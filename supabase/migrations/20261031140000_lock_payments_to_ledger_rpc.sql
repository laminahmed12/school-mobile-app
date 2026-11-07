-- Payments are an immutable accounting ledger. All new receipts must pass through
-- record_student_payment so fee allocations and idempotency remain atomic.
BEGIN;
DROP POLICY IF EXISTS payments_insert ON public.payments;
DROP POLICY IF EXISTS payments_delete ON public.payments;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.payments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.payments TO authenticated;
COMMIT;
