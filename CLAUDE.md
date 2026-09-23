# CLAUDE.md — iphone6s-watch-companion

## Qué es este proyecto

Node.js server que corre en **Windows**, detecta notificaciones de WhatsApp Desktop
leyendo la base de datos SQLite del Windows Notification Center, y las manda via WebSocket
a un iPhone 6s en landscape que actúa como pantalla de alerta secundaria mientras se juega.

**Caso de uso**: el usuario juega en la PC con el celular cargando al lado. El iPhone muestra
un ícono de WhatsApp grisado que se ilumina en verde cuando llega un mensaje, sin necesidad
de mirar el celular ni depender de sonidos.

## Setup inicial (hacer UNA vez)

```bash
npm install
```

El `postinstall` copia automáticamente `NoSleep.min.js` a `public/`. No hace falta hacerlo
a mano.

## Arrancar el servidor

```bash
node server.js
```

Imprime la IP local. Abrir `http://<IP>:3001` en Safari del iPhone (en landscape).

**Importante**: correrlo como proceso standalone, con una consola real (una terminal
abierta a la vista, no un proceso lanzado en background/detached sin consola). Es lo que
permite cerrarlo de forma prolija (Ctrl+C) en vez de tener que matarlo a la fuerza — ver
por qué en "Apagado del servidor" más abajo.

## Verificar que todo funciona

```bash
# 1. Ver si la DB de notificaciones existe y es accesible
curl http://localhost:3001/status

# Respuesta esperada:
# { "dbExists": true, "dbAccessError": false, "lastSeenId": <número>, ... }

# 2. Disparar una notificación de prueba al iPhone
curl http://localhost:3001/test
```

Si el iPhone muestra el ícono verde con "WhatsApp" y "1 mensaje sin leer" → todo OK.

## Si `dbExists: false`

WhatsApp Desktop tiene que haberse abierto al menos una vez para que la DB exista.
Abrir WhatsApp Desktop → cerrar → volver a iniciar el servidor.

## Si `dbAccessError: false` pero no detecta notificaciones reales

El filtro por bundle ID de WhatsApp puede variar entre instalaciones. Agregar
temporalmente este snippet al principio de `server.js` para debug, correr una vez,
ver la salida, y ajustar el `WHERE` en `pollNotifications()` y `initDB()`:

```javascript
// DEBUG: pegar esto después de initDB() al final del archivo, correr una vez
const debugDb = openDB();
const handlers = debugDb.prepare(
  `SELECT DISTINCT h.PrimaryId
   FROM NotificationHandler h
   JOIN Notification n ON n.HandlerId = h.RecordId
   LIMIT 50`
).all();
console.log('Handlers encontrados:', handlers);
debugDb.close();
```

Buscar en la salida el entry que contenga "WhatsApp" o "5319275A" y actualizar el
`LIKE` en ambas queries del `server.js`.

## Si `better-sqlite3` falla al instalar

Si el log de npm dice `No prebuilt binaries found (target=<versión Node>...)`, es que la
versión de `better-sqlite3` en `package.json` es más vieja que tu Node.js y no publicó
binario precompilado para esa combinación — cae a compilar desde código fuente, lo cual
suele fallar en Windows por falta de Python/Build Tools. La solución más simple:

```bash
npm install better-sqlite3@latest
```

Esto suele traer un prebuild que sí soporta tu versión de Node sin compilar nada.
Recompilar desde código fuente (`npm install --build-from-source`, requiere Python 3.x
+ C++ Build Tools de Visual Studio) es el último recurso si ni la última versión tiene
prebuild para tu plataforma.

## Arquitectura en una línea

```
Windows DB (wpndatabase.db) → polling cada 1s → WebSocket → iPhone Safari
```

- Puerto: **3001** (para no pisar el sys-monitor-companion que usa 3000)
- DB path: `%LOCALAPPDATA%\Microsoft\Windows\Notifications\wpndatabase.db` (OJO: es
  `AppData\Local`, no `Roaming` — es un error fácil de cometer)
- Bundle ID de WhatsApp: `%WhatsApp%` o `%5319275A%` (filtro por LIKE)
- Timestamp: Windows FILETIME (100ns desde 1601-01-01) → se convierte a Unix ms

### Por qué solo mostramos un contador, no el mensaje

