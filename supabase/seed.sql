-- Seed development SaaS multi-tenant. Password seluruh akun: password123

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'superadmin@kaswarga.local',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Super Admin KasWarga","phone_number":"+628111111110"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-3333-3333-333333333333',
    'authenticated',
    'authenticated',
    'admin@kaswarga.local',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Budi Owner Melati","phone_number":"+628111111111"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-4444-444444444441',
    'authenticated',
    'authenticated',
    'member1@kaswarga.local',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Warga Demo 1","phone_number":"+628111111112"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-4444-444444444442',
    'authenticated',
    'authenticated',
    'member2@kaswarga.local',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Warga Demo 2","phone_number":"+628111111113"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-4444-444444444443',
    'authenticated',
    'authenticated',
    'member3@kaswarga.local',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Sari Owner Gardenia","phone_number":"+628111111114"}',
    now(),
    now()
  )
on conflict (id) do nothing;

insert into auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  id,
  id,
  email,
  jsonb_build_object(
    'sub', id::text,
    'email', email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  now(),
  now(),
  now()
from auth.users
where id in (
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444441',
  '44444444-4444-4444-4444-444444444442',
  '44444444-4444-4444-4444-444444444443'
)
on conflict (provider_id, provider) do nothing;

insert into public.platform_admins (user_id)
values ('22222222-2222-2222-2222-222222222222')
on conflict do nothing;

insert into public.communities (
  id,
  name,
  type,
  address,
  city,
  province,
  postal_code,
  community_code,
  is_code_join_enabled,
  require_admin_approval,
  is_active,
  created_by
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    'Cluster Melati RT 05',
    'cluster',
    'Jl. Melati Raya No. 5',
    'Bandung',
    'Jawa Barat',
    '40123',
    'MELATI-RT05',
    true,
    true,
    true,
    '33333333-3333-3333-3333-333333333333'
  ),
  (
    '11111111-1111-1111-1111-111111111112',
    'Perhimpunan Warga Gardenia',
    'perhimpunan_warga',
    'Jl. Gardenia Utama No. 8',
    'Bekasi',
    'Jawa Barat',
    '17145',
    'GARDENIA-2026',
    true,
    false,
    true,
    '44444444-4444-4444-4444-444444444443'
  )
on conflict (id) do update set
  name = excluded.name,
  type = excluded.type,
  community_code = excluded.community_code,
  created_by = excluded.created_by;

insert into public.community_memberships (
  id,
  community_id,
  user_id,
  role,
  status,
  joined_via,
  approved_by,
  approved_at
)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333333',
    'owner',
    'active',
    'created_community',
    '33333333-3333-3333-3333-333333333333',
    now()
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444441',
    'member',
    'active',
    'community_code',
    '33333333-3333-3333-3333-333333333333',
    now()
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444442',
    'treasurer',
    'active',
    'invitation_email',
    '33333333-3333-3333-3333-333333333333',
    now()
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
    '11111111-1111-1111-1111-111111111112',
    '44444444-4444-4444-4444-444444444443',
    'owner',
    'active',
    'created_community',
    '44444444-4444-4444-4444-444444444443',
    now()
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
    '11111111-1111-1111-1111-111111111112',
    '44444444-4444-4444-4444-444444444441',
    'admin',
    'active',
    'community_code',
    '44444444-4444-4444-4444-444444444443',
    now()
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa6',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444443',
    'member',
    'pending',
    'community_code',
    null,
    null
  )
on conflict (community_id, user_id) do nothing;

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
  status
)
values
  (
    '44444444-4444-4444-4444-444444444441',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444441',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'Warga Demo 1',
    '+628111111112',
    'A',
    '01',
    3,
    'active'
  ),
  (
    '44444444-4444-4444-4444-444444444442',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444442',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    'Warga Demo 2',
    '+628111111113',
    'A',
    '02',
    4,
    'active'
  ),
  (
    '44444444-4444-4444-4444-444444444443',
    '11111111-1111-1111-1111-111111111112',
    '44444444-4444-4444-4444-444444444443',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
    'Sari Owner Gardenia',
    '+628111111114',
    'G',
    '01',
    2,
    'active'
  ),
  (
    '44444444-4444-4444-4444-444444444445',
    '11111111-1111-1111-1111-111111111112',
    '44444444-4444-4444-4444-444444444441',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
    'Warga Demo 1',
    '+628111111112',
    'G',
    '02',
    3,
    'active'
  )
on conflict (id) do nothing;

