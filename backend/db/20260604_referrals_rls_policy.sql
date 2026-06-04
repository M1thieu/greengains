-- Fix referral access: RLS was enabled on referrals table with no policies,
-- blocking all access. Backend connects via the DB owner role which may not
-- have BYPASSRLS on Neon. Add an explicit permissive policy for all operations.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'referrals' AND policyname = 'backend_full_access'
  ) THEN
    EXECUTE 'CREATE POLICY backend_full_access ON referrals FOR ALL USING (true) WITH CHECK (true)';
  END IF;
END $$;