WhatsApp Desktop **no usa la API nativa de Toast de Windows** para sus notificaciones —
dibuja su propio popup. Lo único que manda al sistema operativo es un update de badge
(`<badge value="N"/>`) para el contador del ícono en la barra de tareas. Confirmado
revisando `wpndatabase.db` (columna `Type` de la tabla `Notification` es siempre
`badge`/`tile`, nunca `toast`), el `UserNotificationListener` de Windows (Action Center,
vía WinRT) y el registro (no existe clave de permisos de notificación para WhatsApp en
`HKCU:\...\Notifications\Settings`, algo que Windows crea automáticamente la primera vez
que una app llama a la API de Toast).

Conclusión: no hay forma de leer el remitente/mensaje real vía las APIs de notificación
de Windows. El servidor parsea `<badge value="N"/>` y manda `{ count, timestamp }` — el
cliente muestra "N mensajes sin leer", no el contenido real. Si en el futuro se quiere el
texto real, las únicas vías son UI Automation sobre la ventana de WhatsApp o leer su
caché local (leveldb/IndexedDB) — ambas mucho más frágiles, no implementadas.

### Detección de mensajes leídos (auto-clear)

**Hallazgo clave**: WhatsApp Desktop *no* manda un `<badge value="0"/>` cuando los
mensajes se leen. En vez de eso, **borra directamente la fila de `Notification`** que
tenía el badge activo. Confirmado inspeccionando `wpndatabase.db` en vivo: después de
leer los mensajes, una query por el handler de WhatsApp (`PrimaryId LIKE '%WhatsApp%'`)
no devuelve ninguna fila — ni una con `value="0"`, ninguna. La entrada simplemente
desaparece de la tabla.

Por eso `pollNotifications()` en `server.js` usa dos mecanismos, no uno:

1. **Rama principal** (`count === 0` en una fila nueva): queda por si alguna instalación
   de WhatsApp sí llega a mandar un badge=0 explícito — no observado en la práctica, pero
   inofensivo tenerlo.
2. **Rama real** (la que dispara en la práctica): el server guarda `hasUnread` (booleano,
   `true` mientras el último estado emitido fue un badge > 0). En cada poll, si
   `hasUnread` es `true`, chequea si sigue existiendo *alguna* fila para el handler de
   WhatsApp. Si ya no hay ninguna → los mensajes se leyeron → `hasUnread = false` y se
   manda `broadcastCleared()` (`{ type: 'whatsapp_cleared' }`).

El cliente (`public/index.html`) reacciona a ese mensaje llamando a `clearUnread()` — la
misma función que usa el tap manual — así que el ícono vuelve a gris solo, típicamente
dentro del segundo (intervalo de poll).

Verificado en sesión real: mensaje de WhatsApp real → ícono se prende → se lee el mensaje
(en el celular) → sin ningún tap en el iPhone, el ícono se apaga solo en el siguiente
poll.

## Comportamiento del cliente (iPhone)

- **Idle**: ícono de WhatsApp muy grisado, no llama la atención
- **Notificación**: ícono parpadea gris↔verde 2 veces, queda verde + muestra "WhatsApp" y
  la cantidad de mensajes sin leer (no el remitente ni el texto — ver arriba)
- **Mensaje se oculta a los 5 segundos**, pero el ícono se queda verde
- **Tap en la pantalla**: marca como leído, ícono vuelve a gris
- **Mensajes leídos en otro lado** (celular, WhatsApp Web, o el propio WhatsApp
  Desktop): el servidor lo detecta y manda `{ type: 'whatsapp_cleared' }` por
  WebSocket — el ícono se apaga solo, en sync con el estado real de leído, sin
  necesitar el tap manual (ver "Detección de mensajes leídos" más abajo)
- **WebSocket desconectado**: indicador "OFFLINE" en el header, reconecta automáticamente cada 2s
- **Vuelta de background/pantalla bloqueada**: listener de `visibilitychange` fuerza una
  reconexión inmediata en vez de esperar el timer de 2s — necesario porque iOS Safari
  suspende el JS de la pestaña al bloquear pantalla, así que el loop de retry normal
  puede no llegar a ejecutarse nunca
- **Servidor apagado a propósito**: indicador "SERVER OFF" en el header (en vez de
  "OFFLINE") y se libera el NoSleep — ver sección siguiente. Al reconectar (el server
  vuelve a estar arriba), el NoSleep se reactiva solo, sin necesitar un tap nuevo

