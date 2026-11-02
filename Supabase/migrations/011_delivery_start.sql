-- Marks the exact moment a trip begins (buyer starting their pickup
-- journey, or farmer starting a delivery run) — separate from created_at,
-- which is just when pickup/delivery was chosen.

alter table public.deliveries
  add column if not exists started_at timestamptz;

comment on column public.deliveries.started_at is
  'When the traveling party (buyer for pickup, farmer for delivery) tapped Start.';

notify pgrst, 'reload schema';
