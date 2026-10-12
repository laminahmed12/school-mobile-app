-- Harden owner bootstrap against a missing/inactive profile whose role resolves to NULL.
-- Keep this function mirrored with the migration applied to Supabase on 2026-10-12.
create or replace function public.bootstrap_owner_school(p_code text, p_name text)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_role text;
  v_school uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  select p.role into v_role
  from public.profiles p
  where p.user_id = v_user and p.active = true;

  -- IS DISTINCT FROM treats a missing/inactive profile (NULL role) as unauthorized.
  if v_role is distinct from 'owner' then
    raise exception 'owner_only';
  end if;

  select p.school_id into v_school
  from public.profiles p
  where p.user_id = v_user and p.active = true;

  if v_school is not null then
    return v_school;
  end if;

  if p_code is null or trim(p_code) !~ '^[[:alnum:]_ -]{3,40}$' then
    raise exception 'invalid_school_code';
  end if;

  if p_name is null or length(btrim(p_name)) < 3 or length(btrim(p_name)) > 80 then
    raise exception 'invalid_school_name';
  end if;

  insert into public.schools(code, name, currency, country_code, licensed, trial_started_at)
  values (lower(trim(p_code)), trim(p_name), 'LYD', '218', false, now())
  returning id into v_school;

  update public.profiles
  set school_id = v_school
  where user_id = v_user and active = true and role = 'owner' and school_id is null;

  if not found then
    raise exception 'owner_profile_changed';
  end if;

  return v_school;
end;
$function$;
