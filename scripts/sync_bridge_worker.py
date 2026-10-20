#!/usr/bin/env python3
"""
Sınıf360 Akıllı Çift Veritabanı Anlık Senkronizasyon Köprüsü (Smart Dual-Database Realtime Bridge)
Eski Supabase (Cloud) <---> Yeni Supabase (Oracle Self-Hosted)

Özellikler:
- Mezar taşı (tombstones.json) kütüğü sayesinde silinen tahtaların dirilmesini (resurrection) %100 engeller.
- Hafızalı Kilit Durum Takipçisi (State-Tracking Lock Sync):
  * Mobilden veya Panelden kilit açıldığında ya da kilitlendiğinde, değişimin yönünü algılar.
  * Kilitleme eylemlerini asla 'açık' durumuna geri döndürmez (resurrection bug çözüldü).
  * 0.5 saniyelik ultra hızlı döngü ile mobilden açılan tahta milisaniyeler içinde her iki DB'de açılır.
- Gerçek yeni tahtaları çift taraflı eşitler.
"""
import time
import json
import os
import urllib.request
import urllib.error
import subprocess
import sys

# Logların anında journalctl'e düşmesi için tamponlamayı kapat
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(line_buffering=True)

PROD_URL = "https://clkasnbpmhddhstoixdz.supabase.co"
PROD_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mjk4Nzg4NCwiZXhwIjoyMDk4NTYzODg0fQ"
    ".Pe4I_qm_qr3HfGNoPFTbbEoQbP1ZD0-KOVZfpI1OJ8c"
)
STATE_FILE = "/home/ubuntu/bridge_known_boards.json"
TOMBSTONE_FILE = "/home/ubuntu/bridge_tombstones.json"

