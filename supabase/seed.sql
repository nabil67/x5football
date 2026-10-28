-- Données de démonstration pour le développement LOCAL uniquement (rejouées par `supabase db reset`).
-- Jamais appliquées en production : `supabase db push` n'exécute pas ce fichier.
-- Un organisateur fictif « Karim » et quelques matchs autour de Tours, à Paris et à Rio.

do $$
declare
  v_karim uuid := 'a0000000-0000-4000-8000-000000000001';
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_karim, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'karim@demo.local', '{}', '{}', now(), now());
  insert into public.users (id, display_name, age_confirmed_at) values (v_karim, 'Karim', now());

  with m as (
    insert into public.matches (organizer_id, title, starts_at, duration_minutes, capacity, format, skill_level,
                                location_name, location)
    select v_karim, v.title, date_trunc('day', now()) + v.delay, 90, v.cap, v.fmt::public.match_format,
           v.lvl::public.skill_level, v.place,
           extensions.st_setsrid(extensions.st_makepoint(v.lng, v.lat), 4326)::extensions.geography
    from (values
      ('Five du jeudi soir', interval '2 days 19 hours', 10, '5v5', 'all', 'Urban Soccer Tours', 47.3790, 0.7240),
      ('Match du dimanche matin', interval '4 days 10 hours', 14, '7v7', 'intermediate', 'Stade de la Vallée du Cher', 47.3600, 0.7000),
      ('Foot à Joué-lès-Tours', interval '6 days 18 hours', 10, '5v5', 'beginner', 'City stade de Joué', 47.3520, 0.6630),
      ('Grand match à Amboise', interval '3 days 15 hours', 22, '11v11', 'advanced', 'Stade municipal d''Amboise', 47.4110, 0.9820),
      ('Five au Parc des Princes', interval '5 days 20 hours', 10, '5v5', 'all', 'Five Paris 16', 48.8414, 2.2530),
      ('Pelada no Aterro', interval '2 days 9 hours', 14, '7v7', 'all', 'Aterro do Flamengo', -22.9300, -43.1730)
    ) as v(title, delay, cap, fmt, lvl, place, lat, lng)
    returning id
  )
  insert into public.participations (match_id, user_id) select id, v_karim from m;
end
$$;
