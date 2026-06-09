begin;

create extension if not exists pgcrypto;

create table public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  city text not null,
  province text not null,
  postal_code text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  phone_number text not null unique
    check (phone_number ~ '^\+62[0-9]{8,13}$'),
  role text not null default 'member'
    check (role in ('super_admin', 'admin', 'member')),
  community_id uuid references public.communities(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payment_accounts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  bank_name text not null,
  account_number text not null check (account_number ~ '^[0-9]+$'),
  account_holder_name text not null,
  branch_name text,
  payment_instruction text,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index payment_accounts_one_active_default
  on public.payment_accounts (community_id)
  where is_default and is_active;

create table public.community_members (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  phone_number text not null
    check (phone_number ~ '^\+62[0-9]{8,13}$'),
  house_block text not null,
  house_number text not null,
  family_count integer not null default 1 check (family_count > 0),
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (community_id, house_block, house_number)
);

create index community_members_community_idx
  on public.community_members (community_id, status);
create index community_members_search_idx
  on public.community_members (community_id, full_name, phone_number);

create table public.dues (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  description text,
  month integer not null check (month between 1 and 12),
  year integer not null check (year between 2020 and 2100),
  amount numeric(14, 2) not null check (amount > 0),
  due_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (community_id, title, month, year)
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  dues_id uuid not null references public.dues(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  member_id uuid not null references public.community_members(id) on delete restrict,
  amount numeric(14, 2) not null check (amount > 0),
  status text not null default 'unpaid'
    check (status in ('unpaid', 'waiting_verification', 'paid', 'rejected')),
  selected_payment_account_id uuid references public.payment_accounts(id),
  payment_date date,
  payment_method text,
  payment_proof_url text,
  admin_note text,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (dues_id, member_id)
);

create index bills_community_status_idx
  on public.bills (community_id, status);
create index bills_member_idx on public.bills (member_id);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  description text,
  amount numeric(14, 2) not null check (amount > 0),
  expense_date date not null,
  receipt_image_url text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index expenses_community_date_idx
  on public.expenses (community_id, expense_date desc);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  title text not null,
  content text not null,
  is_pinned boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index announcements_community_idx
  on public.announcements (community_id, is_pinned desc, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger communities_set_updated_at
before update on public.communities
for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();
create trigger payment_accounts_set_updated_at
before update on public.payment_accounts
for each row execute function public.set_updated_at();
create trigger community_members_set_updated_at
before update on public.community_members
for each row execute function public.set_updated_at();
create trigger dues_set_updated_at
before update on public.dues
for each row execute function public.set_updated_at();
create trigger bills_set_updated_at
before update on public.bills
for each row execute function public.set_updated_at();
create trigger expenses_set_updated_at
before update on public.expenses
for each row execute function public.set_updated_at();
create trigger announcements_set_updated_at
before update on public.announcements
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  supplied_phone text;
begin
  supplied_phone := new.raw_user_meta_data ->> 'phone_number';
  if supplied_phone is null or supplied_phone !~ '^\+62[0-9]{8,13}$' then
    raise exception 'Nomor handphone Indonesia tidak valid.';
  end if;

  insert into public.profiles (
    id,
    full_name,
    email,
    phone_number,
    role
  )
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Pengguna KasWarga'),
    lower(new.email),
    supplied_phone,
    'member'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_community_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
  select community_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(public.current_role() = 'super_admin', false);
$$;

create or replace function public.can_manage_community(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.is_super_admin()
    or (
      public.current_role() = 'admin'
      and public.current_community_id() = target_community_id
    );
$$;

create or replace function public.current_member_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
  select id
  from public.community_members
  where user_id = auth.uid()
  limit 1;
$$;

revoke all on function public.current_role() from public;
revoke all on function public.current_community_id() from public;
revoke all on function public.is_super_admin() from public;
revoke all on function public.can_manage_community(uuid) from public;
revoke all on function public.current_member_id() from public;
grant execute on function public.current_role() to authenticated;
grant execute on function public.current_community_id() to authenticated;
grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.can_manage_community(uuid) to authenticated;
grant execute on function public.current_member_id() to authenticated;

create or replace function public.protect_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or public.is_super_admin() then
    return new;
  end if;

  if auth.uid() = old.id then
    new.role := old.role;
    new.community_id := old.community_id;
    new.email := old.email;
    return new;
  end if;

  if public.current_role() = 'admin'
     and old.community_id = public.current_community_id()
     and new.community_id = old.community_id
     and new.role in ('admin', 'member') then
    return new;
  end if;

  raise exception 'Perubahan role atau komunitas tidak diizinkan.';
end;
$$;

create trigger profiles_protect_privileges
before update on public.profiles
for each row execute function public.protect_profile_privileges();

create or replace function public.protect_member_bill_update()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  account_is_valid boolean;
begin
  if public.can_manage_community(old.community_id) then
    return new;
  end if;

  if old.member_id <> public.current_member_id() then
    raise exception 'Tagihan ini tidak dapat diubah.';
  end if;
  if old.status not in ('unpaid', 'rejected') then
    raise exception 'Status tagihan tidak dapat diubah kembali.';
  end if;

  new.dues_id := old.dues_id;
  new.community_id := old.community_id;
  new.member_id := old.member_id;
  new.amount := old.amount;
  new.status := 'waiting_verification';
  new.payment_method := 'bank_transfer';
  new.admin_note := null;
  new.verified_by := null;
  new.verified_at := null;

  select exists (
    select 1
    from public.payment_accounts account
    where account.id = new.selected_payment_account_id
      and account.community_id = old.community_id
      and account.is_active = true
  ) into account_is_valid;

  if not account_is_valid
     or new.payment_date is null
     or nullif(new.payment_proof_url, '') is null then
    raise exception 'Rekening, tanggal, dan bukti pembayaran wajib diisi.';
  end if;

  return new;
end;
$$;

create trigger bills_protect_member_update
before update on public.bills
for each row execute function public.protect_member_bill_update();

create or replace function public.ensure_one_default_payment_account()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.is_default and new.is_active then
    update public.payment_accounts
    set is_default = false
    where community_id = new.community_id
      and id <> new.id
      and is_default = true;
  end if;
  if not new.is_active then
    new.is_default := false;
  end if;
  return new;
end;
$$;

create trigger payment_accounts_default_guard
before insert or update on public.payment_accounts
for each row execute function public.ensure_one_default_payment_account();

create or replace function public.get_email_by_phone(normalized_phone text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  matched_email text;
begin
  if normalized_phone is null
     or normalized_phone !~ '^\+62[0-9]{8,13}$' then
    return null;
  end if;

  select email
  into matched_email
  from public.profiles
  where phone_number = normalized_phone
  limit 1;

  return matched_email;
end;
$$;

revoke all on function public.get_email_by_phone(text) from public;
grant execute on function public.get_email_by_phone(text) to anon, authenticated;

create or replace function public.generate_bills_for_due(target_due_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_due public.dues%rowtype;
  inserted_count integer;
begin
  select * into target_due from public.dues where id = target_due_id;
  if target_due.id is null then
    raise exception 'Iuran tidak ditemukan.';
  end if;
  if not public.can_manage_community(target_due.community_id) then
    raise exception 'Tidak memiliki akses ke komunitas ini.';
  end if;

  insert into public.bills (
    dues_id,
    community_id,
    member_id,
    amount,
    status
  )
  select
    target_due.id,
    target_due.community_id,
    member.id,
    target_due.amount,
    'unpaid'
  from public.community_members member
  where member.community_id = target_due.community_id
    and member.status = 'active'
  on conflict (dues_id, member_id) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

revoke all on function public.generate_bills_for_due(uuid) from public;
grant execute on function public.generate_bills_for_due(uuid) to authenticated;

create or replace function public.verify_bill_payment(
  target_bill_id uuid,
  approved boolean,
  rejection_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_bill public.bills%rowtype;
begin
  select * into target_bill from public.bills where id = target_bill_id for update;
  if target_bill.id is null then
    raise exception 'Tagihan tidak ditemukan.';
  end if;
  if not public.can_manage_community(target_bill.community_id) then
    raise exception 'Tidak memiliki akses verifikasi.';
  end if;
  if target_bill.status <> 'waiting_verification' then
    raise exception 'Tagihan tidak sedang menunggu verifikasi.';
  end if;
  if not approved and nullif(trim(rejection_note), '') is null then
    raise exception 'Alasan penolakan wajib diisi.';
  end if;

  update public.bills
  set
    status = case when approved then 'paid' else 'rejected' end,
    admin_note = case when approved then null else trim(rejection_note) end,
    verified_by = auth.uid(),
    verified_at = now()
  where id = target_bill_id;
end;
$$;

revoke all on function public.verify_bill_payment(uuid, boolean, text) from public;
grant execute on function public.verify_bill_payment(uuid, boolean, text)
  to authenticated;

create or replace function public.get_community_cash_summary()
returns table (
  total_paid numeric,
  total_unpaid numeric,
  total_expenses numeric,
  balance numeric
)
language sql
stable
security definer
set search_path = public, auth
as $$
  with scope as (
    select public.current_community_id() as community_id
  ),
  income as (
    select
      coalesce(sum(amount) filter (where status = 'paid'), 0) as total_paid,
      coalesce(sum(amount) filter (where status <> 'paid'), 0) as total_unpaid
    from public.bills, scope
    where bills.community_id = scope.community_id
  ),
  outcome as (
    select coalesce(sum(amount), 0) as total_expenses
    from public.expenses, scope
    where expenses.community_id = scope.community_id
  )
  select
    income.total_paid,
    income.total_unpaid,
    outcome.total_expenses,
    income.total_paid - outcome.total_expenses
  from income cross join outcome;
$$;

revoke all on function public.get_community_cash_summary() from public;
grant execute on function public.get_community_cash_summary() to authenticated;

alter table public.communities enable row level security;
alter table public.profiles enable row level security;
alter table public.payment_accounts enable row level security;
alter table public.community_members enable row level security;
alter table public.dues enable row level security;
alter table public.bills enable row level security;
alter table public.expenses enable row level security;
alter table public.announcements enable row level security;

create policy communities_select on public.communities
for select to authenticated
using (
  public.is_super_admin()
  or id = public.current_community_id()
);
create policy communities_insert on public.communities
for insert to authenticated
with check (public.is_super_admin());
create policy communities_update on public.communities
for update to authenticated
using (public.is_super_admin() or public.can_manage_community(id))
with check (public.is_super_admin() or public.can_manage_community(id));

create policy profiles_select on public.profiles
for select to authenticated
using (
  public.is_super_admin()
  or id = auth.uid()
  or (
    public.current_role() = 'admin'
    and community_id = public.current_community_id()
  )
);
create policy profiles_update on public.profiles
for update to authenticated
using (
  public.is_super_admin()
  or id = auth.uid()
  or (
    public.current_role() = 'admin'
    and community_id = public.current_community_id()
  )
)
with check (
  public.is_super_admin()
  or id = auth.uid()
  or (
    public.current_role() = 'admin'
    and community_id = public.current_community_id()
  )
);

create policy payment_accounts_select on public.payment_accounts
for select to authenticated
using (
  public.is_super_admin()
  or public.can_manage_community(community_id)
  or (
    community_id = public.current_community_id()
    and is_active = true
  )
);
create policy payment_accounts_insert on public.payment_accounts
for insert to authenticated
with check (public.can_manage_community(community_id));
create policy payment_accounts_update on public.payment_accounts
for update to authenticated
using (public.can_manage_community(community_id))
with check (public.can_manage_community(community_id));
create policy payment_accounts_delete on public.payment_accounts
for delete to authenticated
using (public.can_manage_community(community_id));

create policy community_members_select on public.community_members
for select to authenticated
using (
  public.is_super_admin()
  or public.can_manage_community(community_id)
  or user_id = auth.uid()
);
create policy community_members_insert on public.community_members
for insert to authenticated
with check (public.can_manage_community(community_id));
create policy community_members_update on public.community_members
for update to authenticated
using (public.can_manage_community(community_id))
with check (public.can_manage_community(community_id));
create policy community_members_delete on public.community_members
for delete to authenticated
using (public.can_manage_community(community_id));

create policy dues_select on public.dues
for select to authenticated
using (
  public.is_super_admin()
  or public.can_manage_community(community_id)
  or community_id = public.current_community_id()
);
create policy dues_insert on public.dues
for insert to authenticated
with check (public.can_manage_community(community_id));
create policy dues_update on public.dues
for update to authenticated
using (public.can_manage_community(community_id))
with check (public.can_manage_community(community_id));
create policy dues_delete on public.dues
for delete to authenticated
using (public.can_manage_community(community_id));

create policy bills_select on public.bills
for select to authenticated
using (
  public.is_super_admin()
  or public.can_manage_community(community_id)
  or member_id = public.current_member_id()
);
create policy bills_insert on public.bills
for insert to authenticated
with check (public.can_manage_community(community_id));
create policy bills_update_admin on public.bills
for update to authenticated
using (public.can_manage_community(community_id))
with check (public.can_manage_community(community_id));
create policy bills_update_member_payment on public.bills
for update to authenticated
using (member_id = public.current_member_id())
with check (
  member_id = public.current_member_id()
  and community_id = public.current_community_id()
  and status = 'waiting_verification'
  and selected_payment_account_id is not null
  and payment_date is not null
  and payment_proof_url is not null
);

create policy expenses_select on public.expenses
for select to authenticated
using (
  public.is_super_admin()
  or public.can_manage_community(community_id)
);
create policy expenses_insert on public.expenses
for insert to authenticated
with check (public.can_manage_community(community_id));
create policy expenses_update on public.expenses
for update to authenticated
using (public.can_manage_community(community_id))
with check (public.can_manage_community(community_id));
create policy expenses_delete on public.expenses
for delete to authenticated
using (public.can_manage_community(community_id));

create policy announcements_select on public.announcements
for select to authenticated
using (
  public.is_super_admin()
  or community_id = public.current_community_id()
);
create policy announcements_insert on public.announcements
for insert to authenticated
with check (public.can_manage_community(community_id));
create policy announcements_update on public.announcements
for update to authenticated
using (public.can_manage_community(community_id))
with check (public.can_manage_community(community_id));
create policy announcements_delete on public.announcements
for delete to authenticated
using (public.can_manage_community(community_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment_proofs',
  'payment_proofs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'expense_receipts',
  'expense_receipts',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy payment_proofs_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'payment_proofs'
  and (storage.foldername(name))[1] = public.current_community_id()::text
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or public.can_manage_community(public.current_community_id())
  )
);
create policy payment_proofs_select on storage.objects
for select to authenticated
using (
  bucket_id = 'payment_proofs'
  and (
    public.is_super_admin()
    or (
      (storage.foldername(name))[1] = public.current_community_id()::text
      and (
        (storage.foldername(name))[2] = auth.uid()::text
        or public.can_manage_community(public.current_community_id())
      )
    )
  )
);

create policy expense_receipts_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'expense_receipts'
  and (storage.foldername(name))[1] = public.current_community_id()::text
  and public.can_manage_community(public.current_community_id())
);
create policy expense_receipts_select on storage.objects
for select to authenticated
using (
  bucket_id = 'expense_receipts'
  and (
    public.is_super_admin()
    or (
      (storage.foldername(name))[1] = public.current_community_id()::text
      and public.can_manage_community(public.current_community_id())
    )
  )
);

commit;
