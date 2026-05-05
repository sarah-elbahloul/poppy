-- Users can only see and touch their own data

alter table profiles enable row level security;
alter table entries  enable row level security;
alter table photos   enable row level security;

-- profiles
create policy "own profile" on profiles
  for all using (auth.uid() = id);

-- entries
create policy "own entries" on entries
  for all using (auth.uid() = user_id);

-- photos
create policy "own photos" on photos
  for all using (auth.uid() = user_id);