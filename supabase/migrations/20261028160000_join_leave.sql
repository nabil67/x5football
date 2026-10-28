-- Étape 5 : rejoindre et quitter un match.
--
-- Les deux RPC verrouillent la ligne du match (FOR UPDATE) : deux demandes simultanées
-- pour la dernière place sont traitées l'une après l'autre, et la seconde voit le match complet.
-- Règles validées le 2026-10-28 :
--   - l'organisateur ne peut pas quitter son match (transfert ou annulation) ;
--   - on peut se réinscrire après être parti, s'il reste de la place ;
--   - on peut quitter jusqu'au coup d'envoi.

-- Verrouille un match ouvert et pas encore commencé, pour une inscription ou une désinscription.
create function private.lock_open_match(p_match_id uuid)
returns public.matches
language plpgsql
set search_path = ''
as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if not found then
    raise exception using errcode = 'PT404', message = 'MATCH_NOT_FOUND',
      hint = 'Ce match est introuvable.';
  end if;
  if v_match.status = 'cancelled' then
    raise exception using errcode = 'PT409', message = 'MATCH_CANCELLED',
      hint = 'Ce match a été annulé.';
  end if;
  if v_match.status = 'completed' then
    raise exception using errcode = 'PT409', message = 'MATCH_COMPLETED',
      hint = 'Ce match est terminé.';
  end if;
  if v_match.starts_at <= now() then
    raise exception using errcode = 'PT409', message = 'MATCH_ALREADY_STARTED',
      hint = 'Ce match a déjà commencé.';
  end if;
  return v_match;
end;
$$;

create function public.join_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches := private.lock_open_match(p_match_id);
  v_active integer;
begin
  if exists (
    select 1 from public.participations
    where match_id = p_match_id and user_id = v_uid and status = 'active'
  ) then
    raise exception using errcode = 'PT409', message = 'ALREADY_JOINED',
      hint = 'Vous êtes déjà inscrit à ce match.';
  end if;

  -- Lecture après obtention du verrou : voit les inscriptions validées entre-temps.
  select count(*) into v_active
  from public.participations
  where match_id = p_match_id and status = 'active';

  if v_active >= v_match.capacity then
    raise exception using errcode = 'PT409', message = 'MATCH_FULL',
      hint = 'Ce match est complet.';
  end if;

  insert into public.participations (match_id, user_id) values (p_match_id, v_uid);
exception
  -- Filet de sécurité : l'index unique partiel refuse toute double inscription active.
  when unique_violation then
    raise exception using errcode = 'PT409', message = 'ALREADY_JOINED',
      hint = 'Vous êtes déjà inscrit à ce match.';
end;
$$;

create function public.leave_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.current_active_user_id();
  v_match public.matches := private.lock_open_match(p_match_id);
begin
  if v_match.organizer_id = v_uid then
    raise exception using errcode = 'PT409', message = 'ORGANIZER_CANNOT_LEAVE',
      hint = 'Vous organisez ce match : transmettez l''organisation à un autre joueur ou annulez le match.';
  end if;

  update public.participations
  set status = 'cancelled', cancelled_at = now()
  where match_id = p_match_id and user_id = v_uid and status = 'active';

  if not found then
    raise exception using errcode = 'PT409', message = 'NOT_PARTICIPANT',
      hint = 'Vous n''êtes pas inscrit à ce match.';
  end if;
end;
$$;

revoke execute on function public.join_match(uuid) from public, anon;
revoke execute on function public.leave_match(uuid) from public, anon;
grant execute on function public.join_match(uuid) to authenticated;
grant execute on function public.leave_match(uuid) to authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;
