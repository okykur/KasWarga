-- Jalankan setelah migration. Password seluruh akun demo: password123
-- Seed ini ditujukan untuk project Supabase lokal/development.

insert into public.communities (
  id,
  name,
  address,
  city,
  province,
  postal_code,
  is_active
)
values (
  '11111111-1111-1111-1111-111111111111',
  'Warga Harmoni RT 05',
  'Jl. Melati Raya No. 5',
  'Bandung',
  'Jawa Barat',
  '40123',
  true
)
on conflict (id) do nothing;
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
    '{"full_name":"Budi Bendahara","phone_number":"+628111111111"}',
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
    '{"full_name":"Warga Demo 3","phone_number":"+628111111114"}',
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

update public.profiles
set role = 'super_admin', community_id = null
where id = '22222222-2222-2222-2222-222222222222';

update public.profiles
set role = 'admin', community_id = '11111111-1111-1111-1111-111111111111'
where id = '33333333-3333-3333-3333-333333333333';

update public.profiles
set role = 'member', community_id = '11111111-1111-1111-1111-111111111111'
where id in (
  '44444444-4444-4444-4444-444444444441',
  '44444444-4444-4444-4444-444444444442',
  '44444444-4444-4444-4444-444444444443'
);

insert into public.community_members (
  id,
  community_id,
  user_id,
  full_name,
  phone_number,
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
    'Warga Demo 2',
    '+628111111113',
    'A',
    '02',
    4,
    'active'
  ),
  (
    '44444444-4444-4444-4444-444444444443',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444443',
    'Warga Demo 3',
    '+628111111114',
    'B',
    '01',
    2,
    'active'
  )
on conflict (id) do nothing;

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
  ),
  (
    '77777777-7777-7777-7777-777777777773',
    '66666666-6666-6666-6666-666666666666',
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444443',
    150000,
    'paid',
    '55555555-5555-5555-5555-555555555551',
    current_date - 1,
    'bank_transfer',
    '11111111-1111-1111-1111-111111111111/44444444-4444-4444-4444-444444444443/demo.jpg',
    '33333333-3333-3333-3333-333333333333',
    now()
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
values (
  '99999999-9999-9999-9999-999999999999',
  '11111111-1111-1111-1111-111111111111',
  'Kerja Bakti Minggu Pagi',
  'Mari berkumpul pukul 07.00 di balai warga. Peralatan kebersihan disiapkan panitia.',
  true,
  '33333333-3333-3333-3333-333333333333'
)
on conflict (id) do nothing;

insert into public.expenses (
  id,
  community_id,
  title,
  description,
  amount,
  expense_date,
  receipt_image_url,
  created_by
)
values (
  '88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  'Perbaikan lampu jalan',
  'Penggantian dua lampu area gerbang.',
  75000,
  current_date - 2,
  null,
  '33333333-3333-3333-3333-333333333333'
)
on conflict (id) do nothing;
