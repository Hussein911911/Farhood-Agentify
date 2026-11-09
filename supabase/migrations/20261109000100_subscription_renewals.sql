create table public.subscription_renewals (
 id uuid primary key default gen_random_uuid(),
 subscription_id uuid not null references public.subscriptions(id),
 payment_id uuid not null unique references public.payment_requests(id),
 previous_ends_at timestamptz not null,
 renewed_from timestamptz not null,
 new_ends_at timestamptz not null,
 billing_period text not null check (billing_period in ('monthly','yearly')),
 payment_amount numeric(12,2) not null,
 payment_currency text not null,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.subscription_renewals enable row level security;
create policy subscription_renewals_admin_read on public.subscription_renewals for select to authenticated using ((select private.is_platform_admin()));
create function public.renew_subscription(p_subscription_id uuid, p_payment_id uuid, p_billing_period text) returns uuid language plpgsql security definer set search_path = '' as $$
declare s public.subscriptions%rowtype; p public.payment_requests%rowtype; start_at timestamptz; end_at timestamptz; renewal_id uuid;
begin
 if not private.is_platform_admin() then raise exception 'not authorized' using errcode='42501'; end if;
 if p_billing_period is null or p_billing_period not in ('monthly','yearly') then raise exception 'invalid period' using errcode='22023'; end if;
 select * into s from public.subscriptions where id=p_subscription_id for update;
 if not found or s.status <> 'active' then raise exception 'subscription not active' using errcode='22023'; end if;
 select * into p from public.payment_requests where id=p_payment_id for update;
 if not found or p.status <> 'approved' or p.restaurant_id <> s.restaurant_id then raise exception 'payment not eligible' using errcode='22023'; end if;
 if exists(select 1 from public.subscription_renewals where payment_id=p.id) then raise exception 'payment already used' using errcode='23505'; end if;
 start_at := greatest(s.ends_at, now());
 end_at := ((start_at at time zone 'UTC') + case when p_billing_period='yearly' then interval '1 year' else interval '1 month' end) at time zone 'UTC';
 insert into public.subscription_renewals(subscription_id,payment_id,previous_ends_at,renewed_from,new_ends_at,billing_period,payment_amount,payment_currency,created_by) values(s.id,p.id,s.ends_at,start_at,end_at,p_billing_period,p.amount,p.currency,auth.uid()) returning id into renewal_id;
 update public.subscriptions set ends_at=end_at, billing_period=p_billing_period where id=s.id;
 return renewal_id;
end; $$;
revoke all on function public.renew_subscription(uuid,uuid,text) from public,anon;
grant execute on function public.renew_subscription(uuid,uuid,text) to authenticated;
