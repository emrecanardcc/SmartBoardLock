#!/usr/bin/env python3
import shutil
import subprocess
import os
import sys

def main():
    try:
        # Disk usage of root filesystem
        total, used, free = shutil.disk_usage("/")
        disk_total_gb = round(total / (1024.0 ** 3), 2)
        disk_used_gb = round(used / (1024.0 ** 3), 2)
        disk_free_gb = round(free / (1024.0 ** 3), 2)
        disk_used_percent = round((used / total) * 100.0, 1) if total > 0 else 0.0

        # Memory usage from /proc/meminfo
        mem = {}
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    val = parts[1].strip().split()[0]
                    if val.isdigit():
                        mem[parts[0].strip()] = int(val)

        ram_total_kb = mem.get("MemTotal", 0)
        ram_avail_kb = mem.get("MemAvailable", mem.get("MemFree", 0))
        ram_used_kb = ram_total_kb - ram_avail_kb
        ram_total_gb = round(ram_total_kb / (1024.0 * 1024.0), 2)
        ram_used_gb = round(ram_used_kb / (1024.0 * 1024.0), 2)
        ram_free_gb = round(ram_avail_kb / (1024.0 * 1024.0), 2)
        ram_used_percent = round((ram_used_kb / ram_total_kb) * 100.0, 1) if ram_total_kb > 0 else 0.0

        # CPU load from /proc/loadavg
        with open("/proc/loadavg", "r") as f:
            loads = [float(x) for x in f.read().split()[:3]]
            load1, load5, load15 = loads[0], loads[1], loads[2]

        cpu_cores = os.cpu_count() or 4
        cpu_usage_percent = round(min(100.0, (load1 / cpu_cores) * 100.0), 1)

        sql = f"""
        CREATE TABLE IF NOT EXISTS public.system_host_telemetry (
            id int PRIMARY KEY DEFAULT 1,
            disk_total_gb numeric NOT NULL,
            disk_used_gb numeric NOT NULL,
            disk_free_gb numeric NOT NULL,
            disk_used_percent numeric NOT NULL,
            ram_total_gb numeric NOT NULL,
            ram_used_gb numeric NOT NULL,
            ram_free_gb numeric NOT NULL,
            ram_used_percent numeric NOT NULL,
            cpu_cores int NOT NULL,
            cpu_model text NOT NULL,
            cpu_usage_percent numeric NOT NULL,
            cpu_load_1m numeric NOT NULL,
            cpu_load_5m numeric NOT NULL,
            cpu_load_15m numeric NOT NULL,
            updated_at timestamptz NOT NULL DEFAULT now()
        );

        ALTER TABLE public.system_host_telemetry ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "system_host_telemetry_service_all" ON public.system_host_telemetry;
        CREATE POLICY "system_host_telemetry_service_all" ON public.system_host_telemetry FOR ALL TO service_role USING (true);
        GRANT ALL ON public.system_host_telemetry TO service_role, postgres;

        INSERT INTO public.system_host_telemetry (
            id, disk_total_gb, disk_used_gb, disk_free_gb, disk_used_percent,
            ram_total_gb, ram_used_gb, ram_free_gb, ram_used_percent,
            cpu_cores, cpu_model, cpu_usage_percent,
            cpu_load_1m, cpu_load_5m, cpu_load_15m, updated_at
        ) VALUES (
            1, {disk_total_gb}, {disk_used_gb}, {disk_free_gb}, {disk_used_percent},
            {ram_total_gb}, {ram_used_gb}, {ram_free_gb}, {ram_used_percent},
            {cpu_cores}, 'Neoverse-N1 (Ampere ARM 4 Çekirdek Cloud vCPU)', {cpu_usage_percent},
            {load1}, {load5}, {load15}, now()
        ) ON CONFLICT (id) DO UPDATE SET
            disk_total_gb = EXCLUDED.disk_total_gb,
            disk_used_gb = EXCLUDED.disk_used_gb,
            disk_free_gb = EXCLUDED.disk_free_gb,
            disk_used_percent = EXCLUDED.disk_used_percent,
            ram_total_gb = EXCLUDED.ram_total_gb,
            ram_used_gb = EXCLUDED.ram_used_gb,
            ram_free_gb = EXCLUDED.ram_free_gb,
            ram_used_percent = EXCLUDED.ram_used_percent,
            cpu_cores = EXCLUDED.cpu_cores,
            cpu_model = EXCLUDED.cpu_model,
            cpu_usage_percent = EXCLUDED.cpu_usage_percent,
            cpu_load_1m = EXCLUDED.cpu_load_1m,
            cpu_load_5m = EXCLUDED.cpu_load_5m,
            cpu_load_15m = EXCLUDED.cpu_load_15m,
            updated_at = now();
        """

        res = subprocess.run(
            ["docker", "exec", "-i", "supabase-db", "psql", "-U", "postgres", "-d", "postgres"],
            input=sql.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        if res.returncode != 0:
            sys.stderr.write("SQL error: " + res.stderr.decode("utf-8") + "\n")
            sys.exit(1)
        else:
            print(f"Host telemetry updated: Disk {disk_used_gb}/{disk_total_gb}GB ({disk_used_percent}%), RAM {ram_used_gb}/{ram_total_gb}GB ({ram_used_percent}%), CPU {cpu_usage_percent}%")
    except Exception as e:
        sys.stderr.write("Telemetry script error: " + str(e) + "\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
