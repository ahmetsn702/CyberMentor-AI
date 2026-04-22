-- CyberMentor AI — chat persistence schema
-- Run this in the Supabase SQL editor (or via `supabase db push`) once per project.

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  title text,
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists conversations_user_created_idx
  on public.conversations (user_id, created_at desc);
create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists conversations_select_own on public.conversations;
drop policy if exists conversations_insert_own on public.conversations;
drop policy if exists conversations_update_own on public.conversations;
drop policy if exists conversations_delete_own on public.conversations;

create policy conversations_select_own on public.conversations
  for select using (auth.uid() = user_id);
create policy conversations_insert_own on public.conversations
  for insert with check (auth.uid() = user_id);
create policy conversations_update_own on public.conversations
  for update using (auth.uid() = user_id);
create policy conversations_delete_own on public.conversations
  for delete using (auth.uid() = user_id);

drop policy if exists messages_select_own on public.messages;
drop policy if exists messages_insert_own on public.messages;
drop policy if exists messages_update_own on public.messages;
drop policy if exists messages_delete_own on public.messages;

create policy messages_select_own on public.messages
  for select using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.user_id = auth.uid()
    )
  );
create policy messages_insert_own on public.messages
  for insert with check (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.user_id = auth.uid()
    )
  );
create policy messages_update_own on public.messages
  for update using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.user_id = auth.uid()
    )
  );
create policy messages_delete_own on public.messages
  for delete using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and c.user_id = auth.uid()
    )
  );

-- Allow an authenticated user to delete their own auth.users row.
-- conversations + messages are removed via FK on delete cascade.
-- SECURITY DEFINER runs as the function owner (postgres) so the call can
-- reach auth.users, but the body restricts the delete to auth.uid().
create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;

-- Per-user request log used by the chat Edge Function for rate limiting
-- (10 requests per rolling 60s). The function trims rows older than the
-- window before counting, so the table stays bounded per user.
-- No RLS policies are defined: the function uses the service_role key, and
-- regular clients are denied by default once RLS is enabled.
create table if not exists public.rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_at timestamptz not null default now()
);

create index if not exists rate_limits_user_request_idx
  on public.rate_limits (user_id, request_at desc);

alter table public.rate_limits enable row level security;

-- Challenge bank: curated educational CTF challenges shown in the
-- challenges_page UI. Seeded via supabase/seed.sql; clients only read.
-- solution_context is sent to the Edge Function (never to the client) so
-- the AI mentor can give targeted Socratic hints without leaking the
-- full solution.
create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  category text not null,
  difficulty text not null check (difficulty in ('Kolay', 'Orta', 'Zor')),
  description text not null,
  hints text[] not null,
  learning_objective text not null,
  solution_context text,
  created_at timestamptz not null default now()
);

create index if not exists challenges_category_difficulty_idx
  on public.challenges (category, difficulty);

alter table public.challenges enable row level security;

-- Read-only from clients. No insert/update/delete policies — challenges
-- are managed by maintainers via seed.sql / Supabase dashboard, not users.
drop policy if exists challenges_select_all on public.challenges;
create policy challenges_select_all on public.challenges
  for select using (true);

-- Link a conversation to the challenge it was started from (optional).
-- on delete set null preserves chat history if a challenge is later removed.
alter table public.conversations
  add column if not exists challenge_id uuid references public.challenges(id)
    on delete set null;
