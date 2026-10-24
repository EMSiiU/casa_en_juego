# Publicación web en Firebase Hosting

El proyecto Firebase es `casaenjuego`. Hosting sirve únicamente `build/web`.
Supabase continúa gestionando las cuentas, los datos y la autorización mediante
RLS. La web todavía no registra dispositivos para notificaciones push.

## Publicar y actualizar

Desde la raíz del repositorio, con Flutter y Firebase CLI instalados:

```powershell
firebase login
flutter build web --release
firebase deploy --only hosting --project casaenjuego
```

Compilar antes de cada publicación evita desplegar una versión anterior. No es
necesario ejecutar `firebase init`: la configuración está en `firebase.json` y
`.firebaserc`. El despliegue se limita a Hosting; no modifica otros servicios.

La URL del sitio predeterminado es `https://casaenjuego.web.app`. La CLI confirma
la URL efectiva al terminar. Se puede consultar y revertir una versión desde
Firebase Console → Hosting → Historial de versiones.

Las rutas se resuelven mediante `index.html`. Los archivos se revalidan con el
servidor para permitir actualizaciones sin conservar indefinidamente versiones
anteriores en la caché del navegador. No se garantiza funcionamiento sin conexión.

## Probar desde iPhone

1. Abrir la URL publicada en Safari e iniciar sesión con una cuenta existente.
2. Comprobar tareas, actividad, ranking, revisiones y cierre de sesión.
3. En Safari, abrir Compartir → Añadir a pantalla de inicio y confirmar.
4. Abrir Casa en Juego desde su icono y comprobar que la sesión se conserva al
   cerrar y volver a abrir. Safari y la aplicación añadida pueden usar sesiones
   distintas, por lo que podría ser necesario iniciar sesión de nuevo.
5. Publicar una actualización y volver a abrir para comprobar que carga.

Esta versión permite usar las funciones de la app desde el navegador. Las
notificaciones de aprobación, revisión y recordatorios siguen disponibles en
Android; su entrega web requiere una integración posterior.

El acceso actual utiliza correo y contraseña con Supabase. Si se añaden OAuth,
enlaces mágicos o recuperación por correo, habrá que configurar también las URL
de redirección del dominio publicado en Supabase Auth.

## Referencias

- [Firebase Hosting](https://firebase.google.com/docs/hosting/quickstart)
- [Configuración de Hosting](https://firebase.google.com/docs/hosting/full-config)
- [Publicación web de Flutter](https://docs.flutter.dev/deployment/web)
