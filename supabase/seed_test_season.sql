-- Opcional: ejecutar en SQL Editor para probar tareas antes de implementar admin.
-- Solo inicia una temporada si no existe otra activa; no modifica el historial.
insert into public.seasons (name)
select 'Octubre 2026'
where not exists (select 1 from public.seasons where status = 'active');

select id, name, status, start_date from public.seasons where status = 'active';
