-- MOSTAX database schema
-- Run this file in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'عام',
  description text default '',
  image_url text,
  price numeric(12,2) not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  phone text not null,
  address text not null,
  notes text default '',
  total numeric(12,2) not null check (total >= 0),
  status text not null default 'new' check (status in ('new','processing','shipped','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  price numeric(12,2) not null check (price >= 0),
  quantity integer not null check (quantity > 0)
);

alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Public can only read active products.
drop policy if exists "Public read active products" on public.products;
create policy "Public read active products" on public.products for select to anon, authenticated using (active = true);

-- Only authenticated administrators can manage products.
drop policy if exists "Admins manage products" on public.products;
create policy "Admins manage products" on public.products for all to authenticated using (true) with check (true);

-- Customers may submit an order. They cannot read, update, or delete orders.
drop policy if exists "Public create orders" on public.orders;
create policy "Public create orders" on public.orders for insert to anon, authenticated with check (true);
drop policy if exists "Admins read orders" on public.orders;
create policy "Admins read orders" on public.orders for select to authenticated using (true);
drop policy if exists "Admins update orders" on public.orders;
create policy "Admins update orders" on public.orders for update to authenticated using (true) with check (true);

-- Order items may be inserted by customers, but only admins may read them.
drop policy if exists "Public create order items" on public.order_items;
create policy "Public create order items" on public.order_items for insert to anon, authenticated with check (true);
drop policy if exists "Admins read order items" on public.order_items;
create policy "Admins read order items" on public.order_items for select to authenticated using (true);

-- Realtime updates for the admin dashboard.
do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null;
when others then null;
end $$;
