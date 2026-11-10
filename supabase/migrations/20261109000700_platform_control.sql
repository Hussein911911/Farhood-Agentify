-- Phase 2: central control (kill switch), enforced feature gates, platform updates feed.

-- 1) Kill switch: super-admin can suspend any restaurant site instantly.
alter table public.restaurants add column if not exists suspended boolean not null default false;

-- 2) Platform updates feed (shared component in every restaurant dashboard).
create table public.platform_updates (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 1 and 160),
  body text not null default '' check (length(body) <= 2000),
  published boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.platform_updates enable row level security;
create policy updates_admin on public.platform_updates for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy updates_public_read on public.platform_updates for select using (published);

-- 3) Seed features (implemented now + roadmap) and grant every existing plan the base features.
insert into public.features(key,name) values
  ('site','الموقع العام'),
  ('menu','إدارة المنيو'),
  ('orders','الطلبات'),
  ('table_qr','QR الطاولة'),
  ('printing','الفواتير والطباعة'),
  ('kds','شاشة المطبخ KDS'),
  ('inventory','المخزون'),
  ('reports','التقارير')
on conflict (key) do nothing;
insert into public.plan_features(plan_id,feature_key)
select p.id,v.feature_key from public.plans p cross join (values ('site'),('menu')) as v(feature_key)
on conflict do nothing;

-- 4) Feature gate: restaurant-level override wins, otherwise the in-force subscription plan decides.
create function private.has_feature(target uuid, feature text) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(
    (select o.enabled from public.restaurant_feature_overrides o where o.restaurant_id=target and o.feature_key=feature),
    exists(
      select 1 from public.subscriptions s
      join public.plan_features pf on pf.plan_id=s.plan_id
      where s.restaurant_id=target and s.status='active'
        and s.starts_at<=now() and now()<s.ends_at+make_interval(days=>s.grace_days)
        and pf.feature_key=feature),
    false);
$$;
revoke all on function private.has_feature(uuid,text) from public;
grant execute on function private.has_feature(uuid,text) to authenticated;

-- 5) Enforce the menu feature for managers; platform admins bypass.
create or replace function private.can_manage_menu(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.is_platform_admin()
    or (private.is_restaurant_manager(target)
        and private.has_feature(target,'menu')
        and exists(select 1 from public.subscriptions s where s.restaurant_id=target and s.status='active' and s.starts_at<=now() and now()<s.ends_at+make_interval(days=>s.grace_days)));
$$;

-- 6) Kill switch + site feature inside the public site RPC.
create or replace function public.get_restaurant_site(p_slug text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.restaurants%rowtype; settings public.restaurant_site_settings%rowtype; items jsonb;
begin
  select * into r from public.restaurants where slug=p_slug;
  if not found then return jsonb_build_object('status','unavailable'); end if;
  if r.suspended or not private.has_feature(r.id,'site') then return jsonb_build_object('status','unavailable'); end if;
  select * into settings from public.restaurant_site_settings where restaurant_id=r.id and published=true;
  if not found or not exists (select 1 from public.subscriptions s where s.restaurant_id=r.id and s.status='active' and s.starts_at<=now() and now()<s.ends_at+make_interval(days=>s.grace_days)) then return jsonb_build_object('status','unavailable'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('name',i.name,'description',i.description,'category',i.category,'price_iqd',i.price_iqd) order by i.category,i.created_at,i.id),'[]'::jsonb) into items from public.menu_items i where i.restaurant_id=r.id and i.available;
  return jsonb_build_object('status','available','name',r.name,'headline',settings.headline,'description',settings.description,'phone',settings.phone,'address',settings.address,'hero_image_url',settings.hero_image_url,'accent_color',settings.accent_color,'items',items);
end; $$;

-- 7) Public feed of published platform updates (no tenant data).
create function public.get_platform_updates() returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(
    jsonb_agg(jsonb_build_object('title',u.title,'body',u.body,'created_at',u.created_at) order by u.created_at desc),
    '[]'::jsonb)
  from (select title,body,created_at from public.platform_updates where published order by created_at desc limit 10) u;
$$;
revoke all on function public.get_platform_updates() from public;
grant execute on function public.get_platform_updates() to anon,authenticated;

-- 8) Feature map for the logged-in manager of one restaurant (no data for outsiders).
create function public.get_my_restaurant_features(p_restaurant_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb := '{}'::jsonb; f record;
begin
  if not (private.is_platform_admin() or private.is_restaurant_manager(p_restaurant_id)) then
    return jsonb_build_object('status','forbidden');
  end if;
  if not exists(select 1 from public.restaurants where id=p_restaurant_id) then
    return jsonb_build_object('status','not_found');
  end if;
  for f in select key from public.features order by key loop
    result := result || jsonb_build_object(f.key, private.has_feature(p_restaurant_id, f.key));
  end loop;
  return jsonb_build_object('status','ok','features',result);
end; $$;
revoke all on function public.get_my_restaurant_features(uuid) from public;
grant execute on function public.get_my_restaurant_features(uuid) to authenticated;
