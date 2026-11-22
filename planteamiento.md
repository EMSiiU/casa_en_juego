# Documento de Arquitectura y Requerimientos: App de Gestión de Limpieza ("Casa en Juego")

## 1. Resumen del Proyecto

El proyecto nació para organizar las tareas de limpieza en casa y hacer visible
la participación de los hermanos. La aplicación permite registrar las tareas
realizadas y pedir a otro miembro que las valide. El objetivo es repartir y
reconocer el esfuerzo mediante puntos y ciclos de competencia.

Cada cuenta puede crear un ciclo o unirse mediante un código, con una sola
membresía activa a la vez. Cada ciclo empieza con cinco tareas base y su
creador como administrador. Al cerrarlo se conservan sus resultados e
historial, y las cuentas pueden empezar otro ciclo independiente.

Android es el destino de la demostración móvil y Firebase Hosting publica
la versión web. La configuración de iOS requiere validación en esa plataforma.

## 2. Stack Tecnológico

* **Frontend:** Flutter (Dart). Framework de código abierto.
* **Backend / Base de Datos:** Supabase (PostgreSQL). Plataforma Backend-as-a-Service Open Source.
* **Autenticación:** Supabase Auth con correo y contraseña, Google y GitHub. Incluye verificación, reenvío y recuperación por código.
* **Notificaciones Push:** Supabase Edge Functions + Firebase Cloud Messaging (FCM). Activación externa y pruebas de entrega en `docs/push_notifications_setup.md`.
* **Gráficos:** Paquete `fl_chart` para visualización de progreso en barra horizontal.
* **Estado y navegación:** Riverpod y `go_router`.
* **Perfil:** Fotos privadas en Supabase Storage y caché de imágenes en el celular.
* **Mapa:** Google Maps nativo en Android con `google_maps_flutter` y ubicación puntual con `geolocator`. Catálogo fijo de reciclaje, lavanderías y tiendas de limpieza en Celaya, sin Places API ni almacenamiento de la posición.
* **Sensor:** Acelerómetro con `sensors_plus` en Android. Agitar el celular en Tareas sugiere una tarea activa disponible para esa cuenta; no registra solicitudes ni suma puntos.
* **Planes:** Catálogo local de modalidades y suscripciones Familia y Comunidad en pruebas con Stripe PaymentSheet en Android. Supabase Edge Functions prepara el pago.

## 3. Modelo de Datos (Esquema Relacional - Supabase)

Este resumen cubre los datos principales. El [manual técnico](docs/MANUAL.md)
mantiene el esquema vigente, las funciones, las políticas y el orden de las
migraciones, incluidos los ámbitos y archivos históricos de los ciclos.

### Tabla `users`
* `id` (UUID, Primary Key)
* `name` (String) -> ej. "Ana", "Carlos"
* `email` (String)
* `role` (String) -> 'admin' | 'sibling'
* `notifications_enabled` (Boolean, Default: true) -> Controla el switch "Avisos de revisión".
* `is_household_member` (Boolean) y `cycle_group_id` (UUID, Nullable) -> Membresía activa en el ciclo.

### Tabla `tasks`
* `id` (UUID, Primary Key)
* `name` (String) -> ej. "Barrer el cuarto"
* `points` (Integer) -> ej. 3
* `icon_name` (String) -> Referencia al ícono (ej. escoba, platos, baño, basura, gotas, ventana).
* `is_active` (Boolean) -> Para ocultar tareas del catálogo sin borrar el historial.
* `is_daily_limited` (Boolean, Default: false) -> El administrador elige entre repetible o una vez al día por usuario.

### Tabla `seasons` (Ciclos de competencia)
* `id` (UUID, Primary Key)
* `name` (String) -> ej. "Octubre 2026"
* `start_date` (Timestamptz)
* `end_date` (Timestamptz, Nullable)
* `status` (String) -> 'active' | 'closed'
* `cycle_group_id` (UUID) -> Ámbito de datos del ciclo.
* `planned_end_date` (Date) y `planned_duration_days` (Integer) -> Planificación elegida en el calendario.

### Tabla `task_logs` (Historial y Solicitudes)
* `id` (UUID, Primary Key)
* `user_id` (UUID, Foreign Key -> users)
* `task_id` (UUID, Foreign Key -> tasks)
* `season_id` (UUID, Foreign Key -> seasons)
* `status` (String) -> 'pending' | 'approved' | 'rejected'
* `requested_at` (Timestamptz, Default: `now()`)
* `requested_day` (Date) -> Día de registro según el servidor en `America/Mexico_City`.
* `daily_limit_applied` (Boolean) -> Conserva si el límite estaba activo al registrar la solicitud.
* `approved_by` (UUID, Nullable, Foreign Key -> users)
* `resolved_at` (Timestamptz, Nullable) -> Fecha en que se aprobó/rechazó.

