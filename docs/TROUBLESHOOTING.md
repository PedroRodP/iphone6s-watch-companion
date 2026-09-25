# Problemas frecuentes

Empezá por los logs y `/status`:

- Logs de la app instalada o de `npm run tray`: `%LOCALAPPDATA%\WebWatchCompanion\logs\`
  (`server.out.log` y `server.err.log`).
- <http://localhost:47613/status> → `dbExists`, `dbAccessError`, `lastSeenId`,
  `connectedClients`.

## El dispositivo no se conecta

1. ¿Está en la **misma red Wi-Fi** que la PC?
2. ¿Usás la IP correcta? Está en `server.out.log` (línea `Network → http://<IP>:47613`).
3. **Firewall de Windows**: la primera vez que corre el `node.exe` de la app pregunta; hay que
   permitir **redes privadas**. Si lo rechazaste, activalo en *Firewall de Windows Defender →
   Permitir una aplicación* (`runtime\node.exe` dentro de la carpeta de instalación).
4. Si la red de la PC está marcada como **Pública**, cambiala a **Privada** en
   *Configuración → Red e Internet*.

## `dbExists: false`

WhatsApp Desktop tiene que haberse abierto al menos una vez para que exista la DB. Abrirlo,
cerrarlo y reiniciar la app.

## `dbAccessError: false` pero no detecta notificaciones reales

El filtro por bundle ID de WhatsApp puede variar entre instalaciones. Para descubrir el
correcto, agregá temporalmente este snippet al final de `server.js` (después de `initDB()`),
corrélo una vez con `node server.js` y mirá la salida:

```javascript
// DEBUG: correr una vez y quitar
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

Buscá la entrada que contenga "WhatsApp" o "5319275A" y ajustá el `LIKE` en **las tres
queries** (una en `initDB()` y dos en `pollNotifications()`). Ver
[ARCHITECTURE.md](ARCHITECTURE.md) para cómo se detectan las notificaciones.

## La bandeja muestra "El servidor se detuvo"

El `node.exe` terminó con error. Mirá `server.err.log`. Causas habituales:

- **Puerto ocupado**: hay otra instancia (repo + app instalada, o un `node server.js` en una
  terminal) o un `node.exe` huérfano. Ejecutá `tray\stop.ps1` (o cerrá esos procesos) y
  volvé a abrir la app.
- **`dbAccessError`**: ver arriba.

## Al abrir la app a mano aparece "Ya está en ejecución"

Es lo esperado: ya hay una instancia. Buscá el ícono en la bandeja, que puede estar en el
menú de íconos ocultos (flecha `^`). Para reiniciarla: click derecho → Salir y abrirla de
nuevo.

## Después de matar el server a la fuerza, el iPhone no bloquea la pantalla

Es intencional. El cliente suelta la pantalla encendida solo si recibe `server_shutdown`; una
desconexión sin aviso puede ser un hiccup de Wi-Fi y no se toma como apagado. Cerrar la app
con **Salir** (o `POST /shutdown`) evita la situación. Si ya pasó, bloqueá el dispositivo a
mano o volvé a abrir la app y salí con "Salir".

## SmartScreen: "Windows protegió su PC"

El instalador no está firmado. *Más información → Ejecutar de todas formas*.

## `npm install` falla con `better-sqlite3` (solo en desarrollo)

Si el log de npm dice `No prebuilt binaries found (target=<versión Node>...)`, la versión de
`better-sqlite3` es más vieja que tu Node y no publicó binario para esa combinación: cae a
compilar desde código fuente, que suele fallar en Windows por falta de Python/Build Tools. Lo
más simple:

```bash
npm install better-sqlite3@latest
```

Recompilar desde el código fuente (`npm install --build-from-source`, requiere Python 3.x y
las C++ Build Tools de Visual Studio) es el último recurso.

En el build del instalador este problema no aparece: usa `--ignore-scripts` y el binario
precompilado que trae el paquete (ver [DISTRIBUTION.md](DISTRIBUTION.md)).
