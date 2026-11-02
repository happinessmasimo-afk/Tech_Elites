-- Single-farmer model: exactly one account can publish/manage listings
-- ("farmer"); everyone else who signs up is a "buyer" who can browse and
-- make offers but never create, edit, or delete listings.

alter table public.profiles
  add column if not exists role text not null default 'buyer' check (role in ('farmer', 'buyer'));

comment on column public.profiles.role is
  'farmer: the one account allowed to publish/manage listings. buyer: everyone else (default for all new signups).';

-- Replace the write policies on listings so they also require the caller's
-- profile to have role = 'farmer' — this is enforced by Postgres itself,
-- not just hidden in the app UI, so a buyer calling the API directly still
-- can't create/edit/delete a listing.
drop policy if exists "listings_insert_own" on public.listings;
create policy "listings_insert_own" on public.listings for insert
  to authenticated with check (
    auth.uid() = owner_id
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'farmer')
  );

drop policy if exists "listings_update_own" on public.listings;
create policy "listings_update_own" on public.listings for update
  using (auth.uid() = owner_id)
  with check (
    auth.uid() = owner_id
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'farmer')
  );

drop policy if exists "listings_delete_own" on public.listings;
create policy "listings_delete_own" on public.listings for delete
  using (
    auth.uid() = owner_id
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'farmer')
  );

-- ---------------------------------------------------------------------
-- ONE-TIME STEP — do this part yourself:
-- Your farmer account already exists from before this migration, so it
-- defaults to 'buyer' like everyone else until you promote it manually.
-- Replace the email below with the one you registered as a farmer with,
-- then run just this one line:
--
--   update public.profiles set role = 'farmer' where email = 'YOUR_FARMER_EMAIL_HERE';
--
-- Every other signup from now on is a buyer automatically — there is no
-- way to become the farmer through the app itself, only through this
-- manual SQL update, since this app is designed for exactly one farmer.
-- ---------------------------------------------------------------------

-- Force PostgREST to pick up the new column(s)/table immediately.
notify pgrst, 'reload schema';
