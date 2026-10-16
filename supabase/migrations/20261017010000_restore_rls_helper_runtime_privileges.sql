-- Restore the minimum runtime privileges required by RLS policies.
-- The policies call these SECURITY DEFINER helpers to scope each request to
-- the authenticated caller's own active school and role. Do not grant EXECUTE
-- on every function in the private schema.
BEGIN;

GRANT USAGE ON SCHEMA private TO authenticated;

REVOKE ALL ON FUNCTION private.my_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.my_school() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION private.my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION private.my_school() TO authenticated;

COMMIT;
