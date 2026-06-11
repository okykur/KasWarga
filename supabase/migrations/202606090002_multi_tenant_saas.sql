begin;

create extension if not exists pgcrypto;

alter table public.profiles
  add column if not exists avatar_url text;

alter table public.communities
  add column if not exists type text,
  add column if not exists community_code text,
  add column if not exists is_code_join_enabled boolean not null default true,
  add column if not exists require_admin_approval boolean not null default true,
  add column if not exists created_by uuid references public.profiles(id);

update public.communities
set
  type = coalesce(type, 'komunitas_lainnya'),
  community_code = coalesce(
    community_code,
    'KW-' || upper(substr(replace(id::text, '-', ''), 1, 8))
  );

alter table public.communities
  alter column type set not null,
  alter column community_code set not null;

alter table public.communities
  drop constraint if exists communities_type_check;
alter table public.communities
  add constraint communities_type_check check (
    type in (
      'rt_rw',
      'cluster',
      'komplek',
      'apartemen',
      'perhimpunan_warga',
      'masjid',
      'sekolah',
      'komunitas_lainnya'
    )
  );
alter table public.communities
  add constraint communities_code_format_check
  check (community_code ~ '^[A-Z0-9-]{5,30}$');
create unique index if not exists communities_code_unique
  on public.communities (community_code);

create table if not exists public.platform_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.community_memberships (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'treasurer', 'member')),
  status text not null default 'pending'
    check (status in ('active', 'pending', 'rejected', 'inactive')),
  joined_via text not null
    check (
      joined_via in (
        'created_community',
        'invitation_email',
        'community_code',
        'manual_admin'
      )
    ),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (community_id, user_id)
);
create index if not exists community_memberships_user_idx
  on public.community_memberships (user_id, status);
create index if not exists community_memberships_scope_idx
  on public.community_memberships (community_id, role, status);

insert into public.platform_admins (user_id)
select id from public.profiles where role = 'super_admin'
on conflict do nothing;

insert into public.community_memberships (
  community_id,
  user_id,
  role,
  status,
  joined_via,
  approved_by,
  approved_at
)
select
  profile.community_id,
  profile.id,
  case when profile.role = 'admin' then 'owner' else 'member' end,
  'active',
  case
    when profile.role = 'admin' then 'created_community'
    else 'manual_admin'
  end,
  case when profile.role = 'admin' then profile.id else null end,
  now()
from public.profiles profile
where profile.community_id is not null
  and profile.role in ('admin', 'member')
on conflict (community_id, user_id) do nothing;

update public.communities community
set created_by = (
  select membership.user_id
  from public.community_memberships membership
  where membership.community_id = community.id
  order by
    case when membership.role = 'owner' then 0 else 1 end,
    membership.created_at
  limit 1
)
where community.created_by is null;

do $$
begin
  if not exists (
    select 1 from public.communities where created_by is null
  ) then
    alter table public.communities alter column created_by set not null;
  end if;
end;
$$;

create table if not exists public.community_member_details (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  membership_id uuid
    references public.community_memberships(id) on delete set null,
  full_name_in_community text not null,
  phone_number_in_community text not null
    check (phone_number_in_community ~ '^\+62[0-9]{8,13}$'),
  house_block text,
  house_number text,
  family_count integer not null default 1 check (family_count > 0),
  identity_number text,
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (community_id, user_id),
  unique (membership_id)
);

insert into public.community_member_details (
  id,
  community_id,
  user_id,
  membership_id,
  full_name_in_community,
  phone_number_in_community,
  house_block,
  house_number,
  family_count,
  status,
  created_at,
  updated_at
)
select
  member.id,
  member.community_id,
  member.user_id,
  membership.id,
  member.full_name,
  member.phone_number,
  nullif(member.house_block, ''),
  nullif(member.house_number, ''),
  member.family_count,
  member.status,
  member.created_at,
  member.updated_at
from public.community_members member
left join public.community_memberships membership
  on membership.community_id = member.community_id
 and membership.user_id = member.user_id
on conflict (id) do nothing;

alter table public.bills
  drop constraint if exists bills_member_id_fkey;
alter table public.bills
  add constraint bills_member_id_fkey
  foreign key (member_id)
  references public.community_member_details(id)
  on delete restrict;

