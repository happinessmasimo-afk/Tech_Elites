-- Bug: once a listing's status leaves 'active' (e.g. it's sold), the buyer
-- who bought it loses visibility of it (only "active" and "owner" policies
-- existed). That broke arranging delivery and viewing a purchased listing.
--
-- Fix: a buyer with an offer on a listing can always see that listing.
--
-- IMPORTANT (this is the corrected version): the policy must NOT query
-- listing_offers directly. listing_offers' own policies query listings, so
-- listings -> listing_offers -> listings loops forever and Postgres aborts
-- with "infinite recursion detected in policy for relation listings"
-- (error 42P17). The SECURITY DEFINER helpers below read the other table
-- without triggering its row-level security, which breaks the loop.

create or replace function public.user_has_offer_on_listing(p_listing_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.listing_offers
    where listing_id = p_listing_id
      and buyer_id = auth.uid()
  );
$$;

create or replace function public.user_owns_listing(p_listing_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.listings
    where id = p_listing_id
      and owner_id = auth.uid()
  );
$$;

grant execute on function public.user_has_offer_on_listing(uuid) to anon, authenticated;
grant execute on function public.user_owns_listing(uuid) to anon, authenticated;

-- Listings: buyer-with-an-offer can see the listing (no direct subquery).
drop policy if exists "listings_select_buyer" on public.listings;
create policy "listings_select_buyer" on public.listings for select
  using (public.user_has_offer_on_listing(id));

-- Offers: replace the policies that queried listings directly, so the
-- cycle can't re-form from the other side either.
drop policy if exists "offers_select_listing_owner" on public.listing_offers;
create policy "offers_select_listing_owner" on public.listing_offers for select
  using (public.user_owns_listing(listing_id));

drop policy if exists "offers_update_listing_owner" on public.listing_offers;
create policy "offers_update_listing_owner" on public.listing_offers for update
  using (public.user_owns_listing(listing_id));

notify pgrst, 'reload schema';