## Apagado del servidor y NoSleep en el iPhone

**Decisión**: el NoSleep del iPhone (`noSleep.enable()`, activado al primer tap/touch en
`public/index.html`) sólo se libera ante un aviso explícito del servidor, nunca ante una
desconexión de WebSocket común. Motivo: una desconexión sola es ambigua — puede ser el
servidor apagándose, pero también un hiccup de Wi-Fi o el propio iPhone yéndose a
background un momento — y cortar el wake lock en ese segundo caso apagaría la pantalla
en medio de una sesión de juego, justo lo que este proyecto existe para evitar.

Flujo implementado:

1. `server.js` escucha señales de cierre del proceso (`SIGINT`, `SIGBREAK`, `SIGHUP`;
   `SIGTERM` se registra también pero Windows no lo entrega de forma confiable) y, antes
   de cerrar el WebSocket server y salir, llama a `broadcastShutdown()` — manda
   `{ type: 'server_shutdown' }` a todos los clientes conectados y espera ~200ms para
   darle tiempo al frame de llegar antes de tirar abajo los sockets.
2. `public/index.html` distingue ese mensaje de un `ws.onclose` normal: sólo al recibir
   `server_shutdown` llama `noSleep.disable()` y cambia el header a "SERVER OFF". Un
   `onclose` sin ese aviso previo (Wi-Fi, backgrounding) deja el NoSleep activo y
   simplemente reintenta reconectar cada 2s como siempre.
3. Cuando el cliente logra reconectar (`ws.onopen`), si el NoSleep ya había sido
   habilitado alguna vez en esta carga de página (`noSleepGranted`) pero está apagado
   (por el punto 2), se vuelve a llamar `noSleep.enable()` sin esperar un tap nuevo. Esto
   funciona porque NoSleep.js reutiliza el mismo `<video>` que ya recibió el gesto del
   usuario la primera vez — Safari no exige un gesto nuevo para reanudar reproducción en
   el mismo elemento dentro de la misma carga de página, sólo para el primer `play()`.

Verificado en sesión real, ciclo completo: con el iPhone conectado, shutdown prolijo del
server (`taskkill /PID <pid>` sin `/F`) → header pasa a "SERVER OFF" y se libera el
NoSleep → se bloquea la pantalla del 6s y se deja bloqueada un rato largo → se reinicia
el server con la pantalla todavía bloqueada → al desbloquear, el `visibilitychange`
dispara la reconexión sin intervención manual (sin refrescar la página) y el NoSleep se
reactiva solo, dejando la pantalla sin bloquearse de nuevo.

**Por qué correr el server como proceso standalone con consola real** (ver nota en
"Arrancar el servidor"): en Windows, para que el proceso de Node reciba una señal de
cierre "prolija" (Ctrl+C, o `taskkill /PID <pid>` sin `/F`) necesita tener una consola
real asociada. Si el proceso se lanza detached/en background sin consola (por ejemplo,
como background task de un agente automatizado), Windows sólo permite matarlo a la fuerza
(`taskkill /F` o equivalente) — eso es un kill duro que **no** dispara el handler de
`shutdown()`, por lo tanto nunca se manda `server_shutdown` y el iPhone se queda con la
pantalla despierta hasta que el usuario la bloquea a mano o el WebSocket eventualmente
nota la desconexión (sin apagar el NoSleep, por diseño). Verificado en sesión real:
matar el proceso con `taskkill /F` (o un stop de background task) no logra el efecto;
correrlo con `Start-Process` en su propia ventana de consola y cerrarlo con
`taskkill /PID <pid>` (sin `/F`) sí dispara el flujo completo y el iPhone bloqueó la
pantalla solo a los pocos segundos.

## Proyecto de referencia

Este proyecto es un fork de `iphone6s-sys-monitor-companion` (mismo usuario de GitHub).
Misma estructura Express + WebSocket + NoSleep.js. La diferencia es el backend:
aquí se usa `better-sqlite3` sobre la DB de Windows en lugar de `systeminformation`.

## Próximos pasos

Ver [ROADMAP.md](ROADMAP.md) — no se carga acá para no meter contexto innecesario en
cada sesión que no lo necesita.