## 4. Requerimientos Funcionales

### Soporte de notificaciones

* `push_devices`: identificador de dispositivo registrado (FID de FCM), propietario, plataforma y fecha de actualización. Registro y desvinculación mediante RPC autenticadas; sin acceso directo de los clientes a la tabla.
* `push_jobs`: cola de avisos por dispositivo y evento de `task_logs`, con estado, intentos y arrendamiento de procesamiento. Solo el servidor puede consultar y procesar la cola.
* Al enviar una tarea, se avisa a los demás miembros con dispositivos registrados y preferencia activa. Al aprobar o rechazar, se avisa al solicitante. La preferencia se verifica al generar y al entregar.
* Las notificaciones abren Revisiones o Mi actividad. Los avisos de otra cuenta se descartan en Flutter; cerrar sesión revoca el registro del dispositivo. En primer plano las alertas duran tres segundos.
* **Recordatorios diarios:** a las 18:00 y 20:00 de `America/Mexico_City`, avisar al usuario sin solicitudes propias pendientes o aprobadas registradas ese día. Requieren preferencia activa, dispositivo registrado y temporada activa. Se vuelve a comprobar la actividad antes de enviar; una tarea entre ambos horarios evita el segundo aviso. Los rechazados no cuentan como actividad válida. El recordatorio abre Tareas, se deduplica por dispositivo, día y horario y vence a los 30 minutos. Activación en `docs/inactivity_reminders_setup.md`.
* La cola permite reintentos sin depender de que el usuario mantenga abierta la app. La entrega Android/iOS requiere configurar Firebase y desplegar la Edge Function; push web queda fuera de esta integración móvil.

1. **Registro personal:** Cada persona crea su cuenta por correo o entra con Google o GitHub. Una cuenta sin ciclo activo abre Perfil y puede consultar Planes. En cada nueva sesión sin ciclo se presenta una bienvenida guiada de seis pasos, con Siguiente, Atrás, Omitir y Cerrar al final. No vuelve a mostrarse al navegar en la misma sesión. Perfil → Ver tutorial permite abrirla manualmente con o sin ciclo.
2. **Registro de Tareas:** Un usuario selecciona una tarea. El sistema crea un `task_log` `pending` (hora del servidor). Los puntos no se suman hasta ser aprobados.
   * Las tareas limitadas solo permiten una solicitud pendiente o aprobada por persona, tarea y día. Se renuevan a las 00:00 de Ciudad de México. Cada ciclo nuevo recibe copias independientes del catálogo. Una solicitud rechazada permite reenviar ese mismo día. Supabase impone esta regla también ante envíos simultáneos.
   * Inicialmente se limitan barrer, lavar/limpiar baños, tender/hacer la cama y limpiar/ordenar mis cosas cuando existan en el catálogo. Las demás tareas son repetibles; administración puede cambiar la frecuencia.
   * El catálogo incorpora iconos de cama, estante, tenis, ropa, cosas de hermanos y cosas personales.
   * Tareas, Ranking y Revisiones comparten un menú de cuenta para cerrar sesión; Perfil conserva su acceso propio.
   * **Sugerencia al agitar (Android):** Dos impulsos del acelerómetro sugieren una tarea al azar del catálogo activo que no esté bloqueada ese día. La sugerencia se puede cerrar; el usuario realiza la tarea y luego la registra normalmente. El sensor se detiene en segundo plano y al dejar la pantalla. La falta de soporte no afecta al registro manual. El mapa se mantiene independiente del sensor de movimiento.
3. **Sistema de Revisiones Separado:**
   * **Mis solicitudes ("Mi actividad"):** El usuario puede ver el estado de sus propias tareas (Pendientes, Aprobadas, Rechazadas).
   * **Solicitudes de otros ("Revisiones"):** Los usuarios ven y deciden (Aprobar/Rechazar) sobre las tareas de los demás.
