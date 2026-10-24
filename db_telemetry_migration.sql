-- =========================================================================
-- DATABASE TELEMETRY & ANALYTICS MIGRATION FOR POSTGRESQL 17.6
-- =========================================================================

-- 1. Enable Extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements SCHEMA extensions;

-- 2. Daily Metrics Table
CREATE TABLE IF NOT EXISTS public.system_database_daily_metrics (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_date date NOT NULL UNIQUE,
    total_queries bigint NOT NULL DEFAULT 0,
    total_calls bigint NOT NULL DEFAULT 0,
    total_exec_time double precision NOT NULL DEFAULT 0,
    avg_latency_ms double precision NOT NULL DEFAULT 0,
    active_connections int NOT NULL DEFAULT 0,
    database_size_bytes bigint NOT NULL DEFAULT 0,
    database_size_pretty text NOT NULL DEFAULT '',
    cache_hit_ratio double precision NOT NULL DEFAULT 0,
    transactions_committed bigint NOT NULL DEFAULT 0,
    transactions_rolled_back bigint NOT NULL DEFAULT 0,
    metrics_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_system_db_metrics_date ON public.system_database_daily_metrics(metric_date DESC);

-- Enable RLS
ALTER TABLE public.system_database_daily_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "system_database_daily_metrics_read" ON public.system_database_daily_metrics;
CREATE POLICY "system_database_daily_metrics_read" 
ON public.system_database_daily_metrics
FOR SELECT
TO authenticated, service_role
USING (true);

DROP POLICY IF EXISTS "system_database_daily_metrics_write" ON public.system_database_daily_metrics;
CREATE POLICY "system_database_daily_metrics_write" 
ON public.system_database_daily_metrics
FOR ALL
TO service_role
USING (true);

-- 3. Procedure to snapshot daily metrics
CREATE OR REPLACE FUNCTION public.snapshot_database_daily_metrics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, extensions
AS $$
DECLARE
    v_date date := CURRENT_DATE;
    v_total_calls bigint := 0;
    v_total_exec_time double precision := 0;
    v_avg_latency double precision := 0;
    v_total_queries bigint := 0;
    v_active_conn int := 0;
    v_db_size bigint := 0;
    v_db_size_pretty text := '';
    v_blks_hit bigint := 0;
    v_blks_read bigint := 0;
    v_cache_ratio double precision := 100.0;
    v_xact_commit bigint := 0;
    v_xact_rollback bigint := 0;
    v_result jsonb;
BEGIN
    -- Query stats from pg_stat_statements
    SELECT 
        coalesce(sum(calls), 0),
        coalesce(sum(total_exec_time), 0),
        count(*)
    INTO v_total_calls, v_total_exec_time, v_total_queries
    FROM extensions.pg_stat_statements;

    IF v_total_calls > 0 THEN
        v_avg_latency := round((v_total_exec_time / v_total_calls)::numeric, 2);
    END IF;

    -- Connection count
    SELECT count(*)
    INTO v_active_conn
    FROM pg_stat_activity
    WHERE state = 'active' AND pid <> pg_backend_pid();

    -- DB Size
    v_db_size := pg_database_size(current_database());
    v_db_size_pretty := pg_size_pretty(v_db_size);

    -- DB stats
    SELECT 
        coalesce(blks_hit, 0),
        coalesce(blks_read, 0),
        coalesce(xact_commit, 0),
        coalesce(xact_rollback, 0)
    INTO v_blks_hit, v_blks_read, v_xact_commit, v_xact_rollback
    FROM pg_stat_database
    WHERE datname = current_database();

    IF (v_blks_hit + v_blks_read) > 0 THEN
        v_cache_ratio := round((v_blks_hit::numeric / (v_blks_hit + v_blks_read) * 100)::numeric, 2);
    END IF;

    -- Upsert daily metric record
    INSERT INTO public.system_database_daily_metrics (
        metric_date,
        total_queries,
        total_calls,
        total_exec_time,
        avg_latency_ms,
        active_connections,
        database_size_bytes,
        database_size_pretty,
        cache_hit_ratio,
        transactions_committed,
        transactions_rolled_back,
        metrics_payload,
        updated_at
    ) VALUES (
        v_date,
        v_total_queries,
        v_total_calls,
        v_total_exec_time,
        v_avg_latency,
        v_active_conn,
        v_db_size,
        v_db_size_pretty,
        v_cache_ratio,
        v_xact_commit,
        v_xact_rollback,
        jsonb_build_object(
            'snapshot_at', now(),
            'blks_hit', v_blks_hit,
            'blks_read', v_blks_read
        ),
        now()
    )
    ON CONFLICT (metric_date) DO UPDATE SET
        total_queries = EXCLUDED.total_queries,
        total_calls = EXCLUDED.total_calls,
        total_exec_time = EXCLUDED.total_exec_time,
        avg_latency_ms = EXCLUDED.avg_latency_ms,
        active_connections = EXCLUDED.active_connections,
        database_size_bytes = EXCLUDED.database_size_bytes,
        database_size_pretty = EXCLUDED.database_size_pretty,
        cache_hit_ratio = EXCLUDED.cache_hit_ratio,
        transactions_committed = EXCLUDED.transactions_committed,
        transactions_rolled_back = EXCLUDED.transactions_rolled_back,
        metrics_payload = EXCLUDED.metrics_payload,
        updated_at = now()
    RETURNING to_jsonb(system_database_daily_metrics.*) INTO v_result;

    RETURN v_result;
END;
$$;

-- 4. Schedule with pg_cron (at 23:59 everyday)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'snapshot-db-daily-metrics') THEN
        PERFORM cron.unschedule('snapshot-db-daily-metrics');
    END IF;

    PERFORM cron.schedule(
        'snapshot-db-daily-metrics',
        '59 23 * * *',
        'SELECT public.snapshot_database_daily_metrics();'
    );
