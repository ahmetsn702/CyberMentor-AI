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
