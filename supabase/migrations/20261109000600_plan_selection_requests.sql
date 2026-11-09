create table public.plan_selection_requests (id uuid primary key default gen_random_uuid(), restaurant_id uuid not null references public.restaurants(id), plan_id uuid not null references public.plans(id), billing_period text not null check (billing_period in ('monthly','yearly')), estimated_amount numeric(14,2) not null check (estimated_amount >= 0), currency text not null, status text not null default 'pending' check (status in ('pending','reviewed','rejected')), requested_by uuid not null references auth.users(id), created_at timestamptz not null default now());
create unique index plan_selection_one_pending on public.plan_selection_requests(restaurant_id) where status='pending';
alter table public.plan_selection_requests enable row level security;
create policy plan_requests_admin on public.plan_selection_requests for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy plan_requests_manager_read on public.plan_selection_requests for select to authenticated using (private.is_restaurant_manager(restaurant_id));
create function public.request_plan_selection(p_restaurant_id uuid,p_plan_id uuid,p_period text) returns uuid language plpgsql security definer set search_path='' as $$
declare chosen public.plans%rowtype; request_id uuid;
begin
 if not private.is_restaurant_manager(p_restaurant_id) then raise exception 'not authorized' using errcode='42501'; end if;
 if p_period is null or p_period not in ('monthly','yearly') then raise exception 'invalid billing period' using errcode='22023'; end if;
 select * into chosen from public.plans where id=p_plan_id and active=true;
 if not found then raise exception 'plan unavailable' using errcode='22023'; end if;
 insert into public.plan_selection_requests(restaurant_id,plan_id,billing_period,estimated_amount,currency,requested_by) values(p_restaurant_id,chosen.id,p_period,chosen.monthly_price * case when p_period='yearly' then 12 else 1 end,chosen.currency,auth.uid()) returning id into request_id;
 return request_id;
end; $$;
revoke all on function public.request_plan_selection(uuid,uuid,text) from public,anon;
grant execute on function public.request_plan_selection(uuid,uuid,text) to authenticated;
