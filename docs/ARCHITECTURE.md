# Arquitectura

Cómo funciona Web Watch Companion por dentro. Léelo antes de tocar `server.js`,
`public/index.html` o el protocolo WebSocket. Para la bandeja del sistema ver
[TRAY.md](TRAY.md); para el instalador, [DISTRIBUTION.md](DISTRIBUTION.md).

## Visión general

Un server Node.js en Windows lee las notificaciones de WhatsApp Desktop del Windows
Notification Center y las reenvía por WebSocket a cualquier navegador que tenga abierta la
página del server. El caso de uso: un iPhone 6s viejo en horizontal, cargando junto a la PC,
que muestra un ícono de WhatsApp gris que se ilumina en verde cuando llega un mensaje, para
enterarse sin mirar el celular ni depender de sonidos mientras se juega.

```
wpndatabase.db (Windows) ──polling 1s──▶ server.js ──WebSocket──▶ navegador (iPhone Safari)
                                            ▲
        tray/tray.ps1 (ícono de bandeja) ───┘  arranca el server y lo apaga con POST /shutdown
```

## Componentes

| Archivo | Rol |
|---|---|
| `server.js` | Express + WebSocket + polling de la DB de notificaciones + apagado prolijo |
| `public/index.html` | Cliente: UI, reconexión, NoSleep |
| `public/NoSleep.min.js` | Generado por `postinstall` desde `node_modules` (no se commitea) |
| `config.json` | Puerto (`47613`); lo leen `server.js` y `tray/tray.ps1` |
| `tray/` | Bandeja del sistema: ver [TRAY.md](TRAY.md) |
| `installer/`, `tools/build-installer.ps1` | Instalador: ver [DISTRIBUTION.md](DISTRIBUTION.md) |

Stack: Express, `ws`, `better-sqlite3` (lectura de la DB), NoSleep.js (en el cliente).

**Puerto 47613**, definido una sola vez en `config.json`. El cliente usa `location.host`, así
que no lleva el puerto escrito. Se eligió arbitrario a propósito para no chocar con dev
servers de otros proyectos (3000, 3001, 5173, 8080…) y queda fuera del rango efímero de
Windows (49152+), así que el SO no debería ocuparlo.

## Endpoints HTTP

| Ruta | Uso |
|---|---|
| `GET /` | Sirve el cliente (`public/`) |
| `GET /status` | Diagnóstico: `dbPath`, `dbExists`, `dbAccessError`, `lastSeenId`, `connectedClients` |
| `GET /test` | Dispara una notificación falsa (`count: 1`) a todos los clientes |
| `POST /shutdown` | Apaga el server de forma prolija. Solo loopback y con el header `X-Watch-Companion: 1`; si no, 403. `GET` → 404 |

## Mensajes WebSocket (server → cliente)

| `type` | Payload | Efecto en el cliente |
|---|---|---|
| `whatsapp_notification` | `{ count, timestamp }` | Ícono parpadea y queda verde; muestra "N mensajes sin leer" |
| `whatsapp_cleared` | — | Llama a `clearUnread()`: ícono vuelve a gris |
| `server_shutdown` | — | `noSleep.disable()` y header "SERVER OFF" |

## Detección de notificaciones

- **DB**: `%LOCALAPPDATA%\Microsoft\Windows\Notifications\wpndatabase.db`. Ojo: es
  `AppData\Local`, no `Roaming`; es un error fácil de cometer. Se abre en solo lectura; si el
  archivo está bloqueado, se copia a un temporal y se abre la copia.
