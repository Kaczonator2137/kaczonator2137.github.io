-- CalisLevel — Supabase/PostgreSQL schema
-- Uruchom cały plik w Supabase SQL Editor na nowym projekcie.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text not null default 'Athlete',
  avatar_url text,
  bio text,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  birth_year int,
  sex text check (sex in ('male','female')),
  height_cm numeric(5,1),
  target_weight_kg numeric(5,1),
  weekly_goal int not null default 2 check (weekly_goal between 1 and 7),
  activity_factor numeric(4,2) not null default 1.45,
  goal text not null default 'maintain' check (goal in ('cut','maintain','gain')),
  kcal_target int,
  protein_target int,
  fat_target int,
  carbs_target int,
  updated_at timestamptz not null default now()
);

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category text not null,
  equipment text,
  movement text,
  difficulty text default 'all',
  tracking_type text not null default 'weight_reps' check (tracking_type in ('weight_reps','bodyweight_reps','duration','distance','reps')),
  muscle_primary text,
  muscle_secondary text[] not null default '{}',
  owner_id uuid references public.profiles(id) on delete cascade,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists exercises_name_idx on public.exercises using gin (to_tsvector('simple', name));
create index if not exists exercises_owner_idx on public.exercises(owner_id);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  color_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.plan_exercises (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  sort_order int not null default 0,
  sets int not null default 3 check (sets between 1 and 20),
  rep_min int,
  rep_max int,
  duration_sec int,
  rest_sec int not null default 90,
  notes text
);
create index if not exists plan_exercises_plan_idx on public.plan_exercises(plan_id, sort_order);

create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid references public.plans(id) on delete set null,
  title text not null default 'Trening',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  duration_seconds int,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists workouts_user_date_idx on public.workouts(user_id, started_at desc);

create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  set_no int not null default 1,
  weight_kg numeric(7,2),
  reps int,
  duration_sec int,
  distance_m numeric(9,2),
  rpe numeric(3,1),
  completed boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists workout_sets_workout_idx on public.workout_sets(workout_id);
create index if not exists workout_sets_exercise_idx on public.workout_sets(exercise_id);

create table if not exists public.measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  measured_on date not null default current_date,
  weight_kg numeric(5,1),
  waist_cm numeric(5,1),
  chest_cm numeric(5,1),
  arm_cm numeric(5,1),
  thigh_cm numeric(5,1),
  bodyfat_pct numeric(4,1),
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists measurements_user_date_idx on public.measurements(user_id, measured_on desc);

create table if not exists public.skill_definitions (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  category text not null default 'calisthenics',
  steps jsonb not null default '[]'::jsonb,
  max_level int not null default 5
);

create table if not exists public.user_skills (
  user_id uuid not null references public.profiles(id) on delete cascade,
  skill_id uuid not null references public.skill_definitions(id) on delete cascade,
  level int not null default 0,
  best_value numeric,
  note text,
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);

create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  brand text,
  kcal_100g numeric(7,2) not null,
  protein_100g numeric(6,2) not null default 0,
  carbs_100g numeric(6,2) not null default 0,
  fat_100g numeric(6,2) not null default 0,
  serving_g numeric(7,2) default 100,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists foods_name_idx on public.foods using gin (to_tsvector('simple', name));

create table if not exists public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  food_id uuid not null references public.foods(id) on delete cascade,
  eaten_on date not null default current_date,
  meal_type text not null default 'other' check (meal_type in ('breakfast','lunch','dinner','snack','other')),
  grams numeric(7,2) not null check (grams > 0),
  created_at timestamptz not null default now()
);
create index if not exists meal_logs_user_date_idx on public.meal_logs(user_id, eaten_on);

create table if not exists public.supplements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  dose numeric(8,2),
  unit text not null default 'g',
  instructions text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.supplement_schedules (
  id uuid primary key default gen_random_uuid(),
  supplement_id uuid not null references public.supplements(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  weekdays int[] not null default '{1,2,3,4,5,6,7}',
  time_of_day time,
  relation_to_workout text not null default 'any' check (relation_to_workout in ('any','training_only','rest_only','before_training','after_training')),
  offset_minutes int,
  enabled boolean not null default true
);

create table if not exists public.supplement_logs (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid references public.supplement_schedules(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  taken_on date not null default current_date,
  taken_at timestamptz not null default now(),
  unique(schedule_id, taken_on)
);

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_date date not null,
  event_time time,
  kind text not null default 'note' check (kind in ('training','supplement','measurement','note','recovery')),
  title text not null,
  plan_id uuid references public.plans(id) on delete set null,
  notes text,
  completed boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists calendar_events_user_date_idx on public.calendar_events(user_id,event_date);

create table if not exists public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  points int not null check (points between 1 and 500),
  reason text not null,
  entity_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists xp_events_user_date_idx on public.xp_events(user_id, created_at desc);

create table if not exists public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  starts_on date not null,
  ends_on date not null,
  active boolean not null default true,
  check (ends_on >= starts_on)
);

create table if not exists public.leaderboard_stats (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  lifetime_xp bigint not null default 0,
  season_xp bigint not null default 0,
  workout_count int not null default 0,
  current_streak int not null default 0,
  mastered_skills int not null default 0,
  calis_score bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','blocked')),
  created_at timestamptz not null default now(),
  unique(requester_id, addressee_id),
  check(requester_id <> addressee_id)
);

-- Public leaderboard row contains no health/diet/private data.
create or replace function public.recalculate_leaderboard(p_user uuid)
returns void language plpgsql security definer set search_path=public as $$
declare
  v_lifetime bigint := 0;
  v_season bigint := 0;
  v_workouts int := 0;
  v_skills int := 0;
  v_streak int := 0;
  v_cursor date;
  v_active boolean;
begin
  select coalesce(sum(points),0) into v_lifetime from public.xp_events where user_id=p_user;
  select coalesce(sum(x.points),0) into v_season
  from public.xp_events x
  join public.seasons s on s.active=true
    and current_date between s.starts_on and s.ends_on
    and x.created_at::date between s.starts_on and s.ends_on
  where x.user_id=p_user;
  select count(*) into v_workouts from public.workouts where user_id=p_user and finished_at is not null;
  select count(*) into v_skills from public.user_skills us join public.skill_definitions sd on sd.id=us.skill_id where us.user_id=p_user and us.level>=sd.max_level;

  v_cursor := date_trunc('week', current_date)::date;
  loop
    select exists(
      select 1 from public.workouts
      where user_id=p_user and finished_at is not null
        and started_at::date >= v_cursor and started_at::date < v_cursor + 7
    ) into v_active;
    if v_active then v_streak := v_streak + 1;
    elsif v_cursor = date_trunc('week',current_date)::date then null;
    else exit;
    end if;
    v_cursor := v_cursor - 7;
    exit when v_streak >= 104;
  end loop;

  insert into public.leaderboard_stats(user_id,lifetime_xp,season_xp,workout_count,current_streak,mastered_skills,calis_score,updated_at)
  values(p_user,v_lifetime,v_season,v_workouts,v_streak,v_skills,
         v_lifetime + v_workouts*5 + v_streak*50 + v_skills*150, now())
  on conflict(user_id) do update set
    lifetime_xp=excluded.lifetime_xp, season_xp=excluded.season_xp,
    workout_count=excluded.workout_count, current_streak=excluded.current_streak,
    mastered_skills=excluded.mastered_skills, calis_score=excluded.calis_score,
    updated_at=now();
end $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  begin
    insert into public.profiles(id,username,display_name)
    values(new.id,
      lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)),'[^a-zA-Z0-9_]+','','g')),
      coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)));
  exception when unique_violation then
    insert into public.profiles(id,username,display_name)
    values(new.id,
      lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)),'[^a-zA-Z0-9_]+','','g')) || '_' || substr(new.id::text,1,4),
      coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)))
    on conflict(id) do nothing;
  end;
  insert into public.user_settings(user_id) values(new.id) on conflict(user_id) do nothing;
  insert into public.leaderboard_stats(user_id) values(new.id) on conflict(user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.refresh_leaderboard_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.recalculate_leaderboard(coalesce(new.user_id,old.user_id));
  return coalesce(new,old);
end $$;

drop trigger if exists xp_refresh_leaderboard on public.xp_events;
create trigger xp_refresh_leaderboard after insert or update or delete on public.xp_events for each row execute procedure public.refresh_leaderboard_trigger();
drop trigger if exists workout_refresh_leaderboard on public.workouts;
create trigger workout_refresh_leaderboard after insert or update or delete on public.workouts for each row execute procedure public.refresh_leaderboard_trigger();
drop trigger if exists skill_refresh_leaderboard on public.user_skills;
create trigger skill_refresh_leaderboard after insert or update or delete on public.user_skills for each row execute procedure public.refresh_leaderboard_trigger();

-- Automatic XP for finished workouts. Duplicate protection: one event per workout.
create or replace function public.award_workout_xp()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.finished_at is not null and (old.finished_at is null) then
    if not exists(select 1 from public.xp_events where user_id=new.user_id and entity_id=new.id and reason='workout_completed') then
      insert into public.xp_events(user_id,points,reason,entity_id) values(new.user_id,50,'workout_completed',new.id);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists workout_award_xp on public.workouts;
create trigger workout_award_xp after update on public.workouts for each row execute procedure public.award_workout_xp();

-- 3-month seasons generated ahead for ~6 years. The app selects the season containing current_date.
insert into public.seasons(name,starts_on,ends_on,active)
select 'Season ' || to_char((date_trunc('month',current_date) + (g*interval '3 months'))::date,'YYYY-MM'),
       (date_trunc('month',current_date) + (g*interval '3 months'))::date,
       (date_trunc('month',current_date) + ((g+1)*interval '3 months') - interval '1 day')::date,
       true
from generate_series(0,23) g
where not exists(select 1 from public.seasons);

-- Small automatic XP rewards for progress logging.
create or replace function public.award_measurement_xp()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from public.xp_events where user_id=new.user_id and entity_id=new.id and reason='measurement_logged') then
    insert into public.xp_events(user_id,points,reason,entity_id) values(new.user_id,5,'measurement_logged',new.id);
  end if;
  return new;
