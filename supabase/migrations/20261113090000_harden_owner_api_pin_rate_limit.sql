-- Atomic owner API PIN attempt limiter. One global bucket deliberately avoids
-- trusting client-controlled forwarding headers or spoofable IP addresses.
create table if not exists public.owner_api_rate_limit (
  gate_key text primary key,
  window_started_at timestamptz not null,
  attempts integer not null check (attempts >= 0),
  updated_at timestamptz not null default now()
);

alter table public.owner_api_rate_limit enable row level security;
revoke all on table public.owner_api_rate_limit from public, anon, authenticated;
grant all on table public.owner_api_rate_limit to service_role;

create or replace function public.owner_api_consume_attempt(p_pin_valid boolean)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_attempts integer;
  v_started timestamptz;
begin
  insert into public.owner_api_rate_limit
    (gate_key, window_started_at, attempts, updated_at)
  values
    ('owner:global', clock_timestamp(),
     case when p_pin_valid then 0 else 1 end, clock_timestamp())
  on conflict (gate_key) do update
    set window_started_at = case
          when clock_timestamp() - owner_api_rate_limit.window_started_at >= interval '10 minutes'
            then clock_timestamp()
          else owner_api_rate_limit.window_started_at
        end,
        attempts = case
          when clock_timestamp() - owner_api_rate_limit.window_started_at >= interval '10 minutes'
            then case when p_pin_valid then 0 else 1 end
          when owner_api_rate_limit.attempts >= 40
            then owner_api_rate_limit.attempts
          when p_pin_valid then 0
          else owner_api_rate_limit.attempts + 1
        end,
        updated_at = clock_timestamp()
  returning attempts, window_started_at into v_attempts, v_started;

  if p_pin_valid then
    return v_attempts = 0;
  end if;
  return v_attempts <= 40;
end;
$$;

revoke all on function public.owner_api_consume_attempt(boolean) from public, anon, authenticated;
grant execute on function public.owner_api_consume_attempt(boolean) to service_role;

comment on function public.owner_api_consume_attempt(boolean) is
  'Atomic 10-minute global owner PIN limiter; callable only by service_role.';
