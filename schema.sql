-- Sherehe schema. Paste into Supabase > SQL Editor > Run.

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null check (char_length(name) between 1 and 20),
  username text not null unique check (username ~ '^[a-zA-Z0-9_]{3,20}$'),
  gender text not null check (gender in ('Female','Male','Other')),
  photo_url text, drink text, party_type text, town text,
  verified boolean not null default false,
  show_online boolean not null default true,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now()
);
-- Coordinates live in their own table so other users can never read them.
create table locations (
  id uuid primary key references auth.users on delete cascade,
  lat double precision not null, lng double precision not null,
  updated_at timestamptz not null default now()
);
create table unlocks (
  payer uuid references auth.users on delete cascade,
  other uuid references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  primary key (payer, other)
);
create table messages (
  id bigint generated always as identity primary key,
  sender uuid not null references auth.users on delete cascade,
  receiver uuid not null references auth.users on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index on messages (sender, receiver, created_at);
create index on messages (receiver, sender, created_at);

alter table profiles  enable row level security;
alter table locations enable row level security;
alter table unlocks   enable row level security;
alter table messages  enable row level security;

create policy "read verified or own" on profiles for select to authenticated using (verified or id = auth.uid());
create policy "insert own" on profiles for insert to authenticated with check (id = auth.uid());
create policy "update own" on profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- Users can never set verified or last_seen themselves.
revoke insert, update on profiles from authenticated;
grant insert (id, name, username, gender, photo_url, drink, party_type, town) on profiles to authenticated;
grant update (name, username, gender, photo_url, drink, party_type, town, show_online) on profiles to authenticated;

create policy "own location" on locations for all to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "see own unlocks" on unlocks for select to authenticated using (payer = auth.uid() or other = auth.uid());
-- No insert policy on unlocks: only the payment functions below can create one.
create policy "read own chats" on messages for select to authenticated using (sender = auth.uid() or receiver = auth.uid());
create policy "send if unlocked" on messages for insert to authenticated with check (
  sender = auth.uid() and exists (
    select 1 from unlocks u where (u.payer = auth.uid() and u.other = receiver) or (u.payer = receiver and u.other = auth.uid())));

-- People nearby, closest first, with distance only (never coordinates).
create or replace function nearby() returns table(id uuid, name text, username text, gender text, photo_url text,
  drink text, party_type text, town text, online boolean, distance_km double precision)
language sql security definer set search_path = public as $$
  select p.id, p.name, p.username, p.gender, p.photo_url, p.drink, p.party_type, p.town,
    (p.show_online and p.last_seen > now() - interval '90 seconds'),
    2*6371*asin(sqrt(power(sin(radians(l.lat-m.lat)/2),2) + cos(radians(m.lat))*cos(radians(l.lat))*power(sin(radians(l.lng-m.lng)/2),2)))
  from profiles p join locations l on l.id = p.id join locations m on m.id = auth.uid()
  where p.verified and p.id <> auth.uid() order by 10 limit 200 $$;

create or replace function heartbeat() returns void language sql security definer set search_path = public as
$$ update profiles set last_seen = now() where id = auth.uid() $$;

-- DEMO ONLY. Delete both when real checks exist (see README).
create or replace function demo_verify() returns void language sql security definer set search_path = public as
$$ update profiles set verified = true where id = auth.uid() $$;
create or replace function demo_pay(other_id uuid) returns void language sql security definer set search_path = public as
$$ insert into unlocks (payer, other) values (auth.uid(), other_id) on conflict do nothing $$;

revoke execute on function nearby(), heartbeat(), demo_verify(), demo_pay(uuid) from public, anon;
grant  execute on function nearby(), heartbeat(), demo_verify(), demo_pay(uuid) to authenticated;

alter publication supabase_realtime add table messages;

-- Profile photos
insert into storage.buckets (id, name, public) values ('avatars','avatars',true) on conflict do nothing;
create policy "avatars read" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars insert own" on storage.objects for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars update own" on storage.objects for update to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