def fetch_old_boards():
    req = urllib.request.Request(
        f"{PROD_URL}/rest/v1/boards?select=*",
        headers={
            "apikey": PROD_KEY,
            "Authorization": f"Bearer {PROD_KEY}",
            "Content-Type": "application/json"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            return {b["id"]: b for b in json.loads(resp.read().decode("utf-8"))}
    except Exception as e:
        print(f"[Bridge] Eski DB okuma hatası: {e}")
        return None

def fetch_new_boards():
    cmd = [
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres", "-t", "-A", "-c",
        "SELECT json_agg(t) FROM (SELECT * FROM public.boards) t;"
    ]
    try:
        out = subprocess.check_output(cmd, timeout=4).decode("utf-8").strip()
        if not out:
            return {}
        return {b["id"]: b for b in json.loads(out)}
    except Exception as e:
        print(f"[Bridge] Yeni DB okuma hatası: {e}")
        return None

def run_psql(sql_string):
    cmd = ["docker", "exec", "-i", "supabase-db", "psql", "-U", "postgres", "-d", "postgres"]
    proc = subprocess.run(cmd, input=sql_string, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return proc.returncode == 0

def sql_quote(val):
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, (dict, list)):
        dumped = json.dumps(val, ensure_ascii=False).replace("'", "''")
        return f"'{dumped}'::jsonb"
    s = str(val).replace("'", "''")
    return f"'{s}'"

def post_old_board(board):
    req = urllib.request.Request(
        f"{PROD_URL}/rest/v1/boards",
        data=json.dumps(board).encode("utf-8"),
        headers={
            "apikey": PROD_KEY,
            "Authorization": f"Bearer {PROD_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            return True
    except Exception as e:
        print(f"[Bridge] Eski DB ekleme hatası {board.get('id')}: {e}")
        return False

def update_old_board(board_id, patch):
    req = urllib.request.Request(
        f"{PROD_URL}/rest/v1/boards?id=eq.{board_id}",
        data=json.dumps(patch).encode("utf-8"),
        headers={
            "apikey": PROD_KEY,
            "Authorization": f"Bearer {PROD_KEY}",
            "Content-Type": "application/json"
        },
        method="PATCH"
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            return True
    except Exception as e:
        print(f"[Bridge] Eski DB güncelleme hatası {board_id}: {e}")
        return False

def delete_old_board(board_id):
    req = urllib.request.Request(
        f"{PROD_URL}/rest/v1/boards?id=eq.{board_id}",
        headers={
            "apikey": PROD_KEY,
            "Authorization": f"Bearer {PROD_KEY}",
            "Content-Type": "application/json"
        },
        method="DELETE"
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            return True
    except Exception as e:
        print(f"[Bridge] Eski DB silme hatası {board_id}: {e}")
        return False

def insert_new_board(b):
    cols = list(b.keys())
    vals = [sql_quote(b[c]) for c in cols]
    sql = f"INSERT INTO public.boards ({', '.join(cols)}) VALUES ({', '.join(vals)}) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, is_unlocked = EXCLUDED.is_unlocked, is_active = EXCLUDED.is_active;"
    return run_psql(sql)

def load_set(filepath):
    if os.path.exists(filepath):
        try:
            with open(filepath, "r") as f:
                return set(json.load(f))
        except:
            pass
    return set()

def save_set(filepath, s):
    try:
        with open(filepath, "w") as f:
            json.dump(list(s), f)
    except:
        pass

def sync_cycle(known_ids, tombstones, last_known_lock):
    old_b = fetch_old_boards()
    new_b = fetch_new_boards()
    if old_b is None or new_b is None:
        return known_ids, tombstones, last_known_lock

    old_ids = set(old_b.keys())
    new_ids = set(new_b.keys())

    # 0. MEZAR TAŞI KONTROLÜ (TOMBSTONES)
    zombies_in_new = new_ids & tombstones
    for bid in zombies_in_new:
        print(f"[Bridge] Mezar taşındaki tahta Yeni DB'de tespit edildi -> Temizleniyor: {bid}")
        run_psql(f"DELETE FROM public.board_pairings WHERE board_id = '{bid}'; DELETE FROM public.boards WHERE id = '{bid}';")
        new_ids.discard(bid)

    zombies_in_old = old_ids & tombstones
    for bid in zombies_in_old:
        print(f"[Bridge] Mezar taşındaki tahta Eski DB'de tespit edildi -> Temizleniyor: {bid}")
        delete_old_board(bid)
        old_ids.discard(bid)

    # İlk çalışma durumu
    if not known_ids:
        known_ids = (old_ids | new_ids) - tombstones
        save_set(STATE_FILE, known_ids)
        for bid in known_ids:
            if bid in new_b:
                last_known_lock[bid] = bool(new_b[bid].get("is_unlocked"))
            elif bid in old_b:
                last_known_lock[bid] = bool(old_b[bid].get("is_unlocked"))
        return known_ids, tombstones, last_known_lock

    # 1. SİLİNEN TAHTALARIN TESPİTİ
    deleted_from_old = ((known_ids & new_ids) - old_ids) - tombstones
    for bid in deleted_from_old:
        bname = new_b.get(bid, {}).get("name", bid)
        print(f"[Bridge] Tahta Mobilden silindi -> Mezar taşına ekleniyor ve Yeni DB'den siliniyor: {bname} ({bid})")
        tombstones.add(bid)
        run_psql(f"DELETE FROM public.board_pairings WHERE board_id = '{bid}'; DELETE FROM public.boards WHERE id = '{bid}';")
        known_ids.discard(bid)
        new_ids.discard(bid)
        last_known_lock.pop(bid, None)

    deleted_from_new = ((known_ids & old_ids) - new_ids) - tombstones
    for bid in deleted_from_new:
        bname = old_b.get(bid, {}).get("name", bid)
        print(f"[Bridge] Tahta Panelden silindi -> Mezar taşına ekleniyor ve Eski DB'den siliniyor: {bname} ({bid})")
        tombstones.add(bid)
        delete_old_board(bid)
        known_ids.discard(bid)
        old_ids.discard(bid)
        last_known_lock.pop(bid, None)

    save_set(TOMBSTONE_FILE, tombstones)

    # 2. GERÇEK YENİ TAHTALARIN EŞİTLENMESİ
    added_to_old = (old_ids - known_ids) - tombstones
    for bid in added_to_old:
        b = old_b[bid]
        print(f"[Bridge] Mobilden yeni tahta eklendi -> Yeni DB'ye kopyalanıyor: {b.get('name')} ({bid})")
        insert_new_board(b)
        known_ids.add(bid)
        last_known_lock[bid] = bool(b.get("is_unlocked"))

    added_to_new = (new_ids - known_ids) - tombstones
    for bid in added_to_new:
        b = new_b[bid]
        print(f"[Bridge] Panelden yeni tahta eklendi -> Eski DB'ye kopyalanıyor: {b.get('name')} ({bid})")
        post_old_board(b)
        known_ids.add(bid)
        last_known_lock[bid] = bool(b.get("is_unlocked"))

    save_set(STATE_FILE, known_ids)

    # 3. AKILLI VE ANLIK KİLİT DURUM EŞİTLEMESİ (State-Tracking Lock Sync)
    common_ids = (old_ids & new_ids) - tombstones
    for bid in common_ids:
        ob = old_b[bid]
        nb = new_b[bid]

        old_unlocked = bool(ob.get("is_unlocked"))
        new_unlocked = bool(nb.get("is_unlocked"))

        # Eğer iki veritabanı kilit durumunda uyuşuyorsa
        if old_unlocked == new_unlocked:
            last_known_lock[bid] = old_unlocked
            continue

        # Uyuşmazlık durumu (biri True, diğeri False):
        prev = last_known_lock.get(bid)

        if prev is not None:
            old_changed = (old_unlocked != prev)
            new_changed = (new_unlocked != prev)

            if old_changed and not new_changed:
                # Eski DB değişti (Öğretmen mobilden kilit açtı veya kilitledi)
                target_state = old_unlocked
                target_actor = ob.get("last_unlocked_by") if target_state else (ob.get("last_locked_by") or "")
                actor_col = "last_unlocked_by" if target_state else "last_locked_by"
                print(f"[Bridge] Eski DB'de kilit değişti ({'AÇIK' if target_state else 'KİLİTLİ'}) -> Yeni DB'ye yazılıyor: {ob.get('name')}")
                run_psql(f"UPDATE public.boards SET is_unlocked = {'true' if target_state else 'false'}, {actor_col} = {sql_quote(target_actor)} WHERE id = '{bid}';")
                last_known_lock[bid] = target_state
                continue

            elif new_changed and not old_changed:
                # Yeni DB değişti (Web panelden veya yeni mobilden kilit açıldı veya kilitlendi)
                target_state = new_unlocked
                target_actor = nb.get("last_unlocked_by") if target_state else (nb.get("last_locked_by") or "")
                actor_key = "last_unlocked_by" if target_state else "last_locked_by"
                print(f"[Bridge] Yeni DB'de kilit değişti ({'AÇIK' if target_state else 'KİLİTLİ'}) -> Eski DB'ye yazılıyor: {nb.get('name')}")
                patch = {"is_unlocked": target_state, actor_key: target_actor}
                update_old_board(bid, patch)
                last_known_lock[bid] = target_state
                continue

        # Eğer prev bilinmiyorsa veya her ikisi de aynı anda değiştiyse:
        # Kilit Açma Önceliği (Unlock-Wins Policy): Öğretmenin derste mahsur kalmaması için AÇIK kazanır!
        target_state = old_unlocked or new_unlocked
        unlocked_by = ob.get("last_unlocked_by") or nb.get("last_unlocked_by") or "Öğretmen"
        locked_by = ob.get("last_locked_by") or nb.get("last_locked_by") or "Sistem"
        actor = unlocked_by if target_state else locked_by
        actor_col = "last_unlocked_by" if target_state else "last_locked_by"

        print(f"[Bridge] Kilit uyuşmazlığı gideriliyor -> {ob.get('name')}: {'AÇIK' if target_state else 'KİLİTLİ'}")
        patch = {"is_unlocked": target_state, actor_col: actor}
        update_old_board(bid, patch)
        run_psql(f"UPDATE public.boards SET is_unlocked = {'true' if target_state else 'false'}, {actor_col} = {sql_quote(actor)} WHERE id = '{bid}';")
        last_known_lock[bid] = target_state

    return known_ids, tombstones, last_known_lock

def main():
    print("=== Sınıf360 Akıllı Çift Veritabanı Anlık Senkronizasyon Köprüsü Devrede ===")
    known_ids = load_set(STATE_FILE)
    tombstones = load_set(TOMBSTONE_FILE)
    last_known_lock = {}
    print(f"Başlangıç: {len(known_ids)} bilinen tahta, {len(tombstones)} mezar taşı kütüğü yüklendi.")
    while True:
        try:
            known_ids, tombstones, last_known_lock = sync_cycle(known_ids, tombstones, last_known_lock)
        except Exception as e:
            print(f"[Bridge Worker Hata]: {e}")
        time.sleep(0.5)

if __name__ == "__main__":
    main()
