-- Une session (JWT) reste valide jusqu'à son expiration même si l'identité a été
-- supprimée entre-temps (purge d'un compte). complete_profile renvoie alors
-- AUTH_REQUIRED au lieu d'une erreur technique de clé étrangère, pour que
-- l'application déconnecte l'utilisateur.
create or replace function public.complete_profile(p_display_name text, p_is_adult boolean)
returns public.users
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.users;
begin
  if v_uid is null or not exists (select 1 from auth.users where id = v_uid) then
    raise exception using errcode = 'PT401', message = 'AUTH_REQUIRED',
      hint = 'Votre session a expiré. Reconnectez-vous.';
  end if;

  if p_is_adult is not true then
    raise exception using errcode = 'PT422', message = 'AGE_NOT_CONFIRMED',
      hint = 'L''application est réservée aux personnes de 18 ans ou plus.';
  end if;

  begin
    insert into public.users (id, display_name, age_confirmed_at)
    values (v_uid, btrim(p_display_name), now())
    on conflict (id) do nothing
    returning * into v_profile;
  exception
    when check_violation or not_null_violation then
      raise exception using errcode = 'PT400', message = 'INVALID_DISPLAY_NAME',
        hint = 'Le nom doit contenir entre 2 et 40 caractères.';
  end;

  if v_profile.id is null then
    raise exception using errcode = 'PT409', message = 'PROFILE_ALREADY_EXISTS',
      hint = 'Votre profil existe déjà.';
  end if;

  return v_profile;
end;
$$;
