begin;

-- Freeze the original group's catalog when this migration is applied.
lock table private.cycle_groups, public.tasks in share row exclusive mode;
create table private.cycle_task_templates as
  select name, points, icon_name, is_active, is_daily_limited
  from public.tasks
  where cycle_group_id = '00000000-0000-0000-0000-000000000001';
revoke all on private.cycle_task_templates from public, anon, authenticated;

create function private.seed_cycle_group_tasks() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.tasks(cycle_group_id, name, points, icon_name, is_active, is_daily_limited)
  select new.id, name, points, icon_name, is_active, is_daily_limited
  from private.cycle_task_templates;
  return new;
end;
$$;
revoke all on function private.seed_cycle_group_tasks() from public, anon, authenticated;
create trigger cycle_groups_seed_tasks after insert on private.cycle_groups
  for each row execute function private.seed_cycle_group_tasks();

-- Fill existing empty groups once. Groups with edited or disabled tasks keep their catalog.
insert into public.tasks(cycle_group_id, name, points, icon_name, is_active, is_daily_limited)
select group_row.id, template.name, template.points, template.icon_name, template.is_active, template.is_daily_limited
from private.cycle_groups group_row cross join private.cycle_task_templates template
where not exists (select 1 from public.tasks task where task.cycle_group_id = group_row.id);

-- The existing group-scoped INSERT policy and season trigger validate this value.
grant insert (planned_end_date) on public.seasons to authenticated;

notify pgrst, 'reload schema';
commit;
