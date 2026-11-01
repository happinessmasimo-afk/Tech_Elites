-- Tracks whether an accepted offer has been paid via Yoco, and which Yoco
-- checkout session it belongs to (so a confirmation call can look it up).

alter table public.listing_offers
  add column if not exists payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'paid')),
  add column if not exists yoco_checkout_id text;

comment on column public.listing_offers.payment_status is
  'unpaid until the buyer completes a Yoco checkout for this accepted offer.';

-- Force PostgREST to pick up the new column(s)/table immediately.
notify pgrst, 'reload schema';