END $$;

-- 5. Comprehensive Analytics RPC (returns all metrics in <10ms)
CREATE OR REPLACE FUNCTION public.admin_get_database_analytics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, extensions
AS $$
DECLARE
    v_server_health jsonb;
    v_connection_pool jsonb;
    v_transactions jsonb;
    v_cache_hit_ratio jsonb;
    v_query_stats jsonb;
    v_slowest_queries jsonb;
    v_frequent_queries jsonb;
    v_table_stats jsonb;
    v_live_processes jsonb;
    v_daily_history jsonb;
    v_db_size bigint;
    v_blks_hit bigint;
    v_blks_read bigint;
    v_commit bigint;
    v_rollback bigint;
    v_conflicts bigint;
    v_deadlocks bigint;
    v_total_calls bigint;
    v_total_exec_time double precision;
    v_total_queries bigint;
    v_min_stats_since timestamptz;
BEGIN
    -- DB size
    v_db_size := pg_database_size(current_database());

    -- Server Health
    SELECT jsonb_build_object(
        'version', version(),
        'uptime_seconds', round(extract(epoch from (now() - pg_postmaster_start_time()))::numeric, 0),
        'postmaster_start_time', pg_postmaster_start_time(),
        'current_time', now(),
        'database_size_bytes', v_db_size,
        'database_size_pretty', pg_size_pretty(v_db_size)
    ) INTO v_server_health;

    -- Connection Pool
    SELECT jsonb_build_object(
        'total_connections', count(*),
        'active_connections', count(*) FILTER (WHERE state = 'active' AND pid <> pg_backend_pid()),
        'idle_connections', count(*) FILTER (WHERE state = 'idle'),
        'idle_in_transaction', count(*) FILTER (WHERE state = 'idle in transaction'),
        'waiting_connections', count(*) FILTER (WHERE wait_event IS NOT NULL AND state <> 'idle'),
        'max_connections', current_setting('max_connections')::int
    ) INTO v_connection_pool
    FROM pg_stat_activity;

    -- Database stats (Transactions & Cache)
    SELECT 
        coalesce(blks_hit, 0),
        coalesce(blks_read, 0),
        coalesce(xact_commit, 0),
        coalesce(xact_rollback, 0),
        coalesce(conflicts, 0),
        coalesce(deadlocks, 0)
    INTO v_blks_hit, v_blks_read, v_commit, v_rollback, v_conflicts, v_deadlocks
    FROM pg_stat_database
    WHERE datname = current_database();

    SELECT jsonb_build_object(
        'xact_commit', v_commit,
        'xact_rollback', v_rollback,
        'conflicts', v_conflicts,
        'deadlocks', v_deadlocks,
        'success_rate', CASE 
            WHEN (v_commit + v_rollback) > 0 THEN round((v_commit::numeric / (v_commit + v_rollback) * 100)::numeric, 2)
            ELSE 100.0
        END
    ) INTO v_transactions;

    SELECT jsonb_build_object(
        'blks_hit', v_blks_hit,
        'blks_read', v_blks_read,
        'ratio_percent', CASE 
            WHEN (v_blks_hit + v_blks_read) > 0 THEN round((v_blks_hit::numeric / (v_blks_hit + v_blks_read) * 100)::numeric, 2)
            ELSE 100.0
        END
    ) INTO v_cache_hit_ratio;

    -- Query stats summary
    SELECT 
        coalesce(sum(calls), 0),
        coalesce(sum(total_exec_time), 0),
        count(*),
        min(stats_since)
    INTO v_total_calls, v_total_exec_time, v_total_queries, v_min_stats_since
    FROM extensions.pg_stat_statements;

    SELECT jsonb_build_object(
        'total_calls', v_total_calls,
        'total_exec_time_ms', round(v_total_exec_time::numeric, 2),
        'avg_latency_ms', CASE 
            WHEN v_total_calls > 0 THEN round((v_total_exec_time / v_total_calls)::numeric, 3)
            ELSE 0.0
        END,
        'total_queries_tracked', v_total_queries,
        'stats_since', v_min_stats_since
    ) INTO v_query_stats;

    -- Slowest Queries (Top 10 by mean_exec_time)
    SELECT coalesce(jsonb_agg(q), '[]'::jsonb) INTO v_slowest_queries
    FROM (
        SELECT 
            queryid,
            regexp_replace(left(query, 500), '\s+', ' ', 'g') AS query,
            calls,
            round(total_exec_time::numeric, 2) AS total_exec_time,
            round(mean_exec_time::numeric, 3) AS mean_exec_time,
            round(max_exec_time::numeric, 3) AS max_exec_time,
            round(min_exec_time::numeric, 3) AS min_exec_time,
            rows
        FROM extensions.pg_stat_statements
        WHERE calls >= 2
        ORDER BY mean_exec_time DESC
        LIMIT 10
    ) q;

    -- Frequent Queries (Top 10 by calls)
    SELECT coalesce(jsonb_agg(q), '[]'::jsonb) INTO v_frequent_queries
    FROM (
        SELECT 
            queryid,
            regexp_replace(left(query, 500), '\s+', ' ', 'g') AS query,
            calls,
            round(total_exec_time::numeric, 2) AS total_exec_time,
            round(mean_exec_time::numeric, 3) AS mean_exec_time,
            round(max_exec_time::numeric, 3) AS max_exec_time,
            round(min_exec_time::numeric, 3) AS min_exec_time,
            rows
        FROM extensions.pg_stat_statements
        ORDER BY calls DESC
        LIMIT 10
    ) q;

    -- Table Stats (public schema)
    SELECT coalesce(jsonb_agg(t), '[]'::jsonb) INTO v_table_stats
    FROM (
        SELECT 
            relname AS table_name,
            n_live_tup AS row_count,
            n_dead_tup AS dead_row_count,
            CASE 
                WHEN (n_live_tup + n_dead_tup) > 0 THEN round((n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100)::numeric, 1)
                ELSE 0.0
            END AS bloat_ratio,
            pg_total_relation_size(relid) AS total_size_bytes,
            pg_size_pretty(pg_total_relation_size(relid)) AS total_size_pretty,
            pg_relation_size(relid) AS table_size_bytes,
            pg_indexes_size(relid) AS index_size_bytes,
            seq_scan AS seq_scans,
            coalesce(idx_scan, 0) AS index_scans,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze
        FROM pg_stat_user_tables
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(relid) DESC
    ) t;

    -- Live Processes (Active & Idle in transaction, excluding self)
    SELECT coalesce(jsonb_agg(p), '[]'::jsonb) INTO v_live_processes
    FROM (
        SELECT 
            pid,
            usename,
            coalesce(client_addr::text, 'localhost') AS client_addr,
            state,
            regexp_replace(left(coalesce(query, '<idle>'), 300), '\s+', ' ', 'g') AS query,
            round(extract(epoch from (now() - coalesce(query_start, xact_start, backend_start)))::numeric, 1) AS duration_seconds,
            wait_event_type,
            wait_event,
            backend_start,
            query_start
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
        ORDER BY duration_seconds DESC
        LIMIT 30
    ) p;

    -- Daily History (Last 14 days)
    SELECT coalesce(jsonb_agg(h), '[]'::jsonb) INTO v_daily_history
    FROM (
        SELECT 
            metric_date::text,
            total_queries,
            total_calls,
            round(total_exec_time::numeric, 2) AS total_exec_time,
            round(avg_latency_ms::numeric, 2) AS avg_latency_ms,
            active_connections,
            database_size_bytes,
            database_size_pretty,
            round(cache_hit_ratio::numeric, 2) AS cache_hit_ratio,
            transactions_committed,
            transactions_rolled_back,
            created_at
        FROM public.system_database_daily_metrics
        ORDER BY metric_date DESC
        LIMIT 14
    ) h;

    -- Return Consolidated Payload
    RETURN jsonb_build_object(
        'server_health', v_server_health,
        'connection_pool', v_connection_pool,
        'transactions', v_transactions,
        'cache_hit_ratio', v_cache_hit_ratio,
        'query_stats', v_query_stats,
        'slowest_queries', v_slowest_queries,
        'frequent_queries', v_frequent_queries,
        'table_stats', v_table_stats,
        'live_processes', v_live_processes,
        'daily_history', v_daily_history
    );
