# CLAUDE.md — Web Watch Companion

Server Node.js para **Windows** que lee las notificaciones de WhatsApp Desktop (badge en la
DB del Centro de notificaciones) y las manda por WebSocket a un navegador, típicamente un
iPhone 6s en horizontal que hace de pantalla de alerta secundaria mientras el usuario juega.
Se distribuye como un instalador de Windows con ícono en la bandeja del sistema.

El repo/carpeta todavía se llama `iphone6s-watch-companion`; el producto es **Web Watch
Companion**. La documentación está en `docs/`, dividida por tema: **leé solo lo que la tarea
necesita**.

## Qué leer según la tarea

| Si vas a… | Leé |
|---|---|
| Tocar `server.js`, `public/index.html`, el protocolo WebSocket o la detección | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Tocar `tray/` o el ciclo de vida del proceso | [docs/TRAY.md](docs/TRAY.md) |
| Tocar `installer/`, `tools/build-installer.ps1` o publicar una versión | [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) |
| Ayudar a alguien a instalar o usar la app | [docs/INSTALL.md](docs/INSTALL.md) |
| Correr, verificar o convencionar código | [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) |
| Diagnosticar un error | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Cuestionar o cambiar una decisión de fondo | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Saber qué queda por hacer | [ROADMAP.md](ROADMAP.md) (no leer si no hace falta) |

## Comandos

```bash
npm install     # una vez
node server.js  # server con consola (Ctrl+C cierra prolijo)
npm run tray    # bandeja + server oculto, como la app instalada
npm run dist    # genera dist/WebWatchCompanion-Setup-<versión>.exe (requiere Inno Setup 6)
curl http://localhost:47613/status
```

## Reglas que no hay que romper

- **Puerto**: `47613`, solo en `config.json` (lo leen el server y el tray; el cliente usa
  `location.host`). No escribirlo a mano en otro lugar.
- **Apagado prolijo**: los dispositivos solo sueltan el NoSleep si reciben `server_shutdown`.
  Cerrar el server con `POST /shutdown` (header `X-Watch-Companion: 1`, solo loopback) o
  Ctrl+C. **Nunca** `taskkill /F` ni matar procesos a la fuerza salvo último recurso.
- **No correr dos instancias** (repo + app instalada): mismo puerto y mismo mutex del tray.
  Cerrar la instalada con su ícono → Salir antes de probar desde el repo.
- **`tray/tray.ps1` y `tray/stop.ps1` son ASCII puro** (PowerShell 5.1 los lee como ANSI).
- **No cambiar el `AppId`** de `installer/setup.iss`.
- La DB de notificaciones está en `AppData\Local`, **no** `Roaming`.
- WhatsApp Desktop solo expone un **contador** (badge), no remitente ni texto; no intentar
  leer el mensaje por las APIs de notificación (ver ARCHITECTURE.md).
- WhatsApp todavía **no** está aislado como módulo; esa es la dirección acordada (ROADMAP 1b)
  pero no se implementó. No hacerlo sin que se pida.

## Idioma

Comentarios de código en inglés; documentación y mensajes al usuario en español; mensajes de
commit en inglés, en imperativo.
