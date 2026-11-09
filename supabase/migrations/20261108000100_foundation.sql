-- Farhood Agentify foundation: no public self-assignment of administrator rights.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at timestamptz not null default now()
);
create table public.restaurant_members (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'manager', 'staff')),
  created_at timestamptz not null default now(),
  primary key (restaurant_id, user_id)
);
create index restaurant_members_user_id_idx on public.restaurant_members(user_id);
create table public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  monthly_price numeric(12,2) not null check (monthly_price >= 0),
  currency text not null default 'USD',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.features (
  key text primary key,
  name text not null
);
create table public.plan_features (
  plan_id uuid not null references public.plans(id) on delete cascade,
  feature_key text not null references public.features(key) on delete cascade,
  primary key (plan_id, feature_key)
);
create table public.restaurant_feature_overrides (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  feature_key text not null references public.features(key) on delete cascade,
  enabled boolean not null,
  primary key (restaurant_id, feature_key)
);
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  plan_id uuid not null references public.plans(id),
  billing_period text not null check (billing_period in ('monthly', 'yearly')),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  grace_days integer not null default 0 check (grace_days >= 0),
  status text not null default 'pending' check (status in ('pending', 'active', 'cancelled')),
  created_at timestamptz not null default now()
);
create unique index subscriptions_one_active_per_restaurant on public.subscriptions(restaurant_id) where status = 'active';
create table public.payment_requests (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'USD',
  method text not null,
  transaction_reference text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create function private.is_platform_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.platform_admins where user_id = (select auth.uid()));
$$;
create function private.is_restaurant_member(target uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.restaurant_members where restaurant_id = target and user_id = (select auth.uid()));
$$;
revoke all on function private.is_platform_admin() from public;
revoke all on function private.is_restaurant_member(uuid) from public;
grant execute on function private.is_platform_admin() to authenticated;
grant execute on function private.is_restaurant_member(uuid) to authenticated;

alter table public.platform_admins enable row level security;
alter table public.restaurants enable row level security;
alter table public.restaurant_members enable row level security;
alter table public.plans enable row level security;
alter table public.features enable row level security;
alter table public.plan_features enable row level security;
alter table public.restaurant_feature_overrides enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payment_requests enable row level security;

-- Only a trusted database administrator may assign the first or subsequent platform admins.
create policy admins_read_self on public.platform_admins for select to authenticated using (user_id = (select auth.uid()));
create policy restaurants_admin on public.restaurants for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy restaurants_member_read on public.restaurants for select to authenticated using (private.is_restaurant_member(id));
create policy members_admin on public.restaurant_members for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy members_read_self on public.restaurant_members for select to authenticated using (user_id = (select auth.uid()));
create policy plans_admin on public.plans for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy plans_read on public.plans for select to authenticated using (active);
create policy features_admin on public.features for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy features_read on public.features for select to authenticated using (true);
create policy plan_features_admin on public.plan_features for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy plan_features_read on public.plan_features for select to authenticated using (true);
create policy overrides_admin on public.restaurant_feature_overrides for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy overrides_member_read on public.restaurant_feature_overrides for select to authenticated using (private.is_restaurant_member(restaurant_id));
create policy subscriptions_admin on public.subscriptions for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy subscriptions_member_read on public.subscriptions for select to authenticated using (private.is_restaurant_member(restaurant_id));
create policy payments_admin on public.payment_requests for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy payments_member_read on public.payment_requests for select to authenticated using (private.is_restaurant_member(restaurant_id));
