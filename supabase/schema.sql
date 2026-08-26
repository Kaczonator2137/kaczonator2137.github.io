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
