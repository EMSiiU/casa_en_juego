# Documento de Arquitectura y Requerimientos: App de Gestión de Limpieza ("Casa en Juego")

## 1. Resumen del Proyecto

Aplicación móvil multiplataforma (iOS y Android) diseñada para un grupo familiar (hermanos) con el objetivo de gamificar y registrar las tareas de limpieza del hogar. Los usuarios acumulan puntos mediante la realización de tareas predefinidas, las cuales deben ser validadas por otro miembro. La competencia funciona por ciclos con nombre y cuenta con un administrador.

## 2. Stack Tecnológico

* **Frontend:** Flutter (Dart). Framework de código abierto.
* **Backend / Base de Datos:** Supabase (PostgreSQL). Plataforma Backend-as-a-Service Open Source.
* **Autenticación:** Supabase Auth (Email / Contraseña).
* **Notificaciones Push:** Supabase Edge Functions + Firebase Cloud Messaging (FCM) o OneSignal.
* **Gráficos:** Paquete `fl_chart` para visualización de progreso en barra horizontal.

## 3. Modelo de Datos (Esquema Relacional - Supabase)

### Tabla `users`
* `id` (UUID, Primary Key)
* `name` (String) -> ej. "Ana", "Carlos"
* `email` (String)
* `role` (String) -> 'admin' | 'sibling'
* `notifications_enabled` (Boolean, Default: true) -> Controla el switch "Avisos de revisión".

### Tabla `tasks`
* `id` (UUID, Primary Key)
* `name` (String) -> ej. "Barrer el cuarto"
* `points` (Integer) -> ej. 3
* `icon_name` (String) -> Referencia al ícono (ej. escoba, platos, baño, basura, gotas, ventana).
* `is_active` (Boolean) -> Para ocultar tareas del catálogo sin borrar el historial.

### Tabla `seasons` (Ciclos de competencia)
* `id` (UUID, Primary Key)
* `name` (String) -> ej. "Octubre 2026"
* `start_date` (Timestamptz)
* `end_date` (Timestamptz, Nullable)
* `status` (String) -> 'active' | 'closed'

### Tabla `task_logs` (Historial y Solicitudes)
* `id` (UUID, Primary Key)
* `user_id` (UUID, Foreign Key -> users)
* `task_id` (UUID, Foreign Key -> tasks)
* `season_id` (UUID, Foreign Key -> seasons)
* `status` (String) -> 'pending' | 'approved' | 'rejected'
* `requested_at` (Timestamptz, Default: `now()`)
* `approved_by` (UUID, Nullable, Foreign Key -> users)
* `resolved_at` (Timestamptz, Nullable) -> Fecha en que se aprobó/rechazó.

## 4. Requerimientos Funcionales

1. **Autenticación Cerrada:** El administrador crea las cuentas en el dashboard de Supabase. Los usuarios inician sesión con correo y contraseña.
2. **Registro de Tareas:** Un usuario selecciona una tarea. El sistema crea un `task_log` `pending` (hora del servidor). Los puntos no se suman hasta ser aprobados.
3. **Sistema de Revisiones Separado:**
   * **Mis solicitudes ("Mi actividad"):** El usuario puede ver el estado de sus propias tareas (Pendientes, Aprobadas, Rechazadas).
   * **Solicitudes de otros ("Revisiones"):** Los usuarios ven y deciden (Aprobar/Rechazar) sobre las tareas de los demás.
4. **Tabla de Puntuación (Ranking):** Se calculan los puntos (solo tareas `approved`) dentro de la `season` activa. Se muestra un podio (1er, 2do, 3er lugar) y una gráfica de barras horizontales del aporte total al equipo.
5. **Control de Administrador (Flujos de Ciclo):** El administrador puede finalizar el ciclo activo (conservando el historial) y, posteriormente, iniciar un "Nuevo comienzo" nombrando la siguiente temporada. También puede editar nombre, puntos, ícono y estado (Activa/Inactiva) de las tareas.

## 5. Interfaz de Usuario (UI / UX) - "Casa en Juego"

Diseño basado en **Dark Mode moderno con "Glassmorphism" suave**, de contrastes bajos y formas redondeadas.

### 5.1. Paleta de Colores (ThemeData en Flutter)
* **Fondo Principal (Background):** `#1A1B22` (Gris oscuro casi negro).
* **Fondo de Tarjetas (Surface):** `#242531` (Gris oscuro azulado).
* **Color de Acento (Primary):** `#CBBDF8` (Lavanda claro).
* **Texto Principal:** `#FFFFFF` (Blanco puro).
* **Texto Secundario:** `#8C8E9E` (Gris medio).
* **Estados (Validación):**
  * Pendiente: `#F2C94C` (Amarillo ocre oscuro).
  * Aprobada: `#2E7D32` o un verde esmeralda desaturado.
  * Rechazada: `#D32F2F` o un rojo coral oscuro.

### 5.2. Estructura de Navegación (`BottomNavigationBar`)
1. **Tareas:** Ícono de casa (`home`).
2. **Ranking:** Ícono de trofeo (`emoji_events`).
3. **Revisiones:** Ícono de círculo con check (`check_circle_outline`) con *Badge* numérico de pendientes.
4. **Perfil:** Ícono de usuario (`person_outline`).

### 5.3. Diseño de Pantallas Clave

* **Acceso:** Logo "Casa en Juego", campos de email/password, botón "Iniciar sesión" color lavanda.
* **Tareas (Inicio):** Saludo, tarjeta resumen (puntos y lugar actual), banner de "tareas en revisión" y lista de tareas disponibles en formato horizontal (icono, nombre, puntos, botón '+'). Confirmación vía *BottomSheet*.
* **Mi Actividad:** Accesible desde Perfil o Inicio. Lista segmentada por *chips* (Todas, Pendientes, Aprobadas, Rechazadas).
* **Revisiones:** Bandeja de entrada. Tarjetas grandes con botones de "Rechazar" y "Aprobar" explícitos.
* **Ranking:** Tarjeta con podio circular para los 3 primeros, lista inferior para el resto. Gráfica de barras horizontales ("Puntos por persona") y tarjeta de "Tu aporte al equipo".
* **Perfil:** Información del usuario, accesos a "Mi actividad" y *switch* de "Avisos de revisión".
* **Administración (Si rol == admin):** Reemplaza o extiende la vista de perfil. Muestra estadísticas de la temporada actual, acceso a "Gestionar tareas" (Catálogo y edición de campos) y botón de peligro "Finalizar ciclo" (vía *BottomSheet*), seguido de pantalla de "Un nuevo comienzo".

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
│   ├── auth/
│   ├── tasks/                  # Pantalla 'Tareas' y widget BottomSheet de confirmación
│   ├── activity/               # Pantalla 'Mi actividad' (historial propio)
│   ├── leaderboard/            # Pantalla 'Ranking', podio y gráficas horizontales
│   ├── reviews/                # Pantalla 'Revisiones' (bandeja de entrada)
│   ├── profile/                # Pantalla 'Perfil' y toggle de notificaciones
│   └── admin/                  # Pantallas 'Cuidar del equipo', 'Gestionar tareas', 'Editar tarea', 'Cierre/Inicio de ciclo'
└── main.dart
```