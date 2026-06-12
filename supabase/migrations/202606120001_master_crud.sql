begin;

create or replace function public.update_due_and_open_bills(
  target_due_id uuid,
  new_title text,
  new_description text,
  new_month integer,
  new_year integer,
  new_amount numeric,
  new_due_date date
)
returns integer
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  target_due public.dues%rowtype;
  updated_bill_count integer;
begin
  select *
  into target_due
  from public.dues
  where id = target_due_id
  for update;

  if target_due.id is null then
    raise exception 'Iuran tidak ditemukan.';
  end if;
  if not (
    public.is_platform_super_admin(auth.uid())
    or public.has_community_role(
      auth.uid(),
      target_due.community_id,
      array['owner', 'admin', 'treasurer']
    )
  ) then
    raise exception 'Tidak memiliki akses untuk mengubah iuran ini.';
  end if;
  if nullif(trim(new_title), '') is null then
    raise exception 'Judul iuran wajib diisi.';
  end if;
  if new_month not between 1 and 12
     or new_year not between 2020 and 2100
     or new_amount <= 0 then
    raise exception 'Data periode atau nominal iuran tidak valid.';
  end if;

  update public.dues
  set
    title = trim(new_title),
    description = nullif(trim(new_description), ''),
    month = new_month,
    year = new_year,
    amount = new_amount,
    due_date = new_due_date
  where id = target_due_id;

  update public.bills
  set amount = new_amount
  where dues_id = target_due_id
    and status in ('unpaid', 'rejected');

  get diagnostics updated_bill_count = row_count;
  return updated_bill_count;
end;
$$;

revoke all on function public.update_due_and_open_bills(
  uuid,
  text,
  text,
  integer,
  integer,
  numeric,
  date
) from public;
grant execute on function public.update_due_and_open_bills(
  uuid,
  text,
  text,
  integer,
  integer,
  numeric,
  date
) to authenticated;

commit;
