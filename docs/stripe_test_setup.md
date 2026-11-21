# Suscripciones Familia y Comunidad de prueba con Stripe

Esta etapa conecta Familia ($39 MXN al mes) y Comunidad ($69 MXN al mes)
con el mismo PaymentSheet en Android.
Stripe crea la suscripción y cobra su primera factura de forma simulada.
La app informa el resultado y consulta en Stripe cuál es el plan actual. Los beneficios anunciados en las tarjetas
siguen formando parte de la propuesta académica.

## Preparación en Stripe y Supabase

1. Abre el entorno de pruebas de Stripe. En Catálogo de productos crea
   Familia con un precio recurrente de $39 MXN cada mes y Comunidad con
   un precio recurrente de $69 MXN cada mes. Ambos deben estar activos y en MXN.
2. En Supabase → Edge Functions → Secrets, guarda estos valores del mismo
   entorno. El identificador del precio debe empezar con `price_`.

| Nombre | Valor |
|---|---|
| `STRIPE_PUBLISHABLE_KEY` | Clave publicable `pk_test_…` |
| `STRIPE_SECRET_KEY` | Clave secreta `sk_test_…` |
| `STRIPE_PRICE_FAMILIA` | Identificador del precio mensual de Familia |
| `STRIPE_PRICE_COMUNIDAD` | Identificador del precio mensual de Comunidad |

Las variables `SUPABASE_URL` y `SUPABASE_ANON_KEY` son variables del
entorno de Edge Functions. La clave secreta se usa únicamente en el servidor.
La función obtiene el usuario desde Supabase Auth antes de llamar a Stripe.

## Desplegar la función

Desde Supabase Dashboard:

1. Abre **Edge Functions → Deploy a new function → Via Editor**.
2. Usa el nombre exacto **create-family-subscription**.
3. Copia el contenido de estos archivos del repositorio en el editor,
   conservando el nombre de cada archivo.
   - [index.ts](../supabase/functions/create-family-subscription/index.ts)
   - [handler.ts](../supabase/functions/create-family-subscription/handler.ts)
4. Despliega y deja desactivada la opción **Verify JWT** en la configuración
   de esta función. El handler comprueba el token con `/auth/v1/user` y
   exige un correo confirmado. El envío sin sesión recibe un error 401.

Si ya utilizas la CLI con sesión y proyecto configurados, el equivalente es:

```powershell
supabase functions deploy create-family-subscription
```

`supabase/config.toml` contiene la configuración de esta nueva función.
Las pruebas usan datos ficticios y se ejecutan localmente desde `handler_test.ts`.
La configuración de datos del ciclo y las funciones de avisos tienen sus
propios despliegues.

## Actualizar una función ya desplegada

Antes de ejecutar esta versión de la app:

1. Abre **Edge Functions → Secrets** y agrega `STRIPE_PRICE_COMUNIDAD`
   con el identificador `price_…` del precio mensual de Comunidad, del mismo
   entorno de pruebas que las claves existentes. No uses el `prod_…` del producto.
2. Abre **Edge Functions → create-family-subscription → Code**.
3. Reemplaza **index.ts y handler.ts** por sus versiones actuales del repositorio.
4. Pulsa **Deploy updates**. Conserva los tres secretos anteriores y la
   configuración de JWT. No es necesario crear otra función ni ejecutar SQL.

La app envía `action: checkout` y `plan: familia` o `plan: comunidad`.
El nombre histórico de la función se conserva para no cambiar su URL.
Una versión anterior del servidor solo conoce Familia: actualiza primero
ambos archivos del servidor y después ejecuta la app actualizada.

## Probar en el RMX3840 o el emulador Android

1. Ejecuta `flutter pub get` y recompila Android. Stripe necesita una
   `FlutterFragmentActivity` y temas AppCompat. Estos cambios requieren
   reiniciar la compilación nativa.
2. Inicia sesión con una cuenta confirmada y abre **Planes**.
3. Con una cuenta sin suscripción activa, pulsa **Probar pago** en Familia
   o Comunidad. El botón muestra **Preparando pago…**
   mientras abre el formulario nativo de Stripe.
4. Usa la tarjeta ficticia `4242 4242 4242 4242`, fecha futura como `12/34`
   y CVC `123`. Completa los demás campos que solicite el formulario.
5. Al confirmar debe aparecer el mensaje **Pago de prueba completado**
   y la modalidad elegida debe mostrar **Plan actual**, con el botón desactivado.
   La otra modalidad de pago debe indicar **Otro plan activo**.
   En Stripe, dentro del mismo entorno, abre el cliente y revisa su factura
   y suscripción. La suscripción se identifica con `metadata.plan = familia` o `comunidad`
   y `metadata.supabase_user_id`.
6. Para probar la cancelación de la hoja, usa otra cuenta de Casa en Juego
   sin suscripción activa, abre el formulario y ciérralo. Al pulsar de nuevo
   se reutiliza la primera factura pendiente.
