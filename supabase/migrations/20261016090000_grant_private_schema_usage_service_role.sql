-- Lamīn staging follow-up: allow trusted service_role to resolve private RPC implementations.
-- This is a forward-only correction to the review branch. Apply to Lamin-Test first.
-- Do not apply to production until API exposure and authorization acceptance gates pass.

BEGIN;
GRANT USAGE ON SCHEMA private TO service_role;
COMMIT;