end $$;
drop trigger if exists measurement_award_xp on public.measurements;
create trigger measurement_award_xp after insert on public.measurements for each row execute procedure public.award_measurement_xp();

create or replace function public.award_skill_xp()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_points int;
begin
  if new.level > coalesce(old.level,0) then
    v_points := least(100,(new.level-coalesce(old.level,0))*20);
    insert into public.xp_events(user_id,points,reason,entity_id) values(new.user_id,v_points,'skill_progress',new.skill_id);
  end if;
  return new;
end $$;
drop trigger if exists skill_award_xp on public.user_skills;
create trigger skill_award_xp after insert or update on public.user_skills for each row execute procedure public.award_skill_xp();

-- Safe public leaderboard API. It returns only ranking-safe fields for public profiles (plus caller's own profile).
create or replace function public.get_global_leaderboard(p_limit int default 100)
returns table(
  user_id uuid, display_name text, username text, lifetime_xp bigint, season_xp bigint,
  workout_count int, current_streak int, mastered_skills int, calis_score bigint
) language sql stable security definer set search_path=public as $$
  select p.id, p.display_name, p.username,
         coalesce(ls.lifetime_xp,0),
         coalesce((select sum(x.points) from public.xp_events x join public.seasons s on s.active=true and current_date between s.starts_on and s.ends_on where x.user_id=p.id and x.created_at::date between s.starts_on and s.ends_on),0)::bigint,
         coalesce(ls.workout_count,0), coalesce(ls.current_streak,0), coalesce(ls.mastered_skills,0), coalesce(ls.calis_score,0)
  from public.profiles p
  left join public.leaderboard_stats ls on ls.user_id=p.id
  where p.is_public=true or p.id=auth.uid()
  order by coalesce(ls.calis_score,0) desc
  limit greatest(1,least(coalesce(p_limit,100),500));
$$;

-- RLS
alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.exercises enable row level security;
alter table public.plans enable row level security;
alter table public.plan_exercises enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_sets enable row level security;
alter table public.measurements enable row level security;
alter table public.skill_definitions enable row level security;
alter table public.user_skills enable row level security;
alter table public.foods enable row level security;
alter table public.meal_logs enable row level security;
alter table public.supplements enable row level security;
alter table public.supplement_schedules enable row level security;
alter table public.supplement_logs enable row level security;
alter table public.calendar_events enable row level security;
alter table public.xp_events enable row level security;
alter table public.seasons enable row level security;
alter table public.leaderboard_stats enable row level security;
alter table public.friendships enable row level security;

create policy "profiles public read" on public.profiles for select to authenticated using(is_public or id=auth.uid());
create policy "profiles own update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "settings own" on public.user_settings for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "exercises readable" on public.exercises for select to authenticated using(owner_id is null or owner_id=auth.uid() or is_public);
create policy "custom exercises insert" on public.exercises for insert to authenticated with check(owner_id=auth.uid());
create policy "custom exercises update" on public.exercises for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "custom exercises delete" on public.exercises for delete to authenticated using(owner_id=auth.uid());
create policy "plans own" on public.plans for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "plan exercises own" on public.plan_exercises for all to authenticated using(exists(select 1 from public.plans p where p.id=plan_id and p.user_id=auth.uid())) with check(exists(select 1 from public.plans p where p.id=plan_id and p.user_id=auth.uid()));
create policy "workouts own" on public.workouts for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "workout sets own" on public.workout_sets for all to authenticated using(exists(select 1 from public.workouts w where w.id=workout_id and w.user_id=auth.uid())) with check(exists(select 1 from public.workouts w where w.id=workout_id and w.user_id=auth.uid()));
create policy "measurements own" on public.measurements for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "skills definitions read" on public.skill_definitions for select to authenticated using(true);
create policy "user skills own" on public.user_skills for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "foods readable" on public.foods for select to authenticated using(is_public or owner_id=auth.uid());
create policy "foods own insert" on public.foods for insert to authenticated with check(owner_id=auth.uid());
create policy "foods own update" on public.foods for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "foods own delete" on public.foods for delete to authenticated using(owner_id=auth.uid());
create policy "meal logs own" on public.meal_logs for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "supplements own" on public.supplements for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "supp schedules own" on public.supplement_schedules for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "supp logs own" on public.supplement_logs for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "calendar own" on public.calendar_events for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "xp own read" on public.xp_events for select to authenticated using(user_id=auth.uid());
create policy "seasons read" on public.seasons for select to authenticated using(true);
create policy "leaderboard read" on public.leaderboard_stats for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.profiles p where p.id=user_id and p.is_public=true));
create policy "friends own" on public.friendships for select to authenticated using(requester_id=auth.uid() or addressee_id=auth.uid());
create policy "friends request" on public.friendships for insert to authenticated with check(requester_id=auth.uid());
create policy "friends update" on public.friendships for update to authenticated using(requester_id=auth.uid() or addressee_id=auth.uid()) with check(requester_id=auth.uid() or addressee_id=auth.uid());
create policy "friends delete" on public.friendships for delete to authenticated using(requester_id=auth.uid() or addressee_id=auth.uid());

-- Data API permissions (RLS still applies)
grant usage on schema public to authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage,select on all sequences in schema public to authenticated;
grant execute on function public.recalculate_leaderboard(uuid) to authenticated;
grant execute on function public.get_global_leaderboard(int) to authenticated;