7. Prueba un rechazo con la tarjeta ficticia `4000 0000 0000 0002`.
   Stripe muestra el problema de la tarjeta y permite corregir los datos.
   Si sales del formulario, puedes abrirlo otra vez.

Para repetir un pago exitoso con la misma cuenta, cancela su suscripción
en el panel de Stripe del entorno de pruebas con efecto inmediato. Sal de
Planes y vuelve a entrar: Casa debe aparecer como Plan actual y ambos pagos
quedan disponibles. Una cancelación al final del período mantiene el bloqueo
mientras la suscripción siga activa. Para comprobar el cambio, paga el otro
plan y verifica su importe (39 o 69 MXN), metadata y factura en Stripe.
La app detecta una suscripción activa de cualquiera de los dos planes y
evita crear otra, tanto en la pantalla como en la función del servidor. La creación y las renovaciones de esta integración
ocurren en el sandbox, con sus claves y tarjetas de prueba.

## Corrección tras eliminar un cliente de pruebas

Si eliminaste el cliente de Stripe y Planes muestra Casa, pero el nuevo pago
falla con «No pudimos preparar la suscripción de prueba», actualiza
**Edge Functions → create-family-subscription → Code → handler.ts** con la
versión actual del repositorio y pulsa **Deploy updates**. Para esta corrección
no cambian `index.ts`, los secretos, JWT, SQL ni la app Flutter.

La función comprueba si el cliente devuelto por una petición idempotente sigue
existiendo. Si estaba eliminado, obtiene uno nuevo y utiliza claves de
suscripción distintas para ese cliente. Así evita reutilizar referencias o
facturas guardadas del cliente anterior. Esta situación no se resuelve
reiniciando la app o cerrando sesión.

Después del despliegue, vuelve a Planes e intenta un pago ficticio. Comprueba
que Stripe tenga un cliente nuevo y que la factura corresponda al plan elegido.
Para repetir habitualmente la demostración basta cancelar la suscripción con
efecto inmediato y conservar al cliente; no necesitas eliminarlo.

## Alcance y diagnóstico

- Familia y Comunidad habilitan el formulario solo en Android. Chrome y Edge muestran
  el catálogo y un aviso que indica dónde probar el pago nativo.
- Cada precio se selecciona en el servidor y se valida contra su importe
  anunciado. El cliente no controla moneda, importe, cliente ni precio de Stripe.
- Casa representa el acceso gratuito a las funciones actuales. El resultado
  de un pago se muestra como aviso. Al abrir Planes se consulta Stripe para
  marcar la modalidad activa; Casa solo se marca si no hay un plan de pago activo.
- La función crea o reutiliza un cliente por el identificador de Supabase,
  usa claves de idempotencia para los POST y reutiliza una suscripción pendiente.
- Stripe actualiza sus facturas y estados. La app consulta el plan al abrir
  Planes y después de pagar (también si Stripe informa que ya estaba activo).
  Si cancelas inmediatamente desde Stripe, sal de Planes y vuelve a entrar.
  Una cancelación al final del período conserva el plan mientras siga activo.
  No hay webhook, cambios automáticos de modalidad ni cancelación desde la app.
- Una factura incompleta del mismo plan se reutiliza. Una pendiente del otro
  plan, o una suscripción con problemas de cobro, requiere revisión/cancelación
  desde el panel antes de contratar otro. Cerrar PaymentSheet no elimina la
  suscripción incompleta de Stripe.
- Si falla la consulta, se ofrece Reintentar y no se permite iniciar el pago
  hasta conocer el plan. Un fallo no se interpreta como acceso gratuito.
- Si la función responde que el precio es incorrecto, comprueba moneda MXN,
  importe 39.00 para Familia o 69.00 para Comunidad, recurrencia mensual
  y que el precio esté activo en pruebas.
- Si el formulario no abre, comprueba el nombre de la función, su despliegue,
  las dos claves, el secreto de precio del plan elegido, la sesión y la conexión. La app omite los detalles privados
  del error del proveedor.

## Verificación local

```powershell
dart analyze
flutter test
deno check supabase/functions/create-family-subscription/index.ts
deno test supabase/functions/create-family-subscription/handler_test.ts
flutter build apk --debug
flutter build web
```

Las pruebas de la función verifican identidad, entorno de pruebas, precio
elegido en el servidor, reutilización de suscripciones y respuestas sin
secretos. Las pruebas Flutter sustituyen el cobro por una implementación
controlada para comprobar ambos botones, sus planes enviados, los resultados
y el bloqueo de ambos pagos cuando existe una suscripción activa.
La entrega real del formulario se comprueba en el teléfono después del
despliegue.

[Suscripciones móviles en Stripe](https://docs.stripe.com/billing/subscriptions/build-subscriptions?payment-ui=mobile&platform=android)
· [Tarjetas de prueba](https://docs.stripe.com/testing)
· [SDK Flutter y requisitos de Android](https://pub.dev/packages/flutter_stripe).
