-- Étape 8 : la liste des participants indique la ligne de l'utilisateur connecté,
-- pour proposer « Signaler » et « Bloquer » sur les autres joueurs uniquement.

create or replace view public.match_participants
with (security_invoker = true)
as
select
  p.match_id,
  p.user_id,
  pp.display_name,
  pp.avatar_url,
  p.joined_at,
  p.user_id = m.organizer_id as is_organizer,
  p.user_id = (select auth.uid()) as is_me
from public.participations p
join public.matches m on m.id = p.match_id
join public.public_profiles pp on pp.id = p.user_id
where p.status = 'active';
