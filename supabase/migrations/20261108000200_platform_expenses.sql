create table public.platform_expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null check (length(trim(description)) > 0),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null check (currency in ('USD','IQD')),
  occurred_on date not null default current_date,
  created_at timestamptz not null default now()
);
alter table public.platform_expenses enable row level security;
create policy platform_expenses_admin on public.platform_expenses for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
