alter table public.restaurant_site_settings add column logo_url text not null default '' check (length(logo_url) <= 1000), add column opening_hours text not null default '' check (length(opening_hours) <= 300);
create or replace function public.get_restaurant_site(p_slug text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.restaurants%rowtype; settings public.restaurant_site_settings%rowtype; items jsonb;
begin
 select * into r from public.restaurants where slug=p_slug;
 if not found then return jsonb_build_object('status','unavailable'); end if;
 select * into settings from public.restaurant_site_settings where restaurant_id=r.id and published=true;
 if not found or not exists (select 1 from public.subscriptions s where s.restaurant_id=r.id and s.status='active' and s.starts_at<=now() and now()<s.ends_at+make_interval(days=>s.grace_days)) then return jsonb_build_object('status','unavailable'); end if;
 select coalesce(jsonb_agg(jsonb_build_object('name',i.name,'description',i.description,'category',i.category,'price_iqd',i.price_iqd) order by i.category,i.created_at,i.id),'[]'::jsonb) into items from public.menu_items i where i.restaurant_id=r.id and i.available;
 return jsonb_build_object('status','available','name',r.name,'headline',settings.headline,'description',settings.description,'phone',settings.phone,'address',settings.address,'hero_image_url',settings.hero_image_url,'logo_url',settings.logo_url,'opening_hours',settings.opening_hours,'accent_color',settings.accent_color,'items',items);
end; $$;
