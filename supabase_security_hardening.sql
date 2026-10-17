-- =====================================================================
-- Sınıf360 Veritabanı Güvenlik Sıkılaştırma ve Tenant İzolasyonu Scripti
-- Bu scripti Supabase Dashboard > SQL Editor üzerinden çalıştırın.
-- =====================================================================

-- 1. support_tickets Tablosu için RLS Politikalarını Yenileme (Tenant Isolation)
DROP POLICY IF EXISTS "support_tickets_select_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_insert_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_update_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_delete_policy" ON public.support_tickets;

-- SELECT Politikası: Kullanıcı yalnızca kendi okulunun biletlerini görebilir (Süper admin tümünü görür)
CREATE POLICY "support_tickets_select_policy" ON public.support_tickets
    FOR SELECT TO authenticated
    USING (
        -- Süper Admin kontrolü (school_id null olan admin veya listede tanımlı)
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'admin' 
            AND school_id IS NULL
        )
        OR
        -- Okul İzolasyonu: Kullanıcının okul_id'si biletin okul_id'si ile eşleşmeli
        school_id = (
            SELECT school_id FROM public.user_profiles 
            WHERE id = auth.uid()
        )
        OR
        -- Kendi açtığı bilet
        reporter_id = auth.uid()
    );

-- INSERT Politikası: Oturum açmış öğretmen veya müdür bilet oluşturabilir
CREATE POLICY "support_tickets_insert_policy" ON public.support_tickets
    FOR INSERT TO authenticated
    WITH CHECK (
        reporter_id = auth.uid()
        OR
        school_id = (
            SELECT school_id FROM public.user_profiles 
            WHERE id = auth.uid()
        )
    );

-- UPDATE Politikası: Yalnızca biletin ait olduğu okulun müdürü veya süper admin güncelleyebilir
CREATE POLICY "support_tickets_update_policy" ON public.support_tickets
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'admin' 
            AND (school_id IS NULL OR school_id = support_tickets.school_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'admin' 
            AND (school_id IS NULL OR school_id = support_tickets.school_id)
        )
    );

-- DELETE Politikası: Yalnızca süper admin veya bileti oluşturan kişi silebilir
CREATE POLICY "support_tickets_delete_policy" ON public.support_tickets
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'admin' 
            AND school_id IS NULL
        )
        OR
        reporter_id = auth.uid()
    );

-- 2. Hızlı ve Hafif Filtreleme İndeksleri
CREATE INDEX IF NOT EXISTS idx_boards_school_active ON public.boards(school_id, is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_school_role ON public.user_profiles(school_id, role);
CREATE INDEX IF NOT EXISTS idx_support_tickets_school_status ON public.support_tickets(school_id, status);
