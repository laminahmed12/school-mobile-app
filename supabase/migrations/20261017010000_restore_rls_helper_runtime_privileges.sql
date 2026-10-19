-- Restore the minimum runtime privileges required by RLS policies.
-- Stored RLS expressions call these SECURITY DEFINER helpers to scope each
-- request to the authenticated caller's own active school and role.
-- Keep the private schema itself unexposed; grant no schema USAGE to clients.
BEGIN;

REVOKE ALL ON FUNCTION private.my_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.my_school() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION private.my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION private.my_school() TO authenticated;

COMMIT;