-- Calisthenics skill definitions
insert into public.skill_definitions(slug,name,steps,max_level) values
('pull-up','Podciąganie','["1 czyste","5 czystych","10 czystych","15 czystych","+20 kg x 3"]',5),
('dips','Dipy','["1 czysty","5 czystych","10 czystych","15 czystych","+30 kg x 3"]',5),
('l-sit','L-sit','["Tuck","10 s","20 s","30 s","45 s"]',5),
('handstand','Handstand','["Ściana","5 s","15 s","30 s","60 s"]',5),
('muscle-up','Muscle-up','["Negatyw","Guma","1 powt.","3 powt.","5 powt."]',5),
('front-lever','Front lever','["Tuck","Advanced tuck","One leg","Straddle","Full"]',5),
('back-lever','Back lever','["Tuck","Advanced tuck","One leg","Straddle","Full"]',5),
('planche','Planche','["Lean","Tuck","Advanced tuck","Straddle","Full"]',5)
on conflict(slug) do nothing;
-- CalisLevel global exercise library
insert into public.exercises(slug,name,category,equipment,movement,difficulty,tracking_type,muscle_primary,muscle_secondary,is_public) values
('wyciskanie-sztanga-awka-paska','Wyciskanie sztanga — ławka płaska','Klatka','sztanga','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-sztanga-awka-skos-dodatni-15','Wyciskanie sztanga — ławka skos dodatni 15°','Klatka','sztanga','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-sztanga-awka-skos-dodatni-30','Wyciskanie sztanga — ławka skos dodatni 30°','Klatka','sztanga','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-sztanga-awka-skos-dodatni-45','Wyciskanie sztanga — ławka skos dodatni 45°','Klatka','sztanga','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-sztanga-awka-skos-ujemny','Wyciskanie sztanga — ławka skos ujemny','Klatka','sztanga','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-hantle-awka-paska','Wyciskanie hantle — ławka płaska','Klatka','hantle','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-hantle-awka-skos-dodatni-15','Wyciskanie hantle — ławka skos dodatni 15°','Klatka','hantle','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-hantle-awka-skos-dodatni-30','Wyciskanie hantle — ławka skos dodatni 30°','Klatka','hantle','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-hantle-awka-skos-dodatni-45','Wyciskanie hantle — ławka skos dodatni 45°','Klatka','hantle','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-hantle-awka-skos-ujemny','Wyciskanie hantle — ławka skos ujemny','Klatka','hantle','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-smith-machine-awka-paska','Wyciskanie Smith machine — ławka płaska','Klatka','Smith machine','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-smith-machine-awka-skos-dodatni-15','Wyciskanie Smith machine — ławka skos dodatni 15°','Klatka','Smith machine','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-smith-machine-awka-skos-dodatni-30','Wyciskanie Smith machine — ławka skos dodatni 30°','Klatka','Smith machine','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-smith-machine-awka-skos-dodatni-45','Wyciskanie Smith machine — ławka skos dodatni 45°','Klatka','Smith machine','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('wyciskanie-smith-machine-awka-skos-ujemny','Wyciskanie Smith machine — ławka skos ujemny','Klatka','Smith machine','push','all','weight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('rozpietki-na-wyciagu-brama-wysoka-oburacz','Rozpiętki na wyciągu — brama wysoka, oburącz','Klatka','wyciąg','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-na-wyciagu-brama-wysoka-jednoracz','Rozpiętki na wyciągu — brama wysoka, jednorącz','Klatka','wyciąg','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-na-wyciagu-brama-srodkowa-oburacz','Rozpiętki na wyciągu — brama środkowa, oburącz','Klatka','wyciąg','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-na-wyciagu-brama-srodkowa-jednoracz','Rozpiętki na wyciągu — brama środkowa, jednorącz','Klatka','wyciąg','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-na-wyciagu-brama-niska-oburacz','Rozpiętki na wyciągu — brama niska, oburącz','Klatka','wyciąg','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-na-wyciagu-brama-niska-jednoracz','Rozpiętki na wyciągu — brama niska, jednorącz','Klatka','wyciąg','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('pompki-klasyczne','Pompki klasyczne','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-szerokie','Pompki szerokie','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-waskie','Pompki wąskie','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-diamentowe','Pompki diamentowe','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-z-nogami-na-podwyzszeniu','Pompki z nogami na podwyższeniu','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-z-rekami-na-podwyzszeniu','Pompki z rękami na podwyższeniu','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-archer','Pompki archer','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-pseudo-planche','Pompki pseudo planche','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-ring','Pompki ring','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-na-uchwytach','Pompki na uchwytach','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-z-obciazeniem','Pompki z obciążeniem','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-eksplozywne','Pompki eksplozywne','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-clap','Pompki clap','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('pompki-spiderman','Pompki Spiderman','Klatka','masa ciała','push','all','bodyweight_reps','klatka',ARRAY['triceps','barki']::text[],true),
('rozpietki-fly-pec-deck','Rozpiętki / fly — pec deck','Klatka','maszyna/hantle','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-fly-hantle-pasko','Rozpiętki / fly — hantle płasko','Klatka','maszyna/hantle','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-fly-hantle-skos-dodatni','Rozpiętki / fly — hantle skos dodatni','Klatka','maszyna/hantle','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-fly-maszyna-converging','Rozpiętki / fly — maszyna converging','Klatka','maszyna/hantle','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('rozpietki-fly-maszyna-plate-loaded','Rozpiętki / fly — maszyna plate-loaded','Klatka','maszyna/hantle','fly','all','weight_reps','klatka',ARRAY['barki']::text[],true),
('wiosowanie-sztanga-nachwytem-standard','Wiosłowanie sztanga nachwytem — standard','Plecy','sztanga','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-sztanga-nachwytem-pauza-1-s-przy-brzuchu','Wiosłowanie sztanga nachwytem — pauza 1 s przy brzuchu','Plecy','sztanga','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-sztanga-podchwytem-standard','Wiosłowanie sztanga podchwytem — standard','Plecy','sztanga','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-sztanga-podchwytem-pauza-1-s-przy-brzuchu','Wiosłowanie sztanga podchwytem — pauza 1 s przy brzuchu','Plecy','sztanga','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-hantle-jednoracz-standard','Wiosłowanie hantle jednorącz — standard','Plecy','hantle','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-hantle-jednoracz-pauza-1-s-przy-brzuchu','Wiosłowanie hantle jednorącz — pauza 1 s przy brzuchu','Plecy','hantle','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-t-bar-standard','Wiosłowanie T-bar — standard','Plecy','T-bar','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-t-bar-pauza-1-s-przy-brzuchu','Wiosłowanie T-bar — pauza 1 s przy brzuchu','Plecy','T-bar','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-landmine-standard','Wiosłowanie landmine — standard','Plecy','landmine','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-landmine-pauza-1-s-przy-brzuchu','Wiosłowanie landmine — pauza 1 s przy brzuchu','Plecy','landmine','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-wyciag-siedzac-szeroko-standard','Wiosłowanie wyciąg siedząc szeroko — standard','Plecy','wyciąg','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-wyciag-siedzac-szeroko-pauza-1-s-przy-brzuchu','Wiosłowanie wyciąg siedząc szeroko — pauza 1 s przy brzuchu','Plecy','wyciąg','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-wyciag-siedzac-wasko-standard','Wiosłowanie wyciąg siedząc wąsko — standard','Plecy','wyciąg','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-wyciag-siedzac-wasko-pauza-1-s-przy-brzuchu','Wiosłowanie wyciąg siedząc wąsko — pauza 1 s przy brzuchu','Plecy','wyciąg','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-maszyna-chest-supported-standard','Wiosłowanie maszyna chest-supported — standard','Plecy','maszyna','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-maszyna-chest-supported-pauza-1-s-przy-brzuchu','Wiosłowanie maszyna chest-supported — pauza 1 s przy brzuchu','Plecy','maszyna','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-seal-row-standard','Wiosłowanie seal row — standard','Plecy','seal','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-seal-row-pauza-1-s-przy-brzuchu','Wiosłowanie seal row — pauza 1 s przy brzuchu','Plecy','seal','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-smith-machine-standard','Wiosłowanie Smith machine — standard','Plecy','Smith','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('wiosowanie-smith-machine-pauza-1-s-przy-brzuchu','Wiosłowanie Smith machine — pauza 1 s przy brzuchu','Plecy','Smith','row','all','weight_reps','plecy',ARRAY['biceps','tył barków']::text[],true),
('sciaganie-drazka-wyciagu-szeroki-nachwyt','Ściąganie drążka wyciągu — szeroki nachwyt','Plecy','wyciąg','vertical pull','all','weight_reps','najszerszy',ARRAY['biceps']::text[],true),
('sciaganie-drazka-wyciagu-sredni-nachwyt','Ściąganie drążka wyciągu — średni nachwyt','Plecy','wyciąg','vertical pull','all','weight_reps','najszerszy',ARRAY['biceps']::text[],true),
('sciaganie-drazka-wyciagu-waski-neutralny','Ściąganie drążka wyciągu — wąski neutralny','Plecy','wyciąg','vertical pull','all','weight_reps','najszerszy',ARRAY['biceps']::text[],true),
('sciaganie-drazka-wyciagu-podchwyt','Ściąganie drążka wyciągu — podchwyt','Plecy','wyciąg','vertical pull','all','weight_reps','najszerszy',ARRAY['biceps']::text[],true),
('sciaganie-drazka-wyciagu-jednoracz','Ściąganie drążka wyciągu — jednorącz','Plecy','wyciąg','vertical pull','all','weight_reps','najszerszy',ARRAY['biceps']::text[],true),
('podciaganie-nachwyt-szeroki-masa-ciaa','Podciąganie nachwyt szeroki — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-nachwyt-szeroki-z-guma','Podciąganie nachwyt szeroki — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-nachwyt-szeroki-z-dodatkowym-ciezarem','Podciąganie nachwyt szeroki — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-nachwyt-sredni-masa-ciaa','Podciąganie nachwyt średni — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-nachwyt-sredni-z-guma','Podciąganie nachwyt średni — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-nachwyt-sredni-z-dodatkowym-ciezarem','Podciąganie nachwyt średni — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-neutralny-masa-ciaa','Podciąganie neutralny — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-neutralny-z-guma','Podciąganie neutralny — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-neutralny-z-dodatkowym-ciezarem','Podciąganie neutralny — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-podchwyt-masa-ciaa','Podciąganie podchwyt — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-podchwyt-z-guma','Podciąganie podchwyt — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-podchwyt-z-dodatkowym-ciezarem','Podciąganie podchwyt — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-towel-grip-masa-ciaa','Podciąganie towel grip — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-towel-grip-z-guma','Podciąganie towel grip — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-towel-grip-z-dodatkowym-ciezarem','Podciąganie towel grip — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-ring-masa-ciaa','Podciąganie ring — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-ring-z-guma','Podciąganie ring — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-ring-z-dodatkowym-ciezarem','Podciąganie ring — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-commando-masa-ciaa','Podciąganie commando — masa ciała','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-commando-z-guma','Podciąganie commando — z gumą','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('podciaganie-commando-z-dodatkowym-ciezarem','Podciąganie commando — z dodatkowym ciężarem','Plecy','drążek','vertical pull','all','bodyweight_reps','najszerszy',ARRAY['biceps','core']::text[],true),
('straight-arm-pulldown-linka','Straight-Arm Pulldown Linka','Plecy','wyciąg/hantle','shoulder extension','all','weight_reps','najszerszy',ARRAY['triceps']::text[],true),
('straight-arm-pulldown-drazek','Straight-Arm Pulldown Drążek','Plecy','wyciąg/hantle','shoulder extension','all','weight_reps','najszerszy',ARRAY['triceps']::text[],true),
('pullover-hantlem','Pullover Hantlem','Plecy','wyciąg/hantle','shoulder extension','all','weight_reps','najszerszy',ARRAY['triceps']::text[],true),
('pullover-na-maszynie','Pullover Na Maszynie','Plecy','wyciąg/hantle','shoulder extension','all','weight_reps','najszerszy',ARRAY['triceps']::text[],true),
('pullover-na-wyciagu','Pullover Na Wyciągu','Plecy','wyciąg/hantle','shoulder extension','all','weight_reps','najszerszy',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-sztanga-stojac','Wyciskanie nad głowę — sztanga stojąc','Barki','sztanga','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-sztanga-siedzac','Wyciskanie nad głowę — sztanga siedząc','Barki','sztanga','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-hantle-stojac','Wyciskanie nad głowę — hantle stojąc','Barki','hantle','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-hantle-siedzac','Wyciskanie nad głowę — hantle siedząc','Barki','hantle','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-arnold-press','Wyciskanie nad głowę — Arnold press','Barki','Arnold','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-smith-machine','Wyciskanie nad głowę — Smith machine','Barki','Smith','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-maszyna-plate-loaded','Wyciskanie nad głowę — maszyna plate-loaded','Barki','maszyna','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-maszyna-selectorized','Wyciskanie nad głowę — maszyna selectorized','Barki','maszyna','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('wyciskanie-nad-gowe-landmine-jednoracz','Wyciskanie nad głowę — landmine jednorącz','Barki','landmine','vertical push','all','weight_reps','barki',ARRAY['triceps']::text[],true),
('unoszenie-bokiem-hantle-oburacz','Unoszenie bokiem — hantle, oburącz','Barki','hantle','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-hantle-jednoracz','Unoszenie bokiem — hantle, jednorącz','Barki','hantle','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-hantle-lean-away','Unoszenie bokiem — hantle, lean-away','Barki','hantle','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-linki-wyciagu-oburacz','Unoszenie bokiem — linki wyciągu, oburącz','Barki','linki wyciągu','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-linki-wyciagu-jednoracz','Unoszenie bokiem — linki wyciągu, jednorącz','Barki','linki wyciągu','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-linki-wyciagu-lean-away','Unoszenie bokiem — linki wyciągu, lean-away','Barki','linki wyciągu','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-maszyna-oburacz','Unoszenie bokiem — maszyna, oburącz','Barki','maszyna','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-maszyna-jednoracz','Unoszenie bokiem — maszyna, jednorącz','Barki','maszyna','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-maszyna-lean-away','Unoszenie bokiem — maszyna, lean-away','Barki','maszyna','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-talerz-oburacz','Unoszenie bokiem — talerz, oburącz','Barki','talerz','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-talerz-jednoracz','Unoszenie bokiem — talerz, jednorącz','Barki','talerz','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-bokiem-talerz-lean-away','Unoszenie bokiem — talerz, lean-away','Barki','talerz','lateral raise','all','weight_reps','barki',ARRAY['kaptury']::text[],true),
('unoszenie-przodem-hantle','Unoszenie przodem — hantle','Barki','hantle','front raise','all','weight_reps','barki',ARRAY['klatka']::text[],true),
('unoszenie-przodem-linki-wyciagu','Unoszenie przodem — linki wyciągu','Barki','linki wyciągu','front raise','all','weight_reps','barki',ARRAY['klatka']::text[],true),
('unoszenie-przodem-talerz','Unoszenie przodem — talerz','Barki','talerz','front raise','all','weight_reps','barki',ARRAY['klatka']::text[],true),
('unoszenie-przodem-sztanga','Unoszenie przodem — sztanga','Barki','sztanga','front raise','all','weight_reps','barki',ARRAY['klatka']::text[],true),
('ty-barkow-reverse-pec-deck','Tył barków — reverse pec deck','Barki','reverse pec deck','rear delt','all','weight_reps','tył barków',ARRAY['kaptury']::text[],true),
('ty-barkow-hantle-w-opadzie','Tył barków — hantle w opadzie','Barki','hantle w opadzie','rear delt','all','weight_reps','tył barków',ARRAY['kaptury']::text[],true),
('ty-barkow-linki-wyciagu','Tył barków — linki wyciągu','Barki','linki wyciągu','rear delt','all','weight_reps','tył barków',ARRAY['kaptury']::text[],true),
('ty-barkow-face-pull-linka','Tył barków — face pull linka','Barki','face pull linka','rear delt','all','weight_reps','tył barków',ARRAY['kaptury']::text[],true),
('ty-barkow-face-pull-uchwyt-podwojny','Tył barków — face pull uchwyt podwójny','Barki','face pull uchwyt podwójny','rear delt','all','weight_reps','tył barków',ARRAY['kaptury']::text[],true),
('uginanie-na-biceps-sztanga-prosta','Uginanie na biceps — sztanga prosta','Biceps','sztanga prosta','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-sztanga-ez','Uginanie na biceps — sztanga EZ','Biceps','sztanga EZ','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-hantle-naprzemiennie','Uginanie na biceps — hantle naprzemiennie','Biceps','hantle naprzemiennie','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-hantle-oburacz','Uginanie na biceps — hantle oburącz','Biceps','hantle oburącz','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-hantle-na-skosie','Uginanie na biceps — hantle na skosie','Biceps','hantle na skosie','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-modlitewnik-sztanga-ez','Uginanie na biceps — modlitewnik sztanga EZ','Biceps','modlitewnik sztanga EZ','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-modlitewnik-hantel','Uginanie na biceps — modlitewnik hantel','Biceps','modlitewnik hantel','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-wyciag-linka','Uginanie na biceps — wyciąg linka','Biceps','wyciąg linka','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-wyciag-drazek','Uginanie na biceps — wyciąg drążek','Biceps','wyciąg drążek','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-bayesian-curl','Uginanie na biceps — bayesian curl','Biceps','bayesian curl','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-spider-curl','Uginanie na biceps — spider curl','Biceps','spider curl','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-concentration-curl','Uginanie na biceps — concentration curl','Biceps','concentration curl','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-hammer-curl','Uginanie na biceps — hammer curl','Biceps','hammer curl','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-cross-body-hammer-curl','Uginanie na biceps — cross-body hammer curl','Biceps','cross-body hammer curl','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('uginanie-na-biceps-reverse-curl','Uginanie na biceps — reverse curl','Biceps','reverse curl','elbow flexion','all','weight_reps','biceps',ARRAY['przedramię']::text[],true),
('triceps-pushdown-drazek','Triceps — pushdown drążek','Triceps','pushdown drążek','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-pushdown-lina','Triceps — pushdown lina','Triceps','pushdown lina','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-pushdown-jednoracz','Triceps — pushdown jednorącz','Triceps','pushdown jednorącz','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-overhead-lina','Triceps — overhead lina','Triceps','overhead lina','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-overhead-hantel','Triceps — overhead hantel','Triceps','overhead hantel','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-french-press-ez','Triceps — French press EZ','Triceps','French press EZ','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-skull-crusher-ez','Triceps — skull crusher EZ','Triceps','skull crusher EZ','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-skull-crusher-hantle','Triceps — skull crusher hantle','Triceps','skull crusher hantle','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-jm-press','Triceps — JM press','Triceps','JM press','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-close-grip-bench-press','Triceps — close-grip bench press','Triceps','close-grip bench press','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-dipy-awkowe','Triceps — dipy ławkowe','Triceps','dipy ławkowe','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-kickback-hantel','Triceps — kickback hantel','Triceps','kickback hantel','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('triceps-kickback-linka','Triceps — kickback linka','Triceps','kickback linka','elbow extension','all','weight_reps','triceps',ARRAY['klatka']::text[],true),
('przedramiona-chwyt-wrist-curl-sztanga','Przedramiona / chwyt — wrist curl sztanga','Przedramiona','wrist curl sztanga','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-wrist-curl-hantle','Przedramiona / chwyt — wrist curl hantle','Przedramiona','wrist curl hantle','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-reverse-wrist-curl','Przedramiona / chwyt — reverse wrist curl','Przedramiona','reverse wrist curl','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-farmer-walk','Przedramiona / chwyt — farmer walk','Przedramiona','farmer walk','grip','all','duration','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-plate-pinch','Przedramiona / chwyt — plate pinch','Przedramiona','plate pinch','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-dead-hang','Przedramiona / chwyt — dead hang','Przedramiona','dead hang','grip','all','duration','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-wrist-roller','Przedramiona / chwyt — wrist roller','Przedramiona','wrist roller','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-pronacja-hantlem','Przedramiona / chwyt — pronacja hantlem','Przedramiona','pronacja hantlem','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przedramiona-chwyt-supinacja-hantlem','Przedramiona / chwyt — supinacja hantlem','Przedramiona','supinacja hantlem','grip','all','weight_reps','przedramię',ARRAY['chwyt']::text[],true),
('przysiad-back-squat-high-bar','Przysiad — back squat high-bar','Nogi','back squat high-bar','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-back-squat-low-bar','Przysiad — back squat low-bar','Nogi','back squat low-bar','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-front-squat','Przysiad — front squat','Nogi','front squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-goblet-squat','Przysiad — goblet squat','Nogi','goblet squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-smith-squat','Przysiad — Smith squat','Nogi','Smith squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-hack-squat','Przysiad — hack squat','Nogi','hack squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-pendulum-squat','Przysiad — pendulum squat','Nogi','pendulum squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-belt-squat','Przysiad — belt squat','Nogi','belt squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-box-squat','Przysiad — box squat','Nogi','box squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('przysiad-zercher-squat','Przysiad — Zercher squat','Nogi','Zercher squat','squat','all','weight_reps','czworogłowe',ARRAY['pośladki','core']::text[],true),
('leg-press-leg-press-45-szeroko','Leg press — leg press 45° szeroko','Nogi','maszyna','press','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('leg-press-leg-press-45-wasko','Leg press — leg press 45° wąsko','Nogi','maszyna','press','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('leg-press-leg-press-poziomy','Leg press — leg press poziomy','Nogi','maszyna','press','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('leg-press-leg-press-jednonoz','Leg press — leg press jednonóż','Nogi','maszyna','press','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('leg-press-hack-press','Leg press — hack press','Nogi','maszyna','press','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('wykroki-chodzone-hantle','Wykroki Chodzone Hantle','Nogi','wykroki chodzone hantle','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('wykroki-w-miejscu-hantle','Wykroki W Miejscu Hantle','Nogi','wykroki w miejscu hantle','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('reverse-lunge','Reverse Lunge','Nogi','reverse lunge','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('forward-lunge','Forward Lunge','Nogi','forward lunge','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('walking-lunge-sztanga','Walking Lunge Sztanga','Nogi','walking lunge sztanga','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('bulgarian-split-squat-hantle','Bulgarian Split Squat Hantle','Nogi','Bulgarian split squat hantle','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('bulgarian-split-squat-smith','Bulgarian Split Squat Smith','Nogi','Bulgarian split squat Smith','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('step-up-hantle','Step-Up Hantle','Nogi','step-up hantle','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('curtsy-lunge','Curtsy Lunge','Nogi','curtsy lunge','lunge','all','weight_reps','czworogłowe',ARRAY['pośladki']::text[],true),
('rdl-sztanga','RDL sztanga','Tył uda','RDL sztanga','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('rdl-hantle','RDL hantle','Tył uda','RDL hantle','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('rdl-smith','RDL Smith','Tył uda','RDL Smith','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('single-leg-rdl-hantle','single-leg RDL hantle','Tył uda','single-leg RDL hantle','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('good-morning-sztanga','good morning sztanga','Tył uda','good morning sztanga','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('good-morning-smith','good morning Smith','Tył uda','good morning Smith','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('stiff-leg-deadlift','stiff-leg deadlift','Tył uda','stiff-leg deadlift','hinge','all','weight_reps','dwugłowe uda',ARRAY['pośladki','prostowniki']::text[],true),
('leg-curl-lezac','Leg Curl Leżąc','Tył uda','maszyna/masa ciała','knee flexion','all','weight_reps','dwugłowe uda',ARRAY['łydki']::text[],true),
('leg-curl-siedzac','Leg Curl Siedząc','Tył uda','maszyna/masa ciała','knee flexion','all','weight_reps','dwugłowe uda',ARRAY['łydki']::text[],true),
('leg-curl-stojac-jednonoz','Leg Curl Stojąc Jednonóż','Tył uda','maszyna/masa ciała','knee flexion','all','weight_reps','dwugłowe uda',ARRAY['łydki']::text[],true),
('nordic-curl','Nordic Curl','Tył uda','maszyna/masa ciała','knee flexion','all','bodyweight_reps','dwugłowe uda',ARRAY['łydki']::text[],true),
('ghr','Ghr','Tył uda','maszyna/masa ciała','knee flexion','all','bodyweight_reps','dwugłowe uda',ARRAY['łydki']::text[],true),
('leg-extension-obunoz','Leg Extension Obunóż','Czworogłowe','maszyna/masa ciała','knee extension','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednonoz','Leg Extension Jednonóż','Czworogłowe','maszyna/masa ciała','knee extension','all','weight_reps','czworogłowe','{}'::text[],true),
('sissy-squat','Sissy Squat','Czworogłowe','maszyna/masa ciała','knee extension','all','bodyweight_reps','czworogłowe','{}'::text[],true),
('reverse-nordic','Reverse Nordic','Czworogłowe','maszyna/masa ciała','knee extension','all','bodyweight_reps','czworogłowe','{}'::text[],true),
('hip-thrust-sztanga','Hip Thrust Sztanga','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('hip-thrust-smith','Hip Thrust Smith','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('glute-bridge-sztanga','Glute Bridge Sztanga','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('glute-bridge-masa-ciaa','Glute Bridge Masa Ciała','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('cable-pull-through','Cable Pull-Through','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('kickback-na-wyciagu','Kickback Na Wyciągu','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('kickback-maszyna','Kickback Maszyna','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('abduction-machine','Abduction Machine','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('adduction-machine','Adduction Machine','Pośladki','różne','hip extension','all','weight_reps','pośladki',ARRAY['dwugłowe uda']::text[],true),
('standing-calf-raise-machine','Standing Calf Raise Machine','Łydki','różne','calf','all','weight_reps','łydki','{}'::text[],true),
('seated-calf-raise','Seated Calf Raise','Łydki','różne','calf','all','weight_reps','łydki','{}'::text[],true),
('calf-raise-leg-press','Calf Raise Leg Press','Łydki','różne','calf','all','weight_reps','łydki','{}'::text[],true),
('single-leg-calf-raise','Single-Leg Calf Raise','Łydki','różne','calf','all','weight_reps','łydki','{}'::text[],true),
('donkey-calf-raise','Donkey Calf Raise','Łydki','różne','calf','all','weight_reps','łydki','{}'::text[],true),
('tibialis-raise','Tibialis Raise','Łydki','różne','calf','all','weight_reps','łydki','{}'::text[],true),
('martwy-ciag-klasyczny','Martwy Ciąg Klasyczny','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('martwy-ciag-sumo','Martwy Ciąg Sumo','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('trap-bar-deadlift','Trap Bar Deadlift','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('rack-pull','Rack Pull','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('block-pull','Block Pull','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('deficit-deadlift','Deficit Deadlift','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('snatch-grip-deadlift','Snatch-Grip Deadlift','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('clean-deadlift','Clean Deadlift','Tył ciała','sztanga','hinge','all','weight_reps','tył ciała',ARRAY['chwyt','core']::text[],true),
('power-clean','Power Clean','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('hang-power-clean','Hang Power Clean','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('clean','Clean','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('clean-and-jerk','Clean And Jerk','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('power-snatch','Power Snatch','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('hang-power-snatch','Hang Power Snatch','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('snatch','Snatch','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('push-press','Push Press','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('split-jerk','Split Jerk','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('high-pull','High Pull','Dwubój / moc','sztanga','olympic','all','weight_reps','całe ciało',ARRAY['barki','nogi']::text[],true),
('plank','Plank','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('side-plank','Side Plank','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('rkc-plank','Rkc Plank','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('hollow-body-hold','Hollow Body Hold','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('arch-hold','Arch Hold','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('dead-bug-hold','Dead Bug Hold','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('l-sit','L-Sit','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('tuck-l-sit','Tuck L-Sit','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('dragon-flag-hold','Dragon Flag Hold','Core','masa ciała','isometric','all','duration','core','{}'::text[],true),
('crunch','Crunch','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('reverse-crunch','Reverse Crunch','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('bicycle-crunch','Bicycle Crunch','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('v-up','V-Up','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('sit-up','Sit-Up','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('toes-to-bar','Toes To Bar','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('hanging-knee-raise','Hanging Knee Raise','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('hanging-leg-raise','Hanging Leg Raise','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('dragon-flag','Dragon Flag','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('ab-wheel-rollout','Ab Wheel Rollout','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('body-saw','Body Saw','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('mountain-climber','Mountain Climber','Core','masa ciała','core','all','bodyweight_reps','core',ARRAY['zginacze biodra']::text[],true),
('cable-crunch','Cable Crunch','Core','wyciąg/ciężar','core','all','weight_reps','core',ARRAY['chwyt']::text[],true),
('pallof-press','Pallof Press','Core','wyciąg/ciężar','core','all','weight_reps','core',ARRAY['chwyt']::text[],true),
('woodchop-high-to-low','Woodchop High-To-Low','Core','wyciąg/ciężar','core','all','weight_reps','core',ARRAY['chwyt']::text[],true),
('woodchop-low-to-high','Woodchop Low-To-High','Core','wyciąg/ciężar','core','all','weight_reps','core',ARRAY['chwyt']::text[],true),
('suitcase-carry','Suitcase Carry','Core','wyciąg/ciężar','core','all','duration','core',ARRAY['chwyt']::text[],true),
('farmer-carry','Farmer Carry','Core','wyciąg/ciężar','core','all','duration','core',ARRAY['chwyt']::text[],true),
('overhead-carry','Overhead Carry','Core','wyciąg/ciężar','core','all','duration','core',ARRAY['chwyt']::text[],true),
('muscle-up-na-drazku','Muscle-up na drążku','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('muscle-up-na-kokach','Muscle-up na kółkach','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('bar-dip','Bar dip','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('ring-dip','Ring dip','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('straight-bar-dip','Straight bar dip','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('handstand','Handstand','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('handstand-przy-scianie','Handstand przy ścianie','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('handstand-push-up','Handstand push-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('pike-push-up','Pike push-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('elevated-pike-push-up','Elevated pike push-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('front-lever-tuck','Front lever tuck','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('front-lever-advanced-tuck','Front lever advanced tuck','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('front-lever-one-leg','Front lever one leg','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('front-lever-straddle','Front lever straddle','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('front-lever-full','Front lever full','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('back-lever-tuck','Back lever tuck','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('back-lever-advanced-tuck','Back lever advanced tuck','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('back-lever-straddle','Back lever straddle','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('back-lever-full','Back lever full','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('planche-lean','Planche lean','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('tuck-planche','Tuck planche','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('advanced-tuck-planche','Advanced tuck planche','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('straddle-planche','Straddle planche','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('full-planche','Full planche','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('human-flag-tuck','Human flag tuck','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('human-flag-one-leg','Human flag one leg','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('human-flag-full','Human flag full','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('skin-the-cat','Skin the cat','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('german-hang','German hang','Kalistenika','masa ciała','skill','all','duration','całe ciało',ARRAY['core']::text[],true),
('pistol-squat','Pistol squat','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('shrimp-squat','Shrimp squat','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('nordic-curl-bodyweight','Nordic curl bodyweight','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('sissy-squat-bodyweight','Sissy squat bodyweight','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('archer-pull-up','Archer pull-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('typewriter-pull-up','Typewriter pull-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('one-arm-pull-up-assisted','One-arm pull-up assisted','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('one-arm-pull-up','One-arm pull-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('archer-push-up','Archer push-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('one-arm-push-up','One-arm push-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('ring-push-up','Ring push-up','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('ring-fly','Ring fly','Kalistenika','masa ciała','skill','all','bodyweight_reps','całe ciało',ARRAY['core']::text[],true),
('bieznia-bieg','Bieżnia bieg','Kondycja / moc','cardio/functional','conditioning','all','distance','całe ciało',ARRAY['core']::text[],true),
('bieznia-marsz-pod-gore','Bieżnia marsz pod górę','Kondycja / moc','cardio/functional','conditioning','all','duration','całe ciało',ARRAY['core']::text[],true),
('rower-stacjonarny','Rower stacjonarny','Kondycja / moc','cardio/functional','conditioning','all','duration','całe ciało',ARRAY['core']::text[],true),
('air-bike','Air bike','Kondycja / moc','cardio/functional','conditioning','all','duration','całe ciało',ARRAY['core']::text[],true),
('ergometr-wioslarski','Ergometr wioślarski','Kondycja / moc','cardio/functional','conditioning','all','distance','całe ciało',ARRAY['core']::text[],true),
('skierg','SkiErg','Kondycja / moc','cardio/functional','conditioning','all','distance','całe ciało',ARRAY['core']::text[],true),
('stairmaster','StairMaster','Kondycja / moc','cardio/functional','conditioning','all','duration','całe ciało',ARRAY['core']::text[],true),
('skakanka','Skakanka','Kondycja / moc','cardio/functional','conditioning','all','duration','całe ciało',ARRAY['core']::text[],true),
('sled-push','Sled push','Kondycja / moc','cardio/functional','conditioning','all','distance','całe ciało',ARRAY['core']::text[],true),
('sled-pull','Sled pull','Kondycja / moc','cardio/functional','conditioning','all','distance','całe ciało',ARRAY['core']::text[],true),
('battle-ropes','Battle ropes','Kondycja / moc','cardio/functional','conditioning','all','duration','całe ciało',ARRAY['core']::text[],true),
('burpees','Burpees','Kondycja / moc','cardio/functional','conditioning','all','reps','całe ciało',ARRAY['core']::text[],true),
('box-jump','Box jump','Kondycja / moc','cardio/functional','conditioning','all','reps','całe ciało',ARRAY['core']::text[],true),
('broad-jump','Broad jump','Kondycja / moc','cardio/functional','conditioning','all','reps','całe ciało',ARRAY['core']::text[],true),
('kettlebell-swing','Kettlebell swing','Kondycja / moc','cardio/functional','conditioning','all','weight_reps','całe ciało',ARRAY['core']::text[],true),
('kettlebell-clean','Kettlebell clean','Kondycja / moc','cardio/functional','conditioning','all','weight_reps','całe ciało',ARRAY['core']::text[],true),
('kettlebell-snatch','Kettlebell snatch','Kondycja / moc','cardio/functional','conditioning','all','weight_reps','całe ciało',ARRAY['core']::text[],true),
('turkish-get-up','Turkish get-up','Kondycja / moc','cardio/functional','conditioning','all','weight_reps','całe ciało',ARRAY['core']::text[],true),
('band-pull-apart','Band Pull-Apart','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('scapular-pull-up','Scapular Pull-Up','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('scapular-push-up','Scapular Push-Up','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('wall-slide','Wall Slide','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('external-rotation-cable','External Rotation Cable','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('external-rotation-band','External Rotation Band','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('cuban-rotation','Cuban Rotation','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('y-raise','Y-Raise','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('t-raise','T-Raise','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('hip-airplane','Hip Airplane','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('cossack-squat','Cossack Squat','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('90-90-hip-rotation','90/90 Hip Rotation','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('jefferson-curl','Jefferson Curl','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('thoracic-rotation','Thoracic Rotation','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('ankle-dorsiflexion-drill','Ankle Dorsiflexion Drill','Mobilność / prehab','guma/masa ciała','prehab','all','reps','stabilizacja','{}'::text[],true),
('cable-row-oburacz-standard','Cable row — oburącz, standard','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-oburacz-tempo-3-1-1','Cable row — oburącz, tempo 3-1-1','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-oburacz-pauza-w-spieciu','Cable row — oburącz, pauza w spięciu','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-jednoracz-prawa-standard','Cable row — jednorącz prawa, standard','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-jednoracz-prawa-tempo-3-1-1','Cable row — jednorącz prawa, tempo 3-1-1','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-jednoracz-prawa-pauza-w-spieciu','Cable row — jednorącz prawa, pauza w spięciu','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-jednoracz-lewa-standard','Cable row — jednorącz lewa, standard','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-jednoracz-lewa-tempo-3-1-1','Cable row — jednorącz lewa, tempo 3-1-1','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('cable-row-jednoracz-lewa-pauza-w-spieciu','Cable row — jednorącz lewa, pauza w spięciu','Plecy','maszyna/wyciąg','accessory','all','weight_reps','plecy','{}'::text[],true),
('lat-pulldown-oburacz-standard','Lat pulldown — oburącz, standard','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-oburacz-tempo-3-1-1','Lat pulldown — oburącz, tempo 3-1-1','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-oburacz-pauza-w-spieciu','Lat pulldown — oburącz, pauza w spięciu','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-jednoracz-prawa-standard','Lat pulldown — jednorącz prawa, standard','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-jednoracz-prawa-tempo-3-1-1','Lat pulldown — jednorącz prawa, tempo 3-1-1','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-jednoracz-prawa-pauza-w-spieciu','Lat pulldown — jednorącz prawa, pauza w spięciu','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-jednoracz-lewa-standard','Lat pulldown — jednorącz lewa, standard','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-jednoracz-lewa-tempo-3-1-1','Lat pulldown — jednorącz lewa, tempo 3-1-1','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('lat-pulldown-jednoracz-lewa-pauza-w-spieciu','Lat pulldown — jednorącz lewa, pauza w spięciu','Plecy','maszyna/wyciąg','accessory','all','weight_reps','najszerszy','{}'::text[],true),
('chest-press-machine-oburacz-standard','Chest press machine — oburącz, standard','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-oburacz-tempo-3-1-1','Chest press machine — oburącz, tempo 3-1-1','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-oburacz-pauza-w-spieciu','Chest press machine — oburącz, pauza w spięciu','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-jednoracz-prawa-standard','Chest press machine — jednorącz prawa, standard','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-jednoracz-prawa-tempo-3-1-1','Chest press machine — jednorącz prawa, tempo 3-1-1','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-jednoracz-prawa-pauza-w-spieciu','Chest press machine — jednorącz prawa, pauza w spięciu','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-jednoracz-lewa-standard','Chest press machine — jednorącz lewa, standard','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-jednoracz-lewa-tempo-3-1-1','Chest press machine — jednorącz lewa, tempo 3-1-1','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('chest-press-machine-jednoracz-lewa-pauza-w-spieciu','Chest press machine — jednorącz lewa, pauza w spięciu','Klatka','maszyna/wyciąg','accessory','all','weight_reps','klatka','{}'::text[],true),
('leg-extension-oburacz-standard','Leg extension — oburącz, standard','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-oburacz-tempo-3-1-1','Leg extension — oburącz, tempo 3-1-1','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-oburacz-pauza-w-spieciu','Leg extension — oburącz, pauza w spięciu','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednoracz-prawa-standard','Leg extension — jednorącz prawa, standard','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednoracz-prawa-tempo-3-1-1','Leg extension — jednorącz prawa, tempo 3-1-1','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednoracz-prawa-pauza-w-spieciu','Leg extension — jednorącz prawa, pauza w spięciu','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednoracz-lewa-standard','Leg extension — jednorącz lewa, standard','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednoracz-lewa-tempo-3-1-1','Leg extension — jednorącz lewa, tempo 3-1-1','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-extension-jednoracz-lewa-pauza-w-spieciu','Leg extension — jednorącz lewa, pauza w spięciu','Czworogłowe','maszyna/wyciąg','accessory','all','weight_reps','czworogłowe','{}'::text[],true),
('leg-curl-oburacz-standard','Leg curl — oburącz, standard','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-oburacz-tempo-3-1-1','Leg curl — oburącz, tempo 3-1-1','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-oburacz-pauza-w-spieciu','Leg curl — oburącz, pauza w spięciu','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-jednoracz-prawa-standard','Leg curl — jednorącz prawa, standard','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-jednoracz-prawa-tempo-3-1-1','Leg curl — jednorącz prawa, tempo 3-1-1','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-jednoracz-prawa-pauza-w-spieciu','Leg curl — jednorącz prawa, pauza w spięciu','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-jednoracz-lewa-standard','Leg curl — jednorącz lewa, standard','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-jednoracz-lewa-tempo-3-1-1','Leg curl — jednorącz lewa, tempo 3-1-1','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('leg-curl-jednoracz-lewa-pauza-w-spieciu','Leg curl — jednorącz lewa, pauza w spięciu','Tył uda','maszyna/wyciąg','accessory','all','weight_reps','dwugłowe uda','{}'::text[],true),
('lateral-raise-cable-oburacz-standard','Lateral raise cable — oburącz, standard','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-oburacz-tempo-3-1-1','Lateral raise cable — oburącz, tempo 3-1-1','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-oburacz-pauza-w-spieciu','Lateral raise cable — oburącz, pauza w spięciu','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-jednoracz-prawa-standard','Lateral raise cable — jednorącz prawa, standard','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-jednoracz-prawa-tempo-3-1-1','Lateral raise cable — jednorącz prawa, tempo 3-1-1','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-jednoracz-prawa-pauza-w-spieciu','Lateral raise cable — jednorącz prawa, pauza w spięciu','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-jednoracz-lewa-standard','Lateral raise cable — jednorącz lewa, standard','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-jednoracz-lewa-tempo-3-1-1','Lateral raise cable — jednorącz lewa, tempo 3-1-1','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true),
('lateral-raise-cable-jednoracz-lewa-pauza-w-spieciu','Lateral raise cable — jednorącz lewa, pauza w spięciu','Barki','maszyna/wyciąg','accessory','all','weight_reps','barki','{}'::text[],true)
on conflict(slug) do nothing;-- Opcjonalna mała baza startowa żywności. Wartości są typowe/orientacyjne; etykieta konkretnego produktu ma pierwszeństwo.
insert into public.foods(owner_id,name,brand,kcal_100g,protein_100g,carbs_100g,fat_100g,serving_g,is_public) values
(null,'Pierś z kurczaka, surowa',null,120,22.5,0,2.6,100,true),
(null,'Pierś z indyka, surowa',null,104,24,0,1,100,true),
(null,'Wołowina mielona 10% tłuszczu',null,176,20,0,10,100,true),
(null,'Łosoś',null,208,20,0,13,100,true),
(null,'Tuńczyk w sosie własnym, odsączony',null,116,26,0,1,100,true),
(null,'Jajko kurze',null,143,12.6,0.7,9.5,60,true),
(null,'Skyr naturalny',null,63,11,4,0.2,150,true),
(null,'Serek wiejski lekki',null,81,12,3,2.5,200,true),
(null,'Twaróg chudy',null,99,19.8,3.5,0.5,100,true),
(null,'Mleko 2%',null,50,3.4,4.8,2,250,true),
(null,'Ryż biały, suchy',null,350,7,78,0.7,100,true),
(null,'Ryż basmati, suchy',null,350,8,77,0.8,100,true),
(null,'Makaron pszenny, suchy',null,350,12,72,1.5,100,true),
(null,'Płatki owsiane',null,370,13,60,7,100,true),
(null,'Chleb pszenny',null,265,9,49,3.2,50,true),
(null,'Chleb żytni',null,250,8,48,3,50,true),
(null,'Ziemniaki',null,77,2,17,0.1,250,true),
(null,'Batat',null,86,1.6,20,0.1,250,true),
(null,'Banan',null,89,1.1,23,0.3,120,true),
(null,'Jabłko',null,52,0.3,14,0.2,180,true),
(null,'Borówki',null,57,0.7,14,0.3,100,true),
(null,'Truskawki',null,32,0.7,7.7,0.3,100,true),
(null,'Awokado',null,160,2,8.5,14.7,100,true),
(null,'Brokuł',null,34,2.8,6.6,0.4,100,true),
(null,'Pomidor',null,18,0.9,3.9,0.2,100,true),
(null,'Ogórek',null,15,0.7,3.6,0.1,100,true),
(null,'Masło orzechowe 100%',null,588,25,20,50,20,true),
(null,'Migdały',null,579,21,22,50,30,true),
(null,'Orzechy włoskie',null,654,15,14,65,30,true),
(null,'Oliwa z oliwek',null,884,0,0,100,10,true),
(null,'Ser mozzarella light',null,180,24,2,8,100,true),
(null,'Ser żółty',null,350,25,2,28,30,true),
(null,'Szynka z indyka',null,105,18,2,3,100,true),
(null,'Tortilla pszenna',null,310,8,52,8,60,true),
(null,'Kuskus, suchy',null,376,13,77,0.6,100,true),
(null,'Kasza gryczana, sucha',null,343,13,72,3.4,100,true),
(null,'Soczewica czerwona, sucha',null,350,25,60,1.5,100,true),
(null,'Ciecierzyca, gotowana',null,164,8.9,27,2.6,100,true),
(null,'Fasola czerwona, gotowana',null,127,8.7,23,0.5,100,true),
(null,'Tofu naturalne',null,125,13,2,7.5,100,true),
(null,'Whey isolate, typowy',null,370,85,4,2,30,true),
(null,'Miód',null,304,0.3,82,0,15,true),
(null,'Dżem niskosłodzony',null,150,0.5,36,0.2,25,true),
(null,'Czekolada gorzka 70%',null,598,8,46,43,20,true),
(null,'Kefir 2%',null,52,3.5,4.7,2,250,true),
(null,'Jogurt grecki 2%',null,73,9,4,2,150,true),
(null,'Marchew',null,41,0.9,10,0.2,100,true),
(null,'Papryka czerwona',null,31,1,6,0.3,100,true),
(null,'Kukurydza konserwowa, odsączona',null,86,3.2,19,1.2,100,true),
(null,'Groszek zielony',null,81,5.4,14,0.4,100,true)
on conflict do nothing;
