-- Ejecutar tras actualizar la app, desplegar la función y aplicar la migración de recordatorios.
-- Usa la entrega inmediata y los reintentos de enable_push_delivery.sql ya configurados.
begin;
do $$
declare existing_job bigint;
begin
  if to_regprocedure('private.enqueue_inactivity_reminders(timestamp with time zone)') is null then
    raise exception 'Ejecuta primero la migración de recordatorios';
  end if;
  if not exists (select 1 from cron.job where jobname = 'send_task_notifications' and active)
    or not exists (select 1 from pg_trigger where tgname = 'push_jobs_wake_worker'
      and tgrelid = 'public.push_jobs'::regclass and tgenabled <> 'D') then
    raise exception 'Activa primero la entrega automática de notificaciones';
  end if;
  for existing_job in select jobid from cron.job where jobname = 'inactivity_reminders' loop
    perform cron.unschedule(existing_job);
  end loop;
  -- No fija UTC-6: la función calcula siempre la hora de America/Mexico_City.
  perform cron.schedule('inactivity_reminders', '0 * * * *',
    'select private.enqueue_inactivity_reminders();');
end;
$$;
commit;

select jobname, schedule, active from cron.job
where jobname in ('inactivity_reminders', 'send_task_notifications');