insert into public.community_subscriptions (
  community_id,
  plan_id,
  status,
  trial_ends_at
)
select community_id, plan.id, 'active', null
from (
  values
    ('11111111-1111-1111-1111-111111111111'::uuid),
    ('11111111-1111-1111-1111-111111111112'::uuid)
) communities(community_id)
cross join public.subscription_plans plan
where plan.code = 'free'
on conflict (community_id) do update set
  plan_id = excluded.plan_id,
  status = excluded.status;

insert into public.payment_accounts (
  id,
  community_id,
  bank_name,
  account_number,
  account_holder_name,
  branch_name,
  payment_instruction,
  is_default,
  is_active,
  created_by
)
values
  (
    '55555555-5555-5555-5555-555555555551',
    '11111111-1111-1111-1111-111111111111',
    'BCA',
    '1234567890',
    'Bendahara RT 05',
    'Bandung',
    'Transfer sesuai nominal tagihan, lalu upload bukti pembayaran.',
    true,
    true,
    '33333333-3333-3333-3333-333333333333'
  ),
  (
    '55555555-5555-5555-5555-555555555552',
    '11111111-1111-1111-1111-111111111111',
    'Mandiri',
    '9876543210',
    'Kas Warga RT 05',
    null,
    'Cantumkan nama dan nomor rumah pada berita transfer.',
    false,
    true,
    '33333333-3333-3333-3333-333333333333'
  )
on conflict (id) do nothing;

insert into public.dues (
  id,
  community_id,
  title,
  description,
  month,
  year,
  amount,
  due_date
)
values (
  '66666666-6666-6666-6666-666666666666',
  '11111111-1111-1111-1111-111111111111',
  'Iuran Bulanan',
  'Kebersihan, keamanan, dan kegiatan warga.',
  extract(month from current_date)::integer,
  extract(year from current_date)::integer,
  150000,
  date_trunc('month', current_date)::date + 9
)
on conflict (id) do nothing;

insert into public.bills (
  id,
  dues_id,
  community_id,
  member_id,
  amount,
  status,
  selected_payment_account_id,
  payment_date,
  payment_method,
  payment_proof_url,
  verified_by,
  verified_at
)
values
  (
    '77777777-7777-7777-7777-777777777771',
    '66666666-6666-6666-6666-666666666666',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444441',
    150000,
    'unpaid',
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '77777777-7777-7777-7777-777777777772',
    '66666666-6666-6666-6666-666666666666',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444442',
    150000,
    'waiting_verification',
    '55555555-5555-5555-5555-555555555551',
    current_date,
    'bank_transfer',
    '11111111-1111-1111-1111-111111111111/44444444-4444-4444-4444-444444444442/demo.jpg',
    null,
    null
  )
on conflict (id) do nothing;

insert into public.announcements (
  id,
  community_id,
  title,
  content,
  is_pinned,
  created_by
)
values
  (
    '99999999-9999-9999-9999-999999999991',
    '11111111-1111-1111-1111-111111111111',
    'Kerja Bakti Minggu Pagi',
    'Mari berkumpul pukul 07.00 di balai warga.',
    true,
    '33333333-3333-3333-3333-333333333333'
  ),
  (
    '99999999-9999-9999-9999-999999999992',
    '11111111-1111-1111-1111-111111111112',
    'Rapat Gardenia',
    'Rapat bulanan dilaksanakan Jumat pukul 19.30.',
    true,
    '44444444-4444-4444-4444-444444444443'
  )
on conflict (id) do nothing;

insert into public.expenses (
  id,
  community_id,
  title,
  description,
  amount,
  expense_date,
  created_by
)
values (
  '88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  'Perbaikan lampu jalan',
  'Penggantian dua lampu area gerbang.',
  75000,
  current_date - 2,
  '33333333-3333-3333-3333-333333333333'
)
on conflict (id) do nothing;

insert into public.community_invitations (
  id,
  community_id,
  invited_email,
  invited_phone_number,
  invited_full_name,
  role,
  invitation_token,
  status,
  expires_at,
  invited_by
)
values (
  'dddddddd-dddd-dddd-dddd-ddddddddddd1',
  '11111111-1111-1111-1111-111111111112',
  'member2@kaswarga.local',
  '+628111111113',
  'Warga Demo 2',
  'member',
  'demo-undangan-gardenia-2026',
  'pending',
  now() + interval '7 days',
  '44444444-4444-4444-4444-444444444443'
)
on conflict (id) do nothing;

insert into public.community_join_requests (
  id,
  community_id,
  user_id,
  request_note,
  status
)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
  '11111111-1111-1111-1111-111111111111',
  '44444444-4444-4444-4444-444444444443',
  'Saya tinggal di Blok C dan ingin bergabung.',
  'pending'
)
on conflict (community_id, user_id) do nothing;