drop trigger if exists bills_protect_member_update on public.bills;
drop function if exists public.protect_member_bill_update();
drop function if exists public.generate_bills_for_due(uuid);
drop function if exists public.current_member_id() cascade;
drop trigger if exists community_members_set_updated_at
  on public.community_members;
drop table if exists public.community_members;

create table if not exists public.community_invitations (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  invited_email text not null,
  invited_phone_number text,
  invited_full_name text,
  role text not null check (role in ('admin', 'treasurer', 'member')),
  invitation_token text not null unique
    default encode(gen_random_bytes(32), 'hex'),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'expired', 'cancelled')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  invited_by uuid not null references public.profiles(id),
  accepted_by uuid references public.profiles(id),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists community_invitations_scope_idx
  on public.community_invitations (community_id, status);

create table if not exists public.community_join_requests (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_note text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (community_id, user_id)
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  price_monthly numeric(14, 2) not null default 0 check (price_monthly >= 0),
  max_members integer,
  max_admins integer,
  max_communities integer,
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_subscriptions (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null unique
    references public.communities(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null default 'trial'
    check (status in ('trial', 'active', 'past_due', 'cancelled', 'expired')),
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.subscription_plans (
  name,
  code,
  price_monthly,
  max_members,
  max_admins,
  max_communities,
  features
)
values
  (
    'Free',
    'free',
    0,
    30,
    2,
    1,
    '{
      "iuran_bulanan": true,
      "upload_bukti_pembayaran": true,
      "pengumuman": true,
      "laporan_csv": true
    }'::jsonb
  ),
  (
    'Pro',
    'pro',
    99000,
    500,
    10,
    5,
    '{
      "semua_fitur_free": true,
      "dukungan_prioritas": true,
      "laporan_lanjutan": true
    }'::jsonb
  )
on conflict (code) do update set
  name = excluded.name,
  price_monthly = excluded.price_monthly,
  max_members = excluded.max_members,
  max_admins = excluded.max_admins,
  max_communities = excluded.max_communities,
  features = excluded.features;

insert into public.community_subscriptions (
  community_id,
  plan_id,
  status,
  trial_ends_at
)
select
  community.id,
  plan.id,
  'trial',
  now() + interval '14 days'
from public.communities community
cross join public.subscription_plans plan
where plan.code = 'free'
on conflict (community_id) do nothing;

create trigger community_memberships_set_updated_at
before update on public.community_memberships
for each row execute function public.set_updated_at();
create trigger community_member_details_set_updated_at
before update on public.community_member_details
for each row execute function public.set_updated_at();
create trigger community_invitations_set_updated_at
before update on public.community_invitations
for each row execute function public.set_updated_at();
create trigger community_join_requests_set_updated_at
before update on public.community_join_requests
for each row execute function public.set_updated_at();
create trigger subscription_plans_set_updated_at
before update on public.subscription_plans
for each row execute function public.set_updated_at();
create trigger community_subscriptions_set_updated_at
before update on public.community_subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists profiles_protect_privileges on public.profiles;
drop function if exists public.protect_profile_privileges();
drop function if exists public.current_role() cascade;
drop function if exists public.current_community_id() cascade;
drop function if exists public.is_super_admin() cascade;
drop function if exists public.can_manage_community(uuid) cascade;
drop function if exists public.current_member_id() cascade;

alter table public.profiles
  drop column if exists role,
  drop column if exists community_id;

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
    phone_number
  )
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      'Pengguna KasWarga'
    ),
    lower(new.email),
    supplied_phone
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.is_platform_super_admin(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1 from public.platform_admins admin
    where admin.user_id = target_user_id
  );
$$;

create or replace function public.is_community_member(
  target_user_id uuid,
  target_community_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.community_memberships membership
    where membership.user_id = target_user_id
      and membership.community_id = target_community_id
      and membership.status = 'active'
  );
$$;

create or replace function public.has_community_role(
  target_user_id uuid,
  target_community_id uuid,
  target_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.community_memberships membership
    where membership.user_id = target_user_id
      and membership.community_id = target_community_id
      and membership.status = 'active'
      and membership.role = any(target_roles)
  );
$$;

