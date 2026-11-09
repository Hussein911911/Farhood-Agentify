create table public.restaurant_site_settings (restaurant_id uuid primary key references public.restaurants(id) on delete cascade, headline text not null default '', description text not null default '', phone text not null default '', address text not null default '', hero_image_url text not null default '', accent_color text not null default '#bd5b36' check (accent_color ~ '^#[0-9a-fA-F]{6}$'), published boolean not null default false, updated_at timestamptz not null default now());
create table public.menu_items (id uuid primary key default gen_random_uuid(), restaurant_id uuid not null references public.restaurants(id) on delete cascade, name text not null check (length(trim(name)) between 1 and 120), description text not null default '' check (length(description)<=500), category text not null default 'المنيو' check (length(category) between 1 and 80), price_iqd numeric(12,2) not null check (price_iqd>=0), available boolean not null default true, created_at timestamptz not null default now());
create index menu_items_restaurant_idx on public.menu_items(restaurant_id);
create function private.can_manage_menu(target uuid) returns boolean language sql stable security definer set search_path='' as $$ select private.is_platform_admin() or (private.is_restaurant_manager(target) and exists(select 1 from public.subscriptions s where s.restaurant_id=target and s.status='active' and s.starts_at<=now() and now()<s.ends_at+make_interval(days=>s.grace_days))); $$;
revoke all on function private.can_manage_menu(uuid) from public;
grant execute on function private.can_manage_menu(uuid) to authenticated;
alter table public.restaurant_site_settings enable row level security;
alter table public.menu_items enable row level security;
create policy site_settings_admin on public.restaurant_site_settings for all to authenticated using ((select private.is_platform_admin())) with check ((select private.is_platform_admin()));
create policy menu_items_access on public.menu_items for all to authenticated using (private.can_manage_menu(restaurant_id)) with check (private.can_manage_menu(restaurant_id));
create function public.get_restaurant_site(p_slug text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.restaurants%rowtype; settings public.restaurant_site_settings%rowtype; items jsonb;
begin
 select * into r from public.restaurants where slug=p_slug;
 if not found then return jsonb_build_object('status','unavailable'); end if;
 select * into settings from public.restaurant_site_settings where restaurant_id=r.id and published=true;
 if not found or not exists (select 1 from public.subscriptions s where s.restaurant_id=r.id and s.status='active' and s.starts_at<=now() and now()<s.ends_at+make_interval(days=>s.grace_days)) then return jsonb_build_object('status','unavailable'); end if;
 select coalesce(jsonb_agg(jsonb_build_object('name',i.name,'description',i.description,'category',i.category,'price_iqd',i.price_iqd) order by i.category,i.created_at,i.id),'[]'::jsonb) into items from public.menu_items i where i.restaurant_id=r.id and i.available;
 return jsonb_build_object('status','available','name',r.name,'headline',settings.headline,'description',settings.description,'phone',settings.phone,'address',settings.address,'hero_image_url',settings.hero_image_url,'accent_color',settings.accent_color,'items',items);
end; $$;
revoke all on function public.get_restaurant_site(text) from public;
grant execute on function public.get_restaurant_site(text) to anon,authenticated;
