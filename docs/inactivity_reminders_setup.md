# Recordatorios de actividad

La app enviará un aviso a las **18:00** y otro a las **20:00**, según `America/Mexico_City`, si el usuario no tiene solicitudes **pendientes o aprobadas registradas ese día**. Revisar tareas de otros no cuenta como actividad propia. Las solicitudes rechazadas no impiden el recordatorio.

Solo se generan avisos cuando existe una temporada activa, la preferencia de notificaciones está activada y hay un dispositivo registrado. La comprobación considera las tareas del día aunque se haya cambiado de temporada. Cada dispositivo recibe como máximo un trabajo por día y horario; tener varios dispositivos permite recibirlo en cada uno.

La elegibilidad se comprueba también antes de enviar. Si se registra una tarea entre las 18:00 y las 20:00, no se genera el segundo recordatorio. Si una tarea se registra mientras el primer aviso sigue en cola, ese aviso se descarta. Una notificación ya entregada al sistema operativo no puede retirarse mediante esta comprobación.

Los recordatorios vencen a los 30 minutos del horario programado. El mismo vencimiento se transmite a FCM/APNs para reducir avisos tardíos en teléfonos desconectados. El reloj del teléfono no decide ni el día ni el horario.

## Activación en el proyecto existente

Las notificaciones de tareas ya deben estar funcionando. Se reutilizan la función, los secretos de Edge Functions, Vault y la entrega automática existentes; no se necesitan nuevas credenciales.

1. Actualizar la app Flutter en los dispositivos Android para que reconozca `reminder` y abra Tareas. Se puede ejecutar `flutter run -d <device-id>` o instalar un APK nuevo conservando los datos de la app.
2. En Supabase → Edge Functions → `send-task-notifications`, reemplazar y volver a desplegar **los tres archivos** actuales:
   - `supabase/functions/send-task-notifications/index.ts`
   - `supabase/functions/send-task-notifications/handler.ts`
   - `supabase/functions/send-task-notifications/fcm_sender.ts`
3. Conservar desactivada la comprobación JWT de la función: se mantiene la autenticación mediante `x-notification-secret`.
4. Ejecutar en SQL Editor **solo** `supabase/migrations/20261022_add_inactivity_reminders.sql`. Conserva los trabajos anteriores y añade el contexto de recordatorios.
5. Ejecutar `supabase/enable_inactivity_reminders.sql`. Esta operación es repetible y mantiene un único trabajo programado llamado `inactivity_reminders`.

El trabajo nuevo se ejecuta al inicio de cada hora del servidor y la función convierte la hora a Ciudad de México, actuando únicamente a las 18:00 y a las 20:00. Así no depende de fijar un desplazamiento UTC. El trabajo `send_task_notifications` continúa ejecutándose cada minuto para procesar la cola y sus reintentos.

No volver a ejecutar las migraciones anteriores ni `enable_push_delivery.sql`: este último ya está activo. No activar el nuevo horario antes de actualizar la Edge Function.

## Comprobación

El script de activación debe devolver ambos trabajos con `active = true`:

| jobname | schedule |
| --- | --- |
| `inactivity_reminders` | `0 * * * *` |
| `send_task_notifications` | `* * * * *` |

A las 18:00 o 20:00, un usuario sin actividad del día debe recibir «Hoy todavía no tienes tareas pendientes o aprobadas. ¡Anímate a sumar en casa!». Al tocarlo se abre Tareas. En primer plano se muestra durante tres segundos, igual que las demás alertas.

Para revisar resultados sin mostrar identificadores de dispositivo ni secretos:

```sql
select reminder_day, reminder_hour, status, attempts, last_error, created_at
from public.push_jobs
where kind = 'reminder'
order by created_at desc
limit 20;
```

No hay un endpoint público para forzar recordatorios o simular la hora. Las pruebas de horarios se realizan en PostgreSQL aislado:

```powershell
npm install --prefix supabase/tests
npm test --prefix supabase/tests
deno test supabase/functions/send-task-notifications/handler_test.ts
flutter test test/notifications_test.dart
```

El test de base de datos usa PGlite con datos ficticios, sin conectarse a Supabase. Cubre ambas horas, medianoche UTC frente al día local, preferencias, estados, cambios de temporada, revalidación al enviar, duplicados, vencimiento, permisos y cierre de sesión. La activación de Cron y la entrega real se validan en el proyecto después del despliegue; las pruebas locales no las sustituyen.