- **Filtro**: handlers con `PrimaryId LIKE '%WhatsApp%'` o `'%5319275A%'` (el bundle ID puede
  variar entre instalaciones; ver [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).
- **Polling** cada 1 s (`pollNotifications()`), leyendo filas con `Id > lastSeenId`.
- **Timestamp**: Windows FILETIME (100 ns desde 1601-01-01), convertido a Unix ms.

### Por qué solo mostramos un contador, no el mensaje

WhatsApp Desktop **no usa la API nativa de Toast de Windows**: dibuja su propio popup. Lo
único que le manda al sistema operativo es un update de badge (`<badge value="N"/>`) para el
contador del ícono en la barra de tareas. Se confirmó revisando:

- `wpndatabase.db`: la columna `Type` de `Notification` es siempre `badge`/`tile`, nunca
  `toast`.
- El `UserNotificationListener` de Windows (Action Center, vía WinRT).
- El registro: no existe la clave de permisos de notificación de WhatsApp en
  `HKCU:\...\Notifications\Settings`, que Windows crea la primera vez que una app usa Toast.

Conclusión: no hay forma de leer remitente ni texto por las APIs de notificación. El server
parsea `<badge value="N"/>` y manda `{ count, timestamp }`. Si algún día se quisiera el texto
real, las únicas vías son UI Automation sobre la ventana de WhatsApp o leer su caché local
(leveldb/IndexedDB): ambas mucho más frágiles y no están implementadas.

### Detección de mensajes leídos (auto-clear)

**Hallazgo clave**: WhatsApp Desktop *no* manda `<badge value="0"/>` cuando los mensajes se
leen; **borra la fila de `Notification`** que tenía el badge activo. Se confirmó inspeccionando
la DB en vivo: tras leer, una query por el handler de WhatsApp no devuelve ninguna fila.

Por eso `pollNotifications()` usa dos mecanismos:

1. **Rama principal** (`count === 0` en una fila nueva): por si alguna instalación sí manda
   un badge=0 explícito. No se observó en la práctica, pero es inofensiva.
2. **Rama real**: el server guarda `hasUnread` (`true` mientras el último estado emitido fue
   un badge > 0). En cada poll, si `hasUnread` es `true`, comprueba si queda *alguna* fila
   del handler de WhatsApp; si no queda ninguna, los mensajes se leyeron → `hasUnread = false`
   y `broadcastCleared()`.

El cliente reacciona con la misma función que el tap manual (`clearUnread()`), así que el
ícono se apaga solo, típicamente dentro del segundo del poll. Verificado en sesión real: con
un mensaje real, leerlo en el celular apagó el ícono del iPhone sin ningún tap.

## Comportamiento del cliente

- **Idle**: ícono de WhatsApp muy grisado, discreto.
- **Notificación**: parpadea gris↔verde 2 veces, queda verde y muestra "WhatsApp" con la
  cantidad de mensajes sin leer (nunca remitente ni texto).
- El mensaje se oculta a los 5 s, pero el ícono queda verde.
- **Tap en la pantalla**: marca como leído, ícono a gris.
- **Leídos en otro lado** (celular, WhatsApp Web, el propio Desktop): llega `whatsapp_cleared`
  y el ícono se apaga solo.
- **WebSocket caído**: "OFFLINE" en el header y reintento automático cada 2 s.
- **Vuelta de background / pantalla bloqueada**: un listener de `visibilitychange` fuerza la
  reconexión inmediata. Hace falta porque iOS Safari suspende el JS de la pestaña al bloquear
  la pantalla, y el timer de 2 s puede no llegar a ejecutarse nunca.
- **Server apagado a propósito**: "SERVER OFF" en el header y se libera el NoSleep. Al volver
  el server, el cliente reconecta y **reactiva el NoSleep solo**, sin un tap nuevo.

## Apagado del server y NoSleep

**Regla**: el NoSleep del cliente (`noSleep.enable()`, activado con el primer tap) se libera
**solo** ante un aviso explícito del server, nunca por una desconexión común. Una desconexión
sola es ambigua (el server apagándose, pero también un hiccup de Wi-Fi o el iPhone yéndose a
background un momento), y soltar el wake lock en el segundo caso apagaría la pantalla en plena
sesión de juego, justo lo que el proyecto existe para evitar.

Flujo:

1. `shutdown(motivo)` en `server.js` llama a `broadcastShutdown()` (`{ type:
   'server_shutdown' }`), espera ~200 ms para que el frame llegue, y recién entonces cierra el
   WebSocket server, la DB y el proceso (con un fallback a 1 s si `close()` se cuelga).
2. Se dispara desde **`POST /shutdown`** (lo usan la bandeja y el instalador) o desde señales
   del proceso: `SIGINT`, `SIGBREAK`, `SIGHUP` (`SIGTERM` se registra, pero Windows no lo
   entrega de forma confiable).
3. El cliente, al recibir `server_shutdown`, hace `noSleep.disable()` y muestra "SERVER OFF".
   Un `onclose` sin ese aviso deja el NoSleep activo y reintenta cada 2 s.
4. Al reconectar (`ws.onopen`), si el NoSleep ya se había habilitado en esta carga de página
   (`noSleepGranted`) pero está apagado, se vuelve a llamar `enable()` sin esperar un gesto.
   Funciona porque NoSleep.js reutiliza el mismo `<video>` que ya recibió el gesto la primera
   vez; Safari solo exige el gesto para el primer `play()` de ese elemento.

Verificado en sesión real, ciclo completo: con el iPhone conectado, shutdown prolijo → "SERVER
OFF" y NoSleep liberado → pantalla del 6s bloqueada un buen rato → server reiniciado con la
pantalla aún bloqueada → al desbloquear, `visibilitychange` reconecta sin refrescar la página y
el NoSleep se reactiva solo.

Por qué se agregó `POST /shutdown` y no se confía solo en señales: ver
[DECISIONS.md](DECISIONS.md) (decisión 4).

## Proyecto de referencia

Es un fork de `iphone6s-sys-monitor-companion` (mismo usuario de GitHub): misma estructura
Express + WebSocket + NoSleep.js. La diferencia es el backend: acá se usa `better-sqlite3`
sobre la DB de Windows en lugar de `systeminformation`.

## Estado actual y dirección

WhatsApp **no** está aislado como módulo: la detección vive en `server.js` y la UI en
`public/index.html`. La dirección acordada (todavía no se implementa) es un núcleo genérico
más módulos de fuentes de alertas independientes; ver el punto 1b del [ROADMAP](../ROADMAP.md).
