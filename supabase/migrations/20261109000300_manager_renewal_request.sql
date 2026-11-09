create function public.submit_renewal_payment(p_restaurant_id uuid,p_amount numeric,p_currency text,p_method text,p_reference text) returns uuid language plpgsql security definer set search_path = '' as $$
declare request_id uuid;
begin
 if not private.is_restaurant_manager(p_restaurant_id) then raise exception 'not authorized' using errcode='42501'; end if;
 if p_amount is null or p_amount <= 0 or p_amount > 9999999999.99 or p_amount <> round(p_amount,2) or p_currency is null or p_currency not in ('IQD','USD') or p_method is null or p_method not in ('زين كاش','FIB') or p_reference is null or length(trim(p_reference)) < 1 or length(trim(p_reference)) > 100 then raise exception 'invalid payment details' using errcode='22023'; end if;
 perform 1 from public.restaurants where id=p_restaurant_id for update;
 if exists (select 1 from public.payment_requests where restaurant_id=p_restaurant_id and status='pending') then raise exception 'pending request exists' using errcode='23505'; end if;
 insert into public.payment_requests(restaurant_id,amount,currency,method,transaction_reference,status) values(p_restaurant_id,p_amount,p_currency,p_method,trim(p_reference),'pending') returning id into request_id;
 return request_id;
end; $$;
revoke all on function public.submit_renewal_payment(uuid,numeric,text,text,text) from public,anon;
grant execute on function public.submit_renewal_payment(uuid,numeric,text,text,text) to authenticated;
