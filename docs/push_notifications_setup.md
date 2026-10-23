# Activación de notificaciones móviles

Supabase conserva Auth, usuarios, tareas, preferencias y la cola de avisos. Firebase Cloud Messaging (FCM) entrega los avisos a Android y a iOS. No se necesita Firestore, Firebase Authentication ni Cloud Functions de Firebase.

El código está preparado, pero los envíos reales requieren los pasos externos de esta guía. Sin configuración nativa de Firebase, la app sigue funcionando y Perfil informa que los avisos no están disponibles. Chrome puede seguir usándose para probar las demás features; esta integración push cubre Android e iOS.

## 1. Crear y conectar Firebase a Android

1. Crear un proyecto en [Firebase Console](https://console.firebase.google.com/). No es necesario activar Analytics para esta integración.
2. Agregar una aplicación Android con el identificador actual **`com.example.casa_en_juego`**. Si se cambia el identificador para publicar, también hay que registrar el nuevo en Firebase y descargar su configuración.
3. Descargar `google-services.json` y colocarlo en `android/app/google-services.json`. Este archivo es la configuración del cliente; **no** es la clave privada del servidor.
4. Revisar en Configuración del proyecto → Cloud Messaging que la API HTTP v1 esté habilitada. El código usa `register()` / `onRegistered` y el destino `fid` del SDK actual.
5. Reiniciar por completo la app con `flutter run`. Hot reload no agrega la configuración nativa. Usar un teléfono o emulador con Google Play Services.

El plugin de Google Services se aplica cuando existe ese archivo. El proyecto usa Android API 24 o superior. Al entrar con una cuenta con «Avisos de revisión» activado, la app solicitará el permiso del sistema. Si se deniega, Perfil muestra cómo volver a intentarlo.

## 2. Aplicar la migración de Supabase

Ejecutar en SQL Editor **solo** `supabase/migrations/20261022_add_push_notifications.sql`, después de las migraciones existentes. No volver a ejecutar `phase_2.sql` sobre el proyecto existente.

La migración agrega dispositivos y trabajos por dispositivo, RLS y RPC de registro/desvinculación. Los clientes no pueden consultar identificadores ajenos ni crear avisos. El JWT identifica al propietario. Registrar un dispositivo con otra cuenta elimina sus trabajos de la cuenta anterior.

## 3. Configurar los secretos del servidor

1. En Firebase → Configuración del proyecto → Cuentas de servicio, generar una clave privada para la cuenta que enviará mensajes. Guardar el JSON **fuera del repositorio**.
2. En Supabase → Edge Functions → Secrets, crear:
   - `FCM_SERVICE_ACCOUNT_JSON`: el JSON completo de esa cuenta de servicio. Necesita permiso `cloudmessaging.messages.create` en el proyecto Firebase correspondiente.
   - `NOTIFICATION_WEBHOOK_SECRET`: un valor aleatorio largo, de al menos 32 caracteres. Usar el mismo valor en Vault en el paso 5.
3. `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` están disponibles en las Edge Functions de Supabase. No se agregan a Flutter.

La clave privada de Firebase, la clave de servicio de Supabase y el secreto del webhook no se deben pegar en el chat ni guardar en archivos versionados. El worker omite identificadores y credenciales en sus respuestas y diagnósticos.

## 4. Desplegar la Edge Function

Con Supabase CLI instalado y la sesión iniciada:

```powershell
supabase login
supabase link --project-ref omselvknclwasrypkxhp
supabase functions deploy send-task-notifications
```

`supabase/config.toml` desactiva la comprobación JWT de esta función porque utiliza autenticación propia mediante `x-notification-secret`. **No es un endpoint público sin autenticación:** rechaza las llamadas que no aportan el secreto correcto; la clave pública de Flutter no sirve para invocarlo.

También puede crearse desde el editor del dashboard copiando los tres archivos `index.ts`, `handler.ts` y `fcm_sender.ts`, conservando sus nombres y rutas relativas y la misma configuración de comprobación JWT. No es necesario desplegar `handler_test.ts`.

## 5. Activar entrega inmediata y reintentos

Crear en Supabase Vault estos dos secretos:

| Nombre | Valor |
| --- | --- |
| `push_function_url` | `https://omselvknclwasrypkxhp.supabase.co/functions/v1/send-task-notifications` |
| `push_webhook_secret` | El mismo valor de `NOTIFICATION_WEBHOOK_SECRET` |

Después ejecutar `supabase/enable_push_delivery.sql`. El script valida que existan, agrega un webhook SQL asíncrono sobre la cola y programa una invocación por minuto para recuperar fallos. No configurar además otro webhook sobre `task_logs`.

La inserción de tareas y su revisión nunca esperan la respuesta de FCM. Cada invocación reclama hasta diez trabajos con un arrendamiento de dos minutos. Reintenta fallos temporales hasta cinco veces y descarta trabajos con más de un día. El worker vuelve a comprobar la preferencia, el propietario del dispositivo y el estado de la solicitud antes de enviar. Las nuevas solicitudes ya resueltas o de ciclos cerrados no generan avisos tardíos de revisión.

Los envíos son de entrega al menos una vez: si FCM acepta un mensaje y el worker se interrumpe antes de confirmarlo en la base, puede repetirse. Android e iOS reciben un identificador de reemplazo estable y Flutter evita repetir la misma alerta en primer plano. Esto reduce duplicados; no garantiza entrega exactamente una vez.

## 6. Prueba con dos usuarios

1. Entrar con Ana y otro miembro en dos dispositivos o emuladores. Permitir notificaciones y activar la preferencia en ambos.
2. Enviar una tarea con Ana. El otro miembro recibe el aviso; Ana no recibe su propio aviso de revisión.
3. Aprobar o rechazar desde la otra cuenta. Ana recibe el resultado.
4. Probar con la app abierta, en segundo plano y cerrada normalmente. En primer plano la alerta dura tres segundos. Al tocar el aviso se abre Revisiones o Mi actividad, según corresponda.
5. Desactivar la preferencia y repetir: esa persona no debe recibir nuevos envíos. La preferencia de la cuenta afecta a todos sus dispositivos.
6. Cerrar sesión y entrar con otra cuenta en el mismo dispositivo. Los avisos anteriores no deben abrir datos de la nueva cuenta.
7. Denegar el permiso del teléfono: las tareas siguen funcionando y Perfil informa del permiso pendiente. Forzar la detención de la app desde los ajustes del sistema puede impedir la entrega hasta abrirla de nuevo.

Para diagnóstico, consultar Edge Function Logs y, como administrador, **solo los estados** de la cola:

```sql
select status, count(*) from public.push_jobs group by status;
select kind, status, attempts, last_error, created_at
from public.push_jobs order by created_at desc limit 20;
```

No imprimir ni compartir las columnas `push_devices.token` o los secretos de Vault.

## 7. iOS

La recepción Dart y el delegado nativo están preparados. La entrega iOS aún requiere acceso a macOS con Xcode y una cuenta Apple apropiada. No es necesario disponer de un Mac propio: la compilación y la firma pueden prepararse en un entorno macOS en la nube, como un runner de GitHub Actions. La entrega real debe comprobarse también en iOS; compilar Android no valida esa plataforma.

Esta etapa queda pendiente mientras se activa y prueba Android. Para iOS falta:

- Registrar la app iOS en Firebase con `com.example.casaEnJuego` o el identificador definitivo.
- Incorporar `GoogleService-Info.plist` al target Runner desde Xcode.
- Activar la capacidad Push Notifications y comprobar Background Modes → Remote notifications. Xcode debe generar el entitlement `aps-environment` conforme al perfil de firma.
- Configurar la clave APNs en Firebase → Cloud Messaging y la firma del target.
- Compilar y comprobar la entrega en iOS. Windows puede utilizarse para editar el código y coordinar la compilación remota, pero no ejecuta Xcode localmente.

## Validación automatizada

Los avisos opcionales de las 18:00 y 20:00 se activan con [la guía de recordatorios](inactivity_reminders_setup.md), después de tener funcionando esta integración básica.

Para editar las funciones en VS Code, instalar la extensión oficial **Deno**, de **Denoland** (`denoland.vscode-deno`), y tener Deno disponible en la terminal. `.vscode/settings.json` limita su analizador a `supabase/functions`. Si VS Code indica que no encuentra Deno, configurar **Deno: Path** con la ruta de su ejecutable y ejecutar **Developer: Reload Window**. Los avisos del analizador TypeScript estándar sobre `Deno`, importaciones `npm:` o extensiones `.ts` no sustituyen la comprobación con `deno check`.

```powershell
flutter analyze
flutter test
deno check supabase/functions/send-task-notifications/index.ts
deno test supabase/functions/send-task-notifications/handler_test.ts
```

Fuentes: [FCM para Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [recepción de mensajes](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [notificaciones desde Supabase](https://supabase.com/docs/guides/functions/examples/push-notifications?platform=fcm), [programación de Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions).