4. **Tabla de Puntuación (Ranking):** Se calculan los puntos (solo tareas `approved`) dentro de la `season` activa. Se muestra un podio (1er, 2do, 3er lugar) y una gráfica de barras horizontales del aporte total al equipo.
5. **Administración del ciclo:** El creador administra solo el ciclo que creó. Puede editar el catálogo y finalizarlo. Al crear otro ciclo se eligen nombre y fecha prevista y se obtiene un catálogo nuevo. Los antiguos miembros se unen con el nuevo código.
6. **Perfil:** Nombre editable, tema claro/oscuro y preferencias de avisos. Solo las cuentas creadas por correo pueden editar su foto. Las cuentas de Google y GitHub usan el avatar del proveedor cuando está disponible.
7. **Planes:** Casa gratis, Familia a $39 MXN al mes y Comunidad a $69 MXN al mes. Familia anuncia hasta tres ciclos simultáneos y Comunidad hasta diez ciclos y resúmenes. Esos beneficios son una propuesta para la demostración académica. En Android, Familia y Comunidad abren la captura nativa de tarjeta de Stripe para pagar la primera factura de la suscripción de prueba elegida. Una suscripción activa impide contratar otro plan; para cambiar se cancela la anterior en Stripe. La app consulta Stripe al abrir Planes y después del pago para identificar el plan actual. La cancelación se realiza desde el panel de pruebas de Stripe.

8. **Lugares útiles:** Acceso desde Perfil para todas las cuentas. El mapa Android muestra la posición actual si se autoriza, un catálogo local de Celaya y filtros de Reciclaje, Lavanderías y Tiendas de limpieza. Si falla la ubicación, conserva Celaya como referencia. Los marcadores y la lista muestran nombre/dirección; Ver Celaya y Mi ubicación controlan la cámara. No hay búsquedas automáticas de establecimientos. En web/iOS o sin clave configurada se conserva el catálogo con filtros.

## 5. Interfaz de Usuario (UI / UX) - "Casa en Juego"

Diseño minimalista con Material 3, tarjetas redondeadas, fuente DM Sans y
modo claro/oscuro elegido desde Perfil.

### 5.1. Tema compartido

`lib/core/theme/app_theme.dart` define las paletas y colores de estado.
`AppPageBar` unifica altura, alineación y tipografía de los encabezados.
El [manual técnico](docs/MANUAL.md) explica cómo cambiar esos estilos.

### 5.2. Estructura de Navegación (`NavigationBar`)
1. **Tareas:** Ícono de casa (`home`).
2. **Ranking:** Ícono de trofeo (`emoji_events`).
3. **Revisiones:** Ícono de círculo con check (`check_circle_outline`) con *Badge* numérico de pendientes.
4. **Perfil:** Ícono de usuario (`person_outline`).
5. **Planes:** Ícono de distintivo (`workspace_premium_outlined`).

Sin membresía activa se muestran Perfil y Planes.

### 5.3. Diseño de Pantallas Clave

* **Acceso:** Logo "Casa en Juego", campos de email/password, botón "Iniciar sesión" color lavanda.
* **Tareas (Inicio):** Saludo, tarjeta resumen (puntos y lugar actual), banner de "tareas en revisión" y lista de tareas disponibles en formato horizontal (icono, nombre, puntos, botón '+'). Confirmación vía *BottomSheet*.
* **Mi Actividad:** Accesible desde Perfil o Inicio. Lista segmentada por *chips* (Todas, Pendientes, Aprobadas, Rechazadas).
* **Revisiones:** Bandeja de entrada. Tarjetas grandes con botones de "Rechazar" y "Aprobar" explícitos.
* **Ranking:** Tarjeta con podio circular para los 3 primeros, lista inferior para el resto. Gráfica de barras horizontales ("Puntos por persona") y tarjeta de "Tu aporte al equipo".
* **Perfil:** Información del usuario, accesos a "Mi actividad" y *switch* de "Avisos de revisión".
* **Administración:** Pantalla accesible desde Perfil para crear un ciclo cuando la cuenta está libre o administrar el actual si se es su creador. El mismo formulario sirve para crear ciclos posteriores.
* **Planes:** Tres tarjetas con precio y beneficios anunciados y un aviso de demostración. Familia y Comunidad habilitan el pago de prueba en Android cuando no hay otra suscripción activa. El catálogo web explica dónde probar el formulario nativo.

## 6. Estructura de Carpetas (Feature-First Architecture)

```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── router/
│   ├── network/
│   └── utils/
├── features/
│   ├── onboarding/             # Bienvenida guiada por sesión y acceso manual desde Perfil
│   ├── auth/
│   ├── tasks/                  # Pantalla 'Tareas' y widget BottomSheet de confirmación
│   ├── activity/               # Pantalla 'Mi actividad' (historial propio)
│   ├── leaderboard/            # Pantalla 'Ranking', podio y gráficas horizontales
│   ├── reviews/                # Pantalla 'Revisiones' (bandeja de entrada)
│   ├── profile/                # Pantalla 'Perfil' y toggle de notificaciones
│   ├── notifications/          # Permisos, registro de dispositivos y recepción de avisos
│   ├── admin/                  # Administración, catálogo e historial de ciclos
│   └── plans/                  # Catálogo de Casa, Familia y Comunidad
└── main.dart
```
