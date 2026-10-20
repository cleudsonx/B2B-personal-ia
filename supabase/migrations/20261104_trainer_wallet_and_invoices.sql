-- Migration: 20261104_trainer_wallet_and_invoices.sql
-- FASE 6: Monetização B2B2C Híbrida (Carteira do Personal e Cobrança de Alunos)

-- 1. Tabela de Carteira do Treinador (Trainer Wallet)
CREATE TABLE IF NOT EXISTS public.trainer_wallets (
    trainer_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    balance_cents BIGINT NOT NULL DEFAULT 0 CHECK (balance_cents >= 0),
    pending_balance_cents BIGINT NOT NULL DEFAULT 0 CHECK (pending_balance_cents >= 0),
    pix_key TEXT,
    pix_key_type VARCHAR(20) DEFAULT 'cpf',
    bank_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Tabela de Cobranças/Faturas de Alunos (Student Invoices)
CREATE TABLE IF NOT EXISTS public.student_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    student_name TEXT NOT NULL,
    student_phone TEXT,
    student_email TEXT,
    title TEXT NOT NULL,
    description TEXT,
    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
    platform_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (platform_fee_cents >= 0),
    net_amount_cents INTEGER NOT NULL CHECK (net_amount_cents >= 0),
    status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'canceled', 'overdue')),
    due_date DATE NOT NULL DEFAULT CURRENT_DATE,
    paid_at TIMESTAMP WITH TIME ZONE,
    payment_method VARCHAR(30) DEFAULT 'pix',
    payment_link TEXT,
    pix_copy_paste TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Tabela de Solicitações de Saque (Wallet Withdrawals)
CREATE TABLE IF NOT EXISTS public.wallet_withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
    pix_key TEXT NOT NULL,
    pix_key_type VARCHAR(20) DEFAULT 'cpf',
    status VARCHAR(30) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
    receipt_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices de performance
CREATE INDEX IF NOT EXISTS idx_student_invoices_trainer_id ON public.student_invoices(trainer_id);
CREATE INDEX IF NOT EXISTS idx_student_invoices_status ON public.student_invoices(status);
CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_trainer_id ON public.wallet_withdrawals(trainer_id);

-- RLS
ALTER TABLE public.trainer_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_withdrawals ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso permissivas para o service_role e proprietário
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Trainers podem gerenciar sua própria carteira' AND tablename = 'trainer_wallets'
    ) THEN
        CREATE POLICY "Trainers podem gerenciar sua própria carteira"
            ON public.trainer_wallets
            FOR ALL
            TO authenticated
            USING (auth.uid() = trainer_id)
            WITH CHECK (auth.uid() = trainer_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Trainers podem gerenciar cobranças de seus alunos' AND tablename = 'student_invoices'
    ) THEN
        CREATE POLICY "Trainers podem gerenciar cobranças de seus alunos"
            ON public.student_invoices
            FOR ALL
            TO authenticated
            USING (auth.uid() = trainer_id)
            WITH CHECK (auth.uid() = trainer_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Trainers podem visualizar seus saques' AND tablename = 'wallet_withdrawals'
    ) THEN
        CREATE POLICY "Trainers podem visualizar seus saques"
            ON public.wallet_withdrawals
            FOR ALL
            TO authenticated
            USING (auth.uid() = trainer_id)
            WITH CHECK (auth.uid() = trainer_id);
    END IF;
END $$;

