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

## Verificar que todo funciona

```bash
# 1. Ver si la DB de notificaciones existe y es accesible
curl http://localhost:3001/status

# Respuesta esperada:
# { "dbExists": true, "dbAccessError": false, "lastSeenId": <número>, ... }

# 2. Disparar una notificación de prueba al iPhone
curl http://localhost:3001/test
```

Si el iPhone muestra el ícono verde con "Test Contact" → todo OK.

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

Los binarios precompilados no matchearon la versión de Node.js. Opciones:

```bash
# Opción A: recompilar (requiere Python y C++ Build Tools de Visual Studio)
npm install --build-from-source

# Opción B: instalar C++ Build Tools si no están
npm install --global --production windows-build-tools
npm install
```

## Arquitectura en una línea

```
Windows DB (wpndatabase.db) → polling cada 1s → WebSocket → iPhone Safari
```

- Puerto: **3001** (para no pisar el sys-monitor-companion que usa 3000)
- DB path: `%APPDATA%\Microsoft\Windows\Notifications\wpndatabase.db`
- Bundle ID de WhatsApp: `%WhatsApp%` o `%5319275A%` (filtro por LIKE)
- Payload de las notificaciones: XML de Windows Toast → se parsea con regex
- Timestamp: Windows FILETIME (100ns desde 1601-01-01) → se convierte a Unix ms

## Comportamiento del cliente (iPhone)

- **Idle**: ícono de WhatsApp muy grisado, no llama la atención
- **Notificación**: ícono parpadea gris↔verde 2 veces, queda verde + muestra emisor y mensaje
- **Mensaje se oculta a los 5 segundos**, pero el ícono se queda verde
- **Tap en la pantalla**: marca como leído, ícono vuelve a gris
- **WebSocket desconectado**: indicador "OFFLINE" en el header, reconecta automáticamente cada 2s

## Proyecto de referencia

Este proyecto es un fork de `iphone6s-sys-monitor-companion` (mismo usuario de GitHub).
Misma estructura Express + WebSocket + NoSleep.js. La diferencia es el backend:
aquí se usa `better-sqlite3` sobre la DB de Windows en lugar de `systeminformation`.
