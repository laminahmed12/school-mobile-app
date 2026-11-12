-- Static security regression assertions for owner API limiter.
do $$
declare
  v_def text;
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'owner_api_consume_attempt'
      and p.prosecdef
  ) then
    raise exception 'owner API limiter must exist and be SECURITY DEFINER';
  end if;

  if has_function_privilege('anon', 'public.owner_api_consume_attempt(boolean)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.owner_api_consume_attempt(boolean)', 'EXECUTE')
     or has_function_privilege('public', 'public.owner_api_consume_attempt(boolean)', 'EXECUTE') then
    raise exception 'owner API limiter must not be executable by public client roles';
  end if;

  if not has_table_privilege('service_role', 'public.owner_api_rate_limit', 'INSERT,UPDATE,SELECT') then
    raise exception 'service_role must access the limiter table';
  end if;
end;
$$;