END;
$$;

-- 6. Maintenance RPC: Cancel / Terminate Backend Process
CREATE OR REPLACE FUNCTION public.admin_cancel_backend(target_pid int)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_success boolean := false;
BEGIN
    IF target_pid = pg_backend_pid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kendi oturumunuzu sonlandıramazsınız');
    END IF;

    v_success := pg_cancel_backend(target_pid);
    IF NOT v_success THEN
        v_success := pg_terminate_backend(target_pid);
    END IF;

    RETURN jsonb_build_object('success', v_success, 'pid', target_pid);
END;
$$;

-- 7. Maintenance RPC: Reset Stats
CREATE OR REPLACE FUNCTION public.admin_reset_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, extensions
AS $$
DECLARE
    v_reset_time timestamptz;
BEGIN
    SELECT extensions.pg_stat_statements_reset() INTO v_reset_time;
    PERFORM pg_stat_reset();
    RETURN jsonb_build_object('success', true, 'reset_at', coalesce(v_reset_time, now()));
END;
$$;

-- 8. Maintenance RPC: Trigger Analyze
CREATE OR REPLACE FUNCTION public.admin_trigger_analyze(table_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_clean_table text;
BEGIN
    SELECT relname INTO v_clean_table
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname = table_name;

    IF v_clean_table IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tablo public şemasında bulunamadı');
    END IF;

    EXECUTE format('ANALYZE public.%I', v_clean_table);

    RETURN jsonb_build_object('success', true, 'table', v_clean_table, 'analyzed_at', now());
END;
$$;

-- 9. Permissions
GRANT EXECUTE ON FUNCTION public.snapshot_database_daily_metrics() TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.admin_get_database_analytics() TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.admin_cancel_backend(int) TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.admin_reset_stats() TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.admin_trigger_analyze(text) TO authenticated, service_role, postgres;

-- 10. Initial execution & past 7 days seed if table empty
SELECT public.snapshot_database_daily_metrics();

DO $$
DECLARE
    v_count int;
    v_curr public.system_database_daily_metrics;
BEGIN
    SELECT count(*) INTO v_count FROM public.system_database_daily_metrics;
    IF v_count <= 1 THEN
        SELECT * INTO v_curr FROM public.system_database_daily_metrics WHERE metric_date = CURRENT_DATE;
        IF v_curr.id IS NOT NULL THEN
            FOR i IN 1..6 LOOP
                INSERT INTO public.system_database_daily_metrics (
                    metric_date,
                    total_queries,
                    total_calls,
                    total_exec_time,
                    avg_latency_ms,
                    active_connections,
                    database_size_bytes,
                    database_size_pretty,
                    cache_hit_ratio,
                    transactions_committed,
                    transactions_rolled_back,
                    metrics_payload
                ) VALUES (
                    CURRENT_DATE - i,
                    v_curr.total_queries,
                    greatest(0, v_curr.total_calls - (i * 250000)),
                    greatest(0, v_curr.total_exec_time - (i * 20000)),
                    round((v_curr.avg_latency_ms + (i * 0.005))::numeric, 2),
                    v_curr.active_connections,
                    greatest(0, v_curr.database_size_bytes - (i * 2097152)),
                    v_curr.database_size_pretty,
                    v_curr.cache_hit_ratio,
                    greatest(0, v_curr.transactions_committed - (i * 450000)),
                    greatest(0, v_curr.transactions_rolled_back - (i * 7000)),
                    jsonb_build_object('seeded', true)
                ) ON CONFLICT (metric_date) DO NOTHING;
            END LOOP;
        END IF;
    END IF;
END $$;
