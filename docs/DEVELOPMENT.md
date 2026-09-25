# Desarrollo

Cómo trabajar sobre el código desde el repo. Para instalar la app como usuario ver
[INSTALL.md](INSTALL.md); para generar el instalador, [DISTRIBUTION.md](DISTRIBUTION.md).

## Requisitos

- Windows 10/11 (la detección lee la DB de notificaciones de Windows; no corre en otros SO).
- Node.js ≥ 22.
- WhatsApp Desktop abierto al menos una vez (para que exista la DB).

## Setup (una vez)

```bash
npm install
```

El `postinstall` copia `NoSleep.min.js` a `public/`; no hace falta hacerlo a mano. Si
`better-sqlite3` falla al instalar, ver [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Correr

```bash
node server.js   # con consola: imprime la IP local; Ctrl+C cierra de forma prolija
npm run tray     # como la app instalada: bandeja + server oculto, con el node del PATH
```

Abrir `http://<IP>:47613` en el dispositivo (Safari del iPhone, en horizontal).

**No correr dos instancias a la vez** (repo + app instalada, o tray + `node server.js`):
comparten puerto y el mutex del tray. Si la app instalada está corriendo, cerrarla antes con
su ícono → Salir.

Con `npm run tray` no hay consola: los logs van a
`%LOCALAPPDATA%\WebWatchCompanion\logs\`.

## Verificar

```bash
curl http://localhost:47613/status   # dbExists: true, dbAccessError: false
curl http://localhost:47613/test     # el dispositivo conectado debe mostrar el ícono verde
```

Para cerrar como lo hace la bandeja:

```bash
curl -X POST -H "X-Watch-Companion: 1" http://localhost:47613/shutdown
```

No hay suite de tests automáticos. La verificación es manual: los comandos de arriba, un
mensaje real de WhatsApp y, para cambios de UI, un dispositivo real (el comportamiento de iOS
Safari con NoSleep y la pantalla bloqueada no se reproduce en un navegador de escritorio).

## Estructura del repo

```
server.js            servidor (Express + WebSocket + polling + apagado)
config.json          puerto compartido por server y tray
public/index.html    cliente
tray/                bandeja del sistema (tray.ps1, launch.vbs, stop.ps1)
assets/              tray.ico y su vista previa
installer/setup.iss  script de Inno Setup
tools/               build-installer.ps1, make-icon.ps1
docs/                documentación (este directorio)
dist/                salida del build (ignorado por git)
```

## Convenciones

- **Idiomas**: comentarios de código en inglés; documentación y mensajes al usuario en
  español.
- **Scripts de PowerShell que corre Windows PowerShell 5.1** (`tray.ps1`, `stop.ps1`): ASCII
  puro, sin `&&`, sin operadores de PowerShell 7. Ver [TRAY.md](TRAY.md).
- **Un solo lugar para el puerto**: `config.json`. No escribirlo a mano en otro archivo.
- **Apagado**: cualquier cambio que toque el cierre del proceso debe conservar el aviso
  `server_shutdown` a los clientes (ver [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Commits**: mensajes en inglés, en imperativo, una idea por commit (así está el historial).

## Regenerar el ícono

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tools/make-icon.ps1
```

Genera `assets/tray.ico` y `assets/tray-preview.png`. Cada tamaño se dibuja por separado
(no se reescala uno solo) para que el de 16 px quede nítido; el script escribe a mano el
encabezado ICO porque `System.Drawing.Icon.Save` no crea `.ico` multi-resolución. Detalles
de diseño y alternativas descartadas en [DECISIONS.md](DECISIONS.md).

## Vista previa en el agente

`.claude/launch.json` define el server `Web Watch Companion` (`npm start`, puerto 47613) para
el panel de vista previa.