create or replace function public.get_user_active_communities(
  target_user_id uuid
)
returns table (
  membership_id uuid,
  community_id uuid,
  role text,
  community_name text,
  community_code text
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    membership.id,
    community.id,
    membership.role,
    community.name,
    community.community_code
  from public.community_memberships membership
  join public.communities community on community.id = membership.community_id
  where membership.user_id = target_user_id
    and membership.status = 'active'
    and community.is_active = true
  order by community.name;
$$;

create or replace function public.can_add_member(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  with limits as (
    select plan.max_members
    from public.community_subscriptions subscription
    join public.subscription_plans plan on plan.id = subscription.plan_id
    where subscription.community_id = target_community_id
      and subscription.status in ('trial', 'active')
  )
  select coalesce(
    (select max_members is null or (
      select count(*)
      from public.community_memberships membership
      where membership.community_id = target_community_id
        and membership.status = 'active'
    ) < max_members from limits),
    false
  );
$$;

create or replace function public.can_add_admin(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  with limits as (
    select plan.max_admins
    from public.community_subscriptions subscription
    join public.subscription_plans plan on plan.id = subscription.plan_id
    where subscription.community_id = target_community_id
      and subscription.status in ('trial', 'active')
  )
  select coalesce(
    (select max_admins is null or (
      select count(*)
      from public.community_memberships membership
      where membership.community_id = target_community_id
        and membership.status = 'active'
        and membership.role in ('owner', 'admin', 'treasurer')
    ) < max_admins from limits),
    false
  );
$$;

create or replace function public.can_create_community(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select (
    select count(*)
    from public.community_memberships membership
    where membership.user_id = target_user_id
      and membership.role = 'owner'
      and membership.status = 'active'
  ) < 3;
$$;

create or replace function public.create_community_with_owner(
  community_name text,
  community_type text,
  community_address text,
  community_city text,
  community_province text,
  community_postal_code text,
  requested_code text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  new_community_id uuid;
  new_membership_id uuid;
  free_plan_id uuid;
  current_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Login diperlukan.';
  end if;
  if not public.can_create_community(auth.uid()) then
    raise exception 'Batas pembuatan komunitas sudah tercapai.';
  end if;
  if requested_code !~ '^[A-Z0-9-]{5,30}$' then
    raise exception 'Kode komunitas belum valid.';
  end if;

  select * into current_profile
  from public.profiles
  where id = auth.uid();

  insert into public.communities (
    name,
    type,
    address,
    city,
    province,
    postal_code,
    community_code,
    created_by
  )
  values (
    trim(community_name),
    community_type,
    trim(community_address),
    trim(community_city),
    trim(community_province),
    trim(community_postal_code),
    upper(trim(requested_code)),
    auth.uid()
  )
  returning id into new_community_id;

  insert into public.community_memberships (
    community_id,
    user_id,
    role,
    status,
    joined_via,
    approved_by,
    approved_at
  )
  values (
    new_community_id,
    auth.uid(),
    'owner',
    'active',
    'created_community',
    auth.uid(),
    now()
  )
  returning id into new_membership_id;

  insert into public.community_member_details (
    community_id,
    user_id,
    membership_id,
    full_name_in_community,
    phone_number_in_community
  )
  values (
    new_community_id,
    auth.uid(),
    new_membership_id,
    current_profile.full_name,
    current_profile.phone_number
  );

  select id into free_plan_id
  from public.subscription_plans
  where code = 'free';

  insert into public.community_subscriptions (
    community_id,
    plan_id,
    status,
    trial_ends_at
  )
  values (
    new_community_id,
    free_plan_id,
    'trial',
    now() + interval '14 days'
  );

  return new_membership_id;
exception
  when unique_violation then
    raise exception 'Kode komunitas sudah digunakan.';
end;
$$;

create or replace function public.get_community_by_code(requested_code text)
returns table (
  id uuid,
  name text,
  type text,
  address text,
  city text,
  province text,
  postal_code text,
  community_code text,
  is_code_join_enabled boolean,
  require_admin_approval boolean,
  is_active boolean,
  created_by uuid
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    community.id,
    community.name,
    community.type,
    community.address,
    community.city,
    community.province,
    community.postal_code,
    community.community_code,
    community.is_code_join_enabled,
    community.require_admin_approval,
    community.is_active,
    community.created_by
  from public.communities community
  where community.community_code = upper(trim(requested_code))
  limit 1;
$$;

create or replace function public.join_community_by_code(
  requested_code text,
  request_note text default null
)
returns text
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  target_community public.communities%rowtype;
  new_membership_id uuid;
  current_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Login diperlukan.';
  end if;
  select * into target_community
  from public.communities
  where community_code = upper(trim(requested_code));
  if target_community.id is null then
    raise exception 'Kode komunitas tidak ditemukan.';
  end if;
  if not target_community.is_active then
    raise exception 'Komunitas ini sedang tidak aktif.';
  end if;
  if not target_community.is_code_join_enabled then
    raise exception 'Komunitas ini tidak menerima pendaftaran melalui kode.';
  end if;
  if exists (
    select 1 from public.community_memberships
    where community_id = target_community.id and user_id = auth.uid()
  ) then
    raise exception 'Anda sudah tergabung dalam komunitas ini.';
  end if;
  if not public.can_add_member(target_community.id) then
    raise exception 'Batas anggota plan komunitas sudah tercapai.';
  end if;

  insert into public.community_memberships (
    community_id,
    user_id,
    role,
    status,
    joined_via,
    approved_at
  )
  values (
    target_community.id,
    auth.uid(),
    'member',
    case
      when target_community.require_admin_approval then 'pending'
      else 'active'
    end,
    'community_code',
    case
      when target_community.require_admin_approval then null
      else now()
    end
  )
  returning id into new_membership_id;

  if target_community.require_admin_approval then
    insert into public.community_join_requests (
      community_id,
      user_id,
      request_note
    )
    values (target_community.id, auth.uid(), nullif(trim(request_note), ''));
    return 'pending';
  end if;

  select * into current_profile
  from public.profiles
  where id = auth.uid();
  insert into public.community_member_details (
    community_id,
    user_id,
    membership_id,
    full_name_in_community,
    phone_number_in_community
  )
  values (
    target_community.id,
    auth.uid(),
    new_membership_id,
    current_profile.full_name,
    current_profile.phone_number
  );
  return 'active';
end;
$$;

create or replace function public.get_invitation_by_token(requested_token text)
returns table (
  id uuid,
  community_id uuid,
  invited_email text,
  invited_phone_number text,
  invited_full_name text,
  role text,
  invitation_token text,
  status text,
  expires_at timestamptz,
  communities jsonb
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    invitation.id,
    invitation.community_id,
    invitation.invited_email,
    invitation.invited_phone_number,
    invitation.invited_full_name,
    invitation.role,
    invitation.invitation_token,
    case
      when invitation.status = 'pending' and invitation.expires_at < now()
        then 'expired'
      else invitation.status
    end,
    invitation.expires_at,
    jsonb_build_object('name', community.name)
  from public.community_invitations invitation
  join public.communities community on community.id = invitation.community_id
  where invitation.invitation_token = requested_token
  limit 1;
$$;

create or replace function public.accept_community_invitation(
  requested_token text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  invitation public.community_invitations%rowtype;
  current_profile public.profiles%rowtype;
  new_membership_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Login diperlukan.';
  end if;
  select * into invitation
  from public.community_invitations
  where invitation_token = requested_token
  for update;
  if invitation.id is null then
    raise exception 'Undangan tidak valid.';
  end if;
  if invitation.status <> 'pending' then
    raise exception 'Undangan tidak dapat digunakan.';
  end if;
  if invitation.expires_at < now() then
    update public.community_invitations
    set status = 'expired'
    where id = invitation.id;
    raise exception 'Undangan sudah kedaluwarsa.';
  end if;
  select * into current_profile
  from public.profiles where id = auth.uid();
  if lower(current_profile.email) <> lower(invitation.invited_email) then
    raise exception 'Undangan ini dikirim ke email berbeda.';
  end if;
  if exists (
    select 1 from public.community_memberships
    where community_id = invitation.community_id and user_id = auth.uid()
  ) then
    raise exception 'Anda sudah tergabung dalam komunitas ini.';
  end if;
  if invitation.role = 'member'
     and not public.can_add_member(invitation.community_id) then
    raise exception 'Batas anggota plan komunitas sudah tercapai.';
  end if;
  if invitation.role <> 'member'
     and not public.can_add_admin(invitation.community_id) then
    raise exception 'Batas admin plan komunitas sudah tercapai.';
  end if;

  insert into public.community_memberships (
    community_id,
    user_id,
    role,
    status,
    joined_via,
    approved_by,
    approved_at
  )
  values (
    invitation.community_id,
    auth.uid(),
    invitation.role,
    'active',
    'invitation_email',
    invitation.invited_by,
    now()
  )
  returning id into new_membership_id;

  insert into public.community_member_details (
    community_id,
    user_id,
    membership_id,
    full_name_in_community,
    phone_number_in_community
  )
  values (
    invitation.community_id,
    auth.uid(),
    new_membership_id,
    coalesce(invitation.invited_full_name, current_profile.full_name),
    coalesce(invitation.invited_phone_number, current_profile.phone_number)
  );

  update public.community_invitations
  set
    status = 'accepted',
    accepted_by = auth.uid(),
    accepted_at = now()
  where id = invitation.id;
  return new_membership_id;
end;
$$;

create or replace function public.review_community_join_request(
  target_request_id uuid,
  approved boolean,
  rejection_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  target_request public.community_join_requests%rowtype;
  membership public.community_memberships%rowtype;
  target_profile public.profiles%rowtype;
begin
  select * into target_request
  from public.community_join_requests
  where id = target_request_id
  for update;
  if target_request.id is null then
    raise exception 'Permintaan bergabung tidak ditemukan.';
  end if;
  if not public.has_community_role(
    auth.uid(),
    target_request.community_id,
    array['owner', 'admin']
  ) then
    raise exception 'Tidak memiliki akses review.';
  end if;
  if target_request.status <> 'pending' then
    raise exception 'Permintaan sudah ditinjau.';
  end if;
  if not approved and nullif(trim(rejection_reason), '') is null then
    raise exception 'Alasan penolakan wajib diisi.';
  end if;
  if approved and not public.can_add_member(target_request.community_id) then
    raise exception 'Batas anggota plan komunitas sudah tercapai.';
  end if;

  select * into membership
  from public.community_memberships
  where community_id = target_request.community_id
    and user_id = target_request.user_id
  for update;

  update public.community_join_requests
  set
    status = case when approved then 'approved' else 'rejected' end,
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    rejection_reason = case
      when approved then null
      else trim(rejection_reason)
    end
  where id = target_request.id;

  update public.community_memberships
  set
    status = case when approved then 'active' else 'rejected' end,
    approved_by = case when approved then auth.uid() else null end,
    approved_at = case when approved then now() else null end
  where id = membership.id;

  if approved then
    select * into target_profile
    from public.profiles where id = target_request.user_id;
    insert into public.community_member_details (
      community_id,
      user_id,
      membership_id,
      full_name_in_community,
      phone_number_in_community
    )
    values (
      target_request.community_id,
      target_request.user_id,
      membership.id,
      target_profile.full_name,
      target_profile.phone_number
    )
    on conflict (community_id, user_id) do nothing;
  end if;
end;
$$;

create or replace function public.protect_community_membership_role()
returns trigger
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  active_owner_count integer;
begin
  if tg_op = 'INSERT' then
    if new.role = 'owner'
       and new.joined_via <> 'created_community'
       and not public.has_community_role(
         auth.uid(),
         new.community_id,
         array['owner']
       ) then
      raise exception 'Hanya owner yang dapat mengangkat owner baru.';
    end if;
    return new;
  end if;

  if old.role = 'owner'
     and old.status = 'active'
     and (new.role <> 'owner' or new.status <> 'active') then
    select count(*) into active_owner_count
    from public.community_memberships
    where community_id = old.community_id
      and role = 'owner'
      and status = 'active';
    if active_owner_count <= 1 then
      raise exception 'Komunitas harus memiliki minimal satu owner aktif.';
    end if;
  end if;
  if new.role = 'owner'
     and old.role <> 'owner'
     and not public.has_community_role(
       auth.uid(),
       old.community_id,
       array['owner']
     ) then
    raise exception 'Hanya owner yang dapat mengangkat owner baru.';
  end if;
  if old.role = 'owner'
     and not public.has_community_role(
       auth.uid(),
       old.community_id,
       array['owner']
     )
     and auth.uid() is not null then
    raise exception 'Admin tidak dapat mengubah role owner.';
  end if;
  return new;
end;
$$;

create trigger community_membership_role_guard
before insert or update on public.community_memberships
for each row execute function public.protect_community_membership_role();

create or replace function public.validate_community_invitation()
returns trigger
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if not public.has_community_role(
    auth.uid(),
    new.community_id,
    array['owner', 'admin']
  ) then
    raise exception 'Tidak memiliki akses mengundang.';
  end if;
  if new.role = 'admin'
     and not public.has_community_role(
       auth.uid(),
       new.community_id,
       array['owner']
     ) then
    raise exception 'Hanya owner yang dapat mengundang admin.';
  end if;
  if new.role = 'member' and not public.can_add_member(new.community_id) then
    raise exception 'Batas anggota plan komunitas sudah tercapai.';
  end if;
  if new.role <> 'member' and not public.can_add_admin(new.community_id) then
    raise exception 'Batas admin plan komunitas sudah tercapai.';
  end if;
  new.invited_email := lower(trim(new.invited_email));
  new.expires_at := coalesce(new.expires_at, now() + interval '7 days');
  return new;
end;
$$;

create trigger community_invitation_guard
before insert on public.community_invitations
for each row execute function public.validate_community_invitation();

drop trigger if exists bills_protect_member_update on public.bills;
drop function if exists public.protect_member_bill_update();
create or replace function public.protect_member_bill_update()
returns trigger
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  account_is_valid boolean;
  owns_bill boolean;
begin
  if public.has_community_role(
    auth.uid(),
    old.community_id,
    array['owner', 'admin', 'treasurer']
  ) or public.is_platform_super_admin(auth.uid()) then
    return new;
  end if;

  select exists (
    select 1
    from public.community_member_details detail
    where detail.id = old.member_id
      and detail.user_id = auth.uid()
      and detail.community_id = old.community_id
  ) into owns_bill;
  if not owns_bill then
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

create or replace function public.generate_bills_for_due(target_due_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  target_due public.dues%rowtype;
  inserted_count integer;
begin
  select * into target_due from public.dues where id = target_due_id;
  if target_due.id is null then
    raise exception 'Iuran tidak ditemukan.';
  end if;
  if not public.has_community_role(
    auth.uid(),
    target_due.community_id,
    array['owner', 'admin', 'treasurer']
  ) then
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
    detail.id,
    target_due.amount,
    'unpaid'
  from public.community_member_details detail
  join public.community_memberships membership
    on membership.id = detail.membership_id
  where detail.community_id = target_due.community_id
    and detail.status = 'active'
    and membership.status = 'active'
  on conflict (dues_id, member_id) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function public.verify_bill_payment(
  target_bill_id uuid,
  approved boolean,
  rejection_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  target_bill public.bills%rowtype;
begin
  select * into target_bill
  from public.bills where id = target_bill_id for update;
  if target_bill.id is null then
    raise exception 'Tagihan tidak ditemukan.';
  end if;
  if not public.has_community_role(
    auth.uid(),
    target_bill.community_id,
    array['owner', 'admin', 'treasurer']
  ) then
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

drop function if exists public.get_community_cash_summary();
create or replace function public.get_community_cash_summary(
  target_community_id uuid
)
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
set row_security = off
as $$
  with income as (
    select
      coalesce(sum(amount) filter (where status = 'paid'), 0) total_paid,
      coalesce(sum(amount) filter (where status <> 'paid'), 0) total_unpaid
    from public.bills
    where community_id = target_community_id
  ),
  outcome as (
    select coalesce(sum(amount), 0) total_expenses
    from public.expenses
    where community_id = target_community_id
  )
  select
    income.total_paid,
    income.total_unpaid,
    outcome.total_expenses,
    income.total_paid - outcome.total_expenses
  from income cross join outcome
  where public.is_community_member(auth.uid(), target_community_id)
     or public.is_platform_super_admin(auth.uid());
$$;

revoke all on function public.is_platform_super_admin(uuid) from public;
revoke all on function public.is_community_member(uuid, uuid) from public;
revoke all on function public.has_community_role(uuid, uuid, text[]) from public;
revoke all on function public.get_user_active_communities(uuid) from public;
revoke all on function public.can_add_member(uuid) from public;
revoke all on function public.can_add_admin(uuid) from public;
revoke all on function public.can_create_community(uuid) from public;
revoke all on function public.create_community_with_owner(
  text, text, text, text, text, text, text
) from public;
revoke all on function public.get_community_by_code(text) from public;
revoke all on function public.join_community_by_code(text, text) from public;
revoke all on function public.get_invitation_by_token(text) from public;
revoke all on function public.accept_community_invitation(text) from public;
revoke all on function public.review_community_join_request(
  uuid, boolean, text
) from public;
revoke all on function public.get_community_cash_summary(uuid) from public;

grant execute on function public.is_platform_super_admin(uuid)
  to authenticated;
grant execute on function public.is_community_member(uuid, uuid)
  to authenticated;
grant execute on function public.has_community_role(uuid, uuid, text[])
  to authenticated;
grant execute on function public.get_user_active_communities(uuid)
  to authenticated;
grant execute on function public.can_add_member(uuid) to authenticated;
grant execute on function public.can_add_admin(uuid) to authenticated;
grant execute on function public.can_create_community(uuid) to authenticated;
grant execute on function public.create_community_with_owner(
  text, text, text, text, text, text, text
) to authenticated;
grant execute on function public.get_community_by_code(text)
  to anon, authenticated;
grant execute on function public.join_community_by_code(text, text)
  to authenticated;
grant execute on function public.get_invitation_by_token(text)
  to anon, authenticated;
grant execute on function public.accept_community_invitation(text)
  to authenticated;
grant execute on function public.review_community_join_request(
  uuid, boolean, text
) to authenticated;
grant execute on function public.get_community_cash_summary(uuid)
  to authenticated;

alter table public.platform_admins enable row level security;
alter table public.community_memberships enable row level security;
alter table public.community_member_details enable row level security;
alter table public.community_invitations enable row level security;
alter table public.community_join_requests enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.community_subscriptions enable row level security;

drop policy if exists communities_select on public.communities;
drop policy if exists communities_insert on public.communities;
drop policy if exists communities_update on public.communities;
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists payment_accounts_select on public.payment_accounts;
drop policy if exists payment_accounts_insert on public.payment_accounts;
drop policy if exists payment_accounts_update on public.payment_accounts;
drop policy if exists payment_accounts_delete on public.payment_accounts;
drop policy if exists community_members_select on public.community_member_details;
drop policy if exists community_members_insert on public.community_member_details;
drop policy if exists community_members_update on public.community_member_details;
drop policy if exists community_members_delete on public.community_member_details;
drop policy if exists dues_select on public.dues;
drop policy if exists dues_insert on public.dues;
drop policy if exists dues_update on public.dues;
drop policy if exists dues_delete on public.dues;
drop policy if exists bills_select on public.bills;
drop policy if exists bills_insert on public.bills;
drop policy if exists bills_update_admin on public.bills;
drop policy if exists bills_update_member_payment on public.bills;
drop policy if exists expenses_select on public.expenses;
drop policy if exists expenses_insert on public.expenses;
drop policy if exists expenses_update on public.expenses;
drop policy if exists expenses_delete on public.expenses;
drop policy if exists announcements_select on public.announcements;
drop policy if exists announcements_insert on public.announcements;
drop policy if exists announcements_update on public.announcements;
drop policy if exists announcements_delete on public.announcements;

create policy communities_select on public.communities
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.is_community_member(auth.uid(), id)
);
create policy communities_update on public.communities
for update to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(auth.uid(), id, array['owner', 'admin'])
)
with check (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(auth.uid(), id, array['owner', 'admin'])
);

create policy profiles_select on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or public.is_platform_super_admin(auth.uid())
  or exists (
    select 1
    from public.community_memberships viewer
    join public.community_memberships target
      on target.community_id = viewer.community_id
    where viewer.user_id = auth.uid()
      and viewer.status = 'active'
      and viewer.role in ('owner', 'admin')
      and target.user_id = profiles.id
      and target.status = 'active'
  )
);
create policy profiles_update_self on public.profiles
for update to authenticated
using (id = auth.uid() or public.is_platform_super_admin(auth.uid()))
with check (id = auth.uid() or public.is_platform_super_admin(auth.uid()));

create policy memberships_select on public.community_memberships
for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
);
create policy memberships_manage on public.community_memberships
for all to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
)
with check (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
);

create policy member_details_select on public.community_member_details
for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
);
create policy member_details_manage on public.community_member_details
for all to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
)
with check (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
);

create policy payment_accounts_select on public.payment_accounts
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or (
    is_active
    and public.is_community_member(auth.uid(), community_id)
  )
);
create policy payment_accounts_manage on public.payment_accounts
for all to authenticated
using (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or public.is_platform_super_admin(auth.uid())
)
with check (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or public.is_platform_super_admin(auth.uid())
);

create policy dues_select on public.dues
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or exists (
    select 1
    from public.bills bill
    join public.community_member_details detail on detail.id = bill.member_id
    where bill.dues_id = dues.id and detail.user_id = auth.uid()
  )
);
create policy dues_manage on public.dues
for all to authenticated
using (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or public.is_platform_super_admin(auth.uid())
)
with check (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or public.is_platform_super_admin(auth.uid())
);

create policy bills_select on public.bills
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or exists (
    select 1
    from public.community_member_details detail
    where detail.id = bills.member_id and detail.user_id = auth.uid()
  )
);
create policy bills_insert on public.bills
for insert to authenticated
with check (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
);
create policy bills_update on public.bills
for update to authenticated
using (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
  or exists (
    select 1
    from public.community_member_details detail
    where detail.id = bills.member_id and detail.user_id = auth.uid()
  )
);

create policy expenses_select on public.expenses
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
);
create policy expenses_manage on public.expenses
for all to authenticated
using (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
)
with check (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
);

