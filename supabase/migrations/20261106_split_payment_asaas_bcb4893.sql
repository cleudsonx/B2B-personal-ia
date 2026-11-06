-- Migration: 20261106_split_payment_asaas_bcb4893.sql
-- Adiciona suporte a subcontas Asaas, Carteira Digital do Personal e Assinatura JWS (BCB 4.893)

-- 1. Enriquecimento da tabela de Carteira do Personal (trainer_wallets)
ALTER TABLE public.trainer_wallets
    ADD COLUMN IF NOT EXISTS asaas_account_id TEXT,
    ADD COLUMN IF NOT EXISTS asaas_wallet_id TEXT,
    ADD COLUMN IF NOT EXISTS asaas_account_status VARCHAR(30) DEFAULT 'unlinked';

-- 2. Enriquecimento da tabela de Cobranças de Alunos (student_invoices)
ALTER TABLE public.student_invoices
    ADD COLUMN IF NOT EXISTS asaas_payment_id TEXT,
    ADD COLUMN IF NOT EXISTS asaas_wallet_id TEXT,
    ADD COLUMN IF NOT EXISTS jws_split_token TEXT,
    ADD COLUMN IF NOT EXISTS split_status VARCHAR(30) DEFAULT 'pending';

-- 3. Índices para consultas de conciliação financeira e webhooks
CREATE INDEX IF NOT EXISTS idx_trainer_wallets_asaas_wallet_id ON public.trainer_wallets(asaas_wallet_id);
CREATE INDEX IF NOT EXISTS idx_student_invoices_asaas_payment_id ON public.student_invoices(asaas_payment_id);
CREATE INDEX IF NOT EXISTS idx_student_invoices_split_status ON public.student_invoices(split_status);
