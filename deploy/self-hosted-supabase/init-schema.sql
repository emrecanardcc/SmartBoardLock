-- =====================================================================
-- Sınıf360 Self-Hosted Supabase Şema ve Veritabanı Kurulum Scripti
-- Bu script Self-Hosted PostgreSQL veritabanına otomatik uygulanır.
-- =====================================================================

-- UUID desteği
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. OKULLAR (schools) TABLOSU
CREATE TABLE IF NOT EXISTS public.schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'İstanbul',
    is_licensed BOOLEAN NOT NULL DEFAULT true,
    license_expires_at TIMESTAMPTZ DEFAULT (now() + interval '1 year'),
    license_notes TEXT,
    board_admin_password TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_schools_is_licensed ON public.schools(is_licensed);
CREATE INDEX IF NOT EXISTS idx_schools_license_expires_at ON public.schools(license_expires_at);

-- 2. KULLANICI PROFİLLERİ (user_profiles) TABLOSU
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'teacher', -- 'admin', 'teacher'
    email TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_school_role ON public.user_profiles(school_id, role);

-- 3. AKILLI TAHTALAR (boards) TABLOSU
CREATE TABLE IF NOT EXISTS public.boards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    auto_lock_minutes INT NOT NULL DEFAULT 15,
    last_ping_at TIMESTAMPTZ DEFAULT now(),
    offline_secret TEXT,
    last_unlocked_by TEXT,
    last_locked_by TEXT,
    grade TEXT,
    branch TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    app_version TEXT,
    remote_command TEXT,
    active_media_id TEXT NOT NULL DEFAULT 'DEFAULT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_boards_school_active ON public.boards(school_id, is_active);
CREATE INDEX IF NOT EXISTS idx_boards_school_id ON public.boards(school_id);

-- 4. TAHTA EŞLEŞTİRME (board_pairings) TABLOSU
CREATE TABLE IF NOT EXISTS public.board_pairings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pairing_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'expired'
    board_id UUID REFERENCES public.boards(id) ON DELETE CASCADE,
    offline_secret TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_board_pairings_code ON public.board_pairings(pairing_code);

-- 5. UYGULAMA VERSİYONLARI (app_versions) TABLOSU
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_number TEXT NOT NULL,
    download_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. YAYIN PAKETLERİ (broadcast_packages) TABLOSU
CREATE TABLE IF NOT EXISTS public.broadcast_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT 'v1.0',
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_template BOOLEAN NOT NULL DEFAULT false,
    template_name TEXT,
    target_board_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_broadcast_packages_school ON public.broadcast_packages(school_id, is_active);

-- 7. DESTEK VE ARIZA BİLDİRİMLERİ (support_tickets) TABLOSU
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    board_id UUID REFERENCES public.boards(id) ON DELETE SET NULL,
    board_name TEXT,
    reporter_id UUID,
    reporter_name TEXT NOT NULL,
    reporter_role TEXT NOT NULL DEFAULT 'teacher',
    category TEXT NOT NULL DEFAULT 'Diğer',
    title TEXT,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_school_status ON public.support_tickets(school_id, status);

-- 8. LİSANS OTOMATİK KONTROL TETİKLEYİCİSİ
CREATE OR REPLACE FUNCTION public.check_school_license_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.license_expires_at IS NOT NULL AND NEW.license_expires_at < now() THEN
        NEW.is_licensed := false;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_school_license_expiry ON public.schools;
CREATE TRIGGER trg_check_school_license_expiry
BEFORE INSERT OR UPDATE ON public.schools
FOR EACH ROW
EXECUTE FUNCTION public.check_school_license_expiry();

-- 9. REALTIME YAYINI AKTİF ETME
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.schools;
ALTER PUBLICATION supabase_realtime ADD TABLE public.boards;
ALTER PUBLICATION supabase_realtime ADD TABLE public.board_pairings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.broadcast_packages;

-- 10. ÖRNEK TEST OKULU VE TAHTALAR (Doğrulama ve Kıyaslama Testleri İçin)
INSERT INTO public.schools (id, name, city, is_licensed, license_expires_at, license_notes)
VALUES 
    ('a0000000-0000-0000-0000-000000000001', 'Test Atatürk Anadolu Lisesi', 'İstanbul', true, now() + interval '365 days', 'Self-Hosted Benchmark Test Okulu')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.boards (id, school_id, name, is_unlocked, auto_lock_minutes, is_active, offline_secret)
VALUES 
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '10-A Akıllı Tahta', false, 15, true, 'TEST-OFFLINE-SECRET-10A'),
    ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', '10-B Akıllı Tahta', false, 15, true, 'TEST-OFFLINE-SECRET-10B')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.app_versions (version_number, download_url)
VALUES ('1.0.0', 'https://github.com/emrecanardcc/SmartBoardLock/releases/latest')
ON CONFLICT (id) DO NOTHING;