create policy announcements_select on public.announcements
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.is_community_member(auth.uid(), community_id)
);
create policy announcements_manage on public.announcements
for all to authenticated
using (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
)
with check (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin', 'treasurer']
  )
);

create policy invitations_select on public.community_invitations
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
);
create policy invitations_manage on public.community_invitations
for all to authenticated
using (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
)
with check (
  public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
);

create policy join_requests_select on public.community_join_requests
for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_super_admin(auth.uid())
  or public.has_community_role(
    auth.uid(),
    community_id,
    array['owner', 'admin']
  )
);

create policy plans_read on public.subscription_plans
for select to authenticated
using (is_active or public.is_platform_super_admin(auth.uid()));
create policy subscriptions_read on public.community_subscriptions
for select to authenticated
using (
  public.is_platform_super_admin(auth.uid())
  or public.is_community_member(auth.uid(), community_id)
);

drop policy if exists payment_proofs_insert on storage.objects;
drop policy if exists payment_proofs_select on storage.objects;
drop policy if exists expense_receipts_insert on storage.objects;
drop policy if exists expense_receipts_select on storage.objects;

create policy payment_proofs_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'payment_proofs'
  and public.is_community_member(
    auth.uid(),
    ((storage.foldername(name))[1])::uuid
  )
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or public.has_community_role(
      auth.uid(),
      ((storage.foldername(name))[1])::uuid,
      array['owner', 'admin', 'treasurer']
    )
  )
);
create policy payment_proofs_select on storage.objects
for select to authenticated
using (
  bucket_id = 'payment_proofs'
  and (
    public.is_platform_super_admin(auth.uid())
    or (
      public.is_community_member(
        auth.uid(),
        ((storage.foldername(name))[1])::uuid
      )
      and (
        (storage.foldername(name))[2] = auth.uid()::text
        or public.has_community_role(
          auth.uid(),
          ((storage.foldername(name))[1])::uuid,
          array['owner', 'admin', 'treasurer']
        )
      )
    )
  )
);
create policy expense_receipts_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'expense_receipts'
  and public.has_community_role(
    auth.uid(),
    ((storage.foldername(name))[1])::uuid,
    array['owner', 'admin', 'treasurer']
  )
);
create policy expense_receipts_select on storage.objects
for select to authenticated
using (
  bucket_id = 'expense_receipts'
  and (
    public.is_platform_super_admin(auth.uid())
    or public.has_community_role(
      auth.uid(),
      ((storage.foldername(name))[1])::uuid,
      array['owner', 'admin', 'treasurer']
    )
  )
);

commit;
