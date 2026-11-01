-- The moment an offer's payment_status flips to 'paid', automatically mark
-- its listing sold and record the sale price — this is what makes
-- "buyer pays" -> "farmer's listing shows sold" -> "shows up in Finance"
-- happen atomically, without the buyer's own token needing write access
-- to a listing they don't own.
--
-- Why this works under RLS: a buyer updating payment_status on THEIR OWN
-- offer is already allowed (offers_update_buyer policy). This trigger runs
-- as SECURITY DEFINER, owned by the role that runs this migration
-- (normally a superuser in the Supabase SQL editor), so the listings
-- update inside it bypasses RLS instead of needing the buyer to somehow
-- have farmer-level write access.

create or replace function public.handle_offer_paid()
returns trigger as $$
begin
  if new.payment_status = 'paid' and (old.payment_status is distinct from 'paid') then
    update public.listings
    set status = 'sold',
        sold_price = coalesce(new.offer_price, listings.asking_price),
        sold_at = now()
    where id = new.listing_id
      and status <> 'sold';
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_offer_paid on public.listing_offers;
create trigger trg_offer_paid
  after update on public.listing_offers
  for each row execute function public.handle_offer_paid();
