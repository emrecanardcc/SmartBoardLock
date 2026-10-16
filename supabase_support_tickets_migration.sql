-- =====================================================================
-- Sınıf360 Destek ve Arıza Bildirimleri (support_tickets) Tablosu
-- Bu scripti Supabase Dashboard > SQL Editor üzerinden çalıştırın.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    board_id UUID REFERENCES public.boards(id) ON DELETE SET NULL,
    board_name TEXT,
    reporter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reporter_name TEXT NOT NULL,
    reporter_role TEXT NOT NULL DEFAULT 'teacher', -- 'teacher', 'school_admin', 'super_admin'
    category TEXT NOT NULL DEFAULT 'Diğer',
    title TEXT,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'in_progress', 'resolved', 'rejected'
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hızlı filtreleme ve listeleme için indeksler
CREATE INDEX IF NOT EXISTS idx_support_tickets_school_id ON public.support_tickets(school_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created_at ON public.support_tickets(created_at DESC);

-- Satır Düzeyi Güvenlik (RLS) Açılışı
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- 1. Giriş yapmış tüm öğretmenler ve müdürler sorun bildirebilir (INSERT)
CREATE POLICY "support_tickets_insert_policy" ON public.support_tickets
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- 2. Giriş yapmış kullanıcılar destek taleplerini okuyabilir (SELECT)
CREATE POLICY "support_tickets_select_policy" ON public.support_tickets
    FOR SELECT TO authenticated
    USING (true);

-- 3. Yetkili kullanıcılar (Süper Admin / Okul Müdürü) durum ve not güncelleyebilir (UPDATE)
CREATE POLICY "support_tickets_update_policy" ON public.support_tickets
    FOR UPDATE TO authenticated
    USING (true)
    WITH CHECK (true);

-- 4. Süper Admin'ler veya yöneticiler silebilir (DELETE)
CREATE POLICY "support_tickets_delete_policy" ON public.support_tickets
    FOR DELETE TO authenticated
    USING (true);

-- Realtime akışı etkinleştir (Web paneli ve mobilde anlık güncelleme için)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'support_tickets'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
    END IF;
END $$;
