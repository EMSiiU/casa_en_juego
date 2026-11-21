# Casa en Juego

Aplicación Flutter para organizar tareas domésticas por ciclos. Cada persona
registra su trabajo y otro miembro lo revisa. Las tareas aprobadas suman
puntos en la clasificación del ciclo. Supabase gestiona datos, acceso y
fotos de perfil. Firebase entrega avisos móviles y aloja la versión web.

La pantalla **Planes** presenta Casa gratis, Familia a $39 MXN al mes y
Comunidad a $69 MXN al mes. Los planes de pago anuncian beneficios de
demostración. La integración con Stripe en pruebas es el siguiente paso.

## Ejecutar

```powershell
flutter pub get
flutter run
```

## Documentación

- [Planteamiento y alcance](planteamiento.md).
- [Manual de usuario](docs/manual%20de%20usuario.md).
- [Manual técnico, arquitectura y pruebas](docs/MANUAL.md).
- [Publicación web en Firebase Hosting](docs/firebase_hosting_setup.md).
- [Configuración de avisos móviles](docs/push_notifications_setup.md).
- [Activación de recordatorios](docs/inactivity_reminders_setup.md).
