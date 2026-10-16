-- =====================================================================
-- Sınıf360 Okul Lisanslama Sistemi Veritabanı Güncelleme Scripti
-- Bu scripti Supabase Dashboard > SQL Editor üzerinden çalıştırın.
-- =====================================================================

-- 1. schools tablosuna lisans alanlarını ekleme
ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS is_licensed BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS license_expires_at TIMESTAMPTZ DEFAULT (now() + interval '1 year'),
ADD COLUMN IF NOT EXISTS license_notes TEXT;

-- 2. Mevcut okulların lisans tarihlerini varsayılan olarak güncelleme (Eğer boş kalmışlarsa)
UPDATE public.schools
SET license_expires_at = (now() + interval '1 year')
WHERE license_expires_at IS NULL;

UPDATE public.schools
SET is_licensed = true
WHERE is_licensed IS NULL;

-- 3. Hızlı sorgulama ve lisans kontrolleri için indeksler
CREATE INDEX IF NOT EXISTS idx_schools_is_licensed ON public.schools(is_licensed);
CREATE INDEX IF NOT EXISTS idx_schools_license_expires_at ON public.schools(license_expires_at);

-- 4. Otomatik Lisans Durum Kontrol Fonksiyonu & Tetikleyicisi
-- Kayıt güncellenirken veya eklenirken son kullanma tarihi geçmişse is_licensed otomatik false yapılır
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

-- 5. Realtime Akışına schools Tablosunu Dahil Etme
-- Web paneli ve istemcilerin anlık lisans değişimlerini yakalayabilmesi için
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'schools'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.schools;
    END IF;
END $$;
