# Casa en Juego

Aplicación Flutter para organizar tareas domésticas por ciclos. Cada persona
registra su trabajo y otro miembro lo revisa. Las tareas aprobadas suman
puntos en la clasificación del ciclo. Supabase gestiona datos, acceso y
fotos de perfil. Firebase entrega avisos móviles y aloja la versión web.
En Android, agitar el celular en Tareas sugiere una tarea disponible mediante
el acelerómetro; el registro sigue siendo manual. Perfil incluye Lugares útiles
con un catálogo fijo de Celaya; el mapa Android requiere configurar su clave.

La pantalla **Planes** presenta Casa gratis, Familia a $39 MXN al mes y
Comunidad a $69 MXN al mes. Los planes de pago anuncian beneficios de
demostración. Familia y Comunidad permiten abrir el pago nativo de prueba en Android
después de desplegar la función de Supabase y configurar Stripe.

## Ejecutar

```powershell
flutter pub get
flutter run
```

## Documentación

- [Planteamiento y alcance](planteamiento.md).
- [Manual de usuario](docs/manual%20de%20usuario.md).
- [Manual técnico, arquitectura y pruebas](docs/MANUAL.md).
- [Mapa Android y catálogo de lugares útiles](docs/maps_setup.md).
- [Publicación web en Firebase Hosting](docs/firebase_hosting_setup.md).
- [Configuración de avisos móviles](docs/push_notifications_setup.md).
- [Activación de recordatorios](docs/inactivity_reminders_setup.md).
- [Configuración y prueba de suscripciones con Stripe](docs/stripe_test_setup.md).
