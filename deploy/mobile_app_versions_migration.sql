-- =====================================================================
-- Sınıf360 Mobil Uygulama Sürüm & Zorunlu Güncelleme Yönetim Tablosu
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.mobile_app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL DEFAULT 'all', -- 'all', 'android', 'ios'
    min_version TEXT NOT NULL DEFAULT '2.1.2', -- Zorunlu minimum sürüm
    latest_version TEXT NOT NULL DEFAULT '2.1.2', -- En son güncel sürüm
    store_url TEXT NOT NULL DEFAULT '', -- App Store / Play Store indirme linki
    title TEXT NOT NULL DEFAULT 'Zorunlu Güncelleme',
    message TEXT NOT NULL DEFAULT 'Sınıf360 mobil uygulamasının yeni sürümü yayınlandı. Kesintisiz ders yönetimi ve güvenlik için lütfen uygulamanızı güncelleyin.',
    is_forced BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS ve İzinler
ALTER TABLE public.mobile_app_versions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'mobile_app_versions' 
        AND policyname = 'Allow public read on mobile_app_versions'
    ) THEN
        CREATE POLICY "Allow public read on mobile_app_versions" 
            ON public.mobile_app_versions 
            FOR SELECT USING (true);
    END IF;
END $$;

GRANT SELECT ON public.mobile_app_versions TO anon, authenticated, service_role;
GRANT ALL ON public.mobile_app_versions TO service_role;

-- Başlangıç verileri
INSERT INTO public.mobile_app_versions (platform, min_version, latest_version, store_url, title, message, is_forced)
SELECT 'all', '2.1.2', '2.1.2', 'https://apps.apple.com', 'Zorunlu Güncelleme', 'Sınıf360 mobil uygulamasının yeni sürümü yayınlandı. Kesintisiz ders yönetimi ve güvenlik için lütfen uygulamanızı güncelleyin.', true
WHERE NOT EXISTS (SELECT 1 FROM public.mobile_app_versions WHERE platform = 'all');

INSERT INTO public.mobile_app_versions (platform, min_version, latest_version, store_url, title, message, is_forced)
SELECT 'ios', '2.1.2', '2.1.2', 'https://apps.apple.com', 'Zorunlu Güncelleme', 'Sınıf360 iOS uygulamasının yeni sürümü yayınlandı. Kesintisiz ders yönetimi ve güvenlik için lütfen uygulamanızı güncelleyin.', true
WHERE NOT EXISTS (SELECT 1 FROM public.mobile_app_versions WHERE platform = 'ios');

INSERT INTO public.mobile_app_versions (platform, min_version, latest_version, store_url, title, message, is_forced)
SELECT 'android', '2.1.2', '2.1.2', 'https://play.google.com', 'Zorunlu Güncelleme', 'Sınıf360 Android uygulamasının yeni sürümü yayınlandı. Kesintisiz ders yönetimi ve güvenlik için lütfen uygulamanızı güncelleyin.', true
WHERE NOT EXISTS (SELECT 1 FROM public.mobile_app_versions WHERE platform = 'android');
