# Casa en Juego

Aplicación Flutter para organizar tareas domésticas por ciclos. Cada persona
registra su trabajo y otro miembro lo revisa. Las tareas aprobadas suman
puntos en la clasificación del ciclo. Supabase gestiona datos, acceso y
fotos de perfil. Firebase entrega avisos móviles y aloja la versión web.
Las cuentas que entran sin ciclo reciben una introducción guiada de seis pasos,
que también puede abrirse desde Perfil → Ver tutorial.
En Android, agitar el celular en Tareas sugiere una tarea disponible mediante
el acelerómetro; el registro sigue siendo manual. Perfil incluye Lugares útiles
con un catálogo fijo de Celaya; el mapa Android requiere configurar su clave.

Desde **Perfil → Planes** puedes consultar Casa gratis, Familia a $39 MXN al mes y
Comunidad a $69 MXN al mes. Los planes de pago anuncian beneficios de
demostración. Familia y Comunidad permiten abrir el pago nativo de prueba en Android
después de desplegar la función de Supabase y configurar Stripe.

## Ejecutar

```powershell
flutter pub get
flutter run
```

## Deploy
Se implementó un deploy usando el servicio de Hosting de Firebase.
[Visitar Casa en Juego](https://casaenjuego.web.app)


## Documentación

- [Manual de usuario](docs/manual%20de%20usuario.md).
- [Manual técnico, arquitectura, configuración y publicación](docs/MANUAL.md).

Para habilitar el mapa Android, consulta la [integración del mapa](docs/MANUAL.md#servicios-mapa).
El manual técnico explica Stripe, notificaciones, recordatorios, Firebase
Hosting y la relación de estos servicios con el código.
