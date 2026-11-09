create function public.assign_restaurant_manager(p_restaurant_id uuid, p_email text, p_role text) returns void language plpgsql security definer set search_path = '' as $$
declare account_id uuid;
begin
 if not private.is_platform_admin() then raise exception 'not authorized' using errcode='42501'; end if;
 if p_role is null or p_role not in ('owner','manager') then raise exception 'invalid role' using errcode='22023'; end if;
 select id into account_id from auth.users where lower(email)=lower(trim(p_email)) and email_confirmed_at is not null;
 if account_id is null then raise exception 'confirmed user not found' using errcode='22023'; end if;
 if not exists(select 1 from public.restaurants where id=p_restaurant_id) then raise exception 'restaurant not found' using errcode='22023'; end if;
 insert into public.restaurant_members(restaurant_id,user_id,role) values(p_restaurant_id,account_id,p_role) on conflict (restaurant_id,user_id) do update set role=excluded.role;
end; $$;
revoke all on function public.assign_restaurant_manager(uuid,text,text) from public,anon;
grant execute on function public.assign_restaurant_manager(uuid,text,text) to authenticated;
create function private.is_restaurant_manager(target uuid) returns boolean language sql stable security definer set search_path = '' as $$ select exists (select 1 from public.restaurant_members where restaurant_id=target and user_id=(select auth.uid()) and role in ('owner','manager')); $$;
revoke all on function private.is_restaurant_manager(uuid) from public;
grant execute on function private.is_restaurant_manager(uuid) to authenticated;
drop policy subscriptions_member_read on public.subscriptions;
create policy subscriptions_manager_read on public.subscriptions for select to authenticated using (private.is_restaurant_manager(restaurant_id));
drop policy payments_member_read on public.payment_requests;
create policy payments_manager_read on public.payment_requests for select to authenticated using (private.is_restaurant_manager(restaurant_id));
