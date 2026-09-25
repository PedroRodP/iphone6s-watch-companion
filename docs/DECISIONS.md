# Decisiones de diseño

Registro de las decisiones no obvias y **por qué** se tomaron, incluyendo lo que se probó y
se descartó. Léelo cuando vayas a cambiar algo de fondo o a proponer una alternativa: es
probable que ya se haya evaluado.

Nota de honestidad: las alternativas "descartadas" lo fueron por análisis, no todas se
probaron en la práctica. Las que se probaron y **fallaron** (decisiones 4, 9 y 10) lo dicen
explícitamente.

## 1. Mostrar un contador, no el mensaje

WhatsApp Desktop no usa Toast nativo, solo manda un badge con el conteo. No hay remitente ni
texto que leer por las APIs de Windows. Alternativas (UI Automation sobre la ventana, leer la
caché local) son mucho más frágiles y no se implementaron. Detalle y evidencia en
[ARCHITECTURE.md](ARCHITECTURE.md).

## 2. "Leído" = desaparece la fila, no un badge 0

Se descubrió inspeccionando la DB en vivo: WhatsApp borra la fila en lugar de mandar
`value="0"`. El server detecta esa desaparición mientras hay algo sin leer. La rama de badge 0
se conserva por si otra instalación se comporta distinto.

## 3. El NoSleep se suelta solo con aviso explícito del server

Una desconexión de WebSocket es ambigua (apagado, Wi-Fi, iPhone en background). Soltar el wake
lock por cualquier desconexión apagaría la pantalla en pleno juego. Solo `server_shutdown`
lo libera, y el cliente lo reactiva solo al reconectar.

## 4. Apagar por `POST /shutdown`, no por señales

En Windows, un proceso Node solo recibe una señal de cierre prolija (Ctrl+C, `taskkill` sin
`/F`) si tiene una consola asociada. Corriendo oculto (bandeja, autostart, tarea de un
agente) solo se puede matar a la fuerza, lo que saltea `shutdown()`: los dispositivos nunca
reciben el aviso y quedan con la pantalla despierta. Un endpoint HTTP dispara la misma
`shutdown()` sin depender de ninguna consola. Se restringe a loopback y a un header custom
(que fuerza un preflight CORS) para que una página web no pueda apagar el server. Las señales
siguen funcionando para `node server.js` en una terminal.

## 5. Puerto 47613 en `config.json`

Un puerto arbitrario evita colisiones con los dev servers habituales (3000, 3001, 5173,
8080…). Está fuera del rango efímero de Windows (49152+) y se comprobó que estaba libre y sin
reservar. Vive en un solo archivo que leen el server y el tray; el cliente usa
`location.host`. Se descartó una variable de entorno `PORT` porque el tray no la vería y
quedarían desincronizados.

## 6. Bandeja con PowerShell + WinForms

Se necesitaba un ícono de bandeja sin agregar dependencias ni compilar nada. PowerShell 5.1 y
WinForms `NotifyIcon` vienen con Windows. Se descartaron: librerías de tray para npm (traen
un binario nativo extra que mantener), `node-windows` (servicio de Windows, que no muestra
ícono ni es lo que se buscaba) y un wrapper nativo propio (requiere compilar). Costo aceptado:
en el Administrador de tareas aparece "Windows PowerShell". Un mini lanzador compilado con el
`csc.exe` de Windows lo arreglaría; queda como mejora opcional.

## 7. Autostart con un acceso directo en Startup

Un `.lnk` en la carpeta Startup del usuario es visible y deshabilitable desde el
Administrador de tareas → Inicio, y no necesita admin. Se descartaron la clave `Run` del
registro (menos visible), el Programador de tareas y un servicio (requieren más permisos y
mantenimiento).

## 8. Instalador Inno Setup con Node incluido

Se quería que funcione en cualquier Windows sin depender de una carpeta del repo ni de tener
Node. Se eligió un instalador clásico por usuario (sin admin) con `node.exe` dentro: reutiliza
todo el tray existente y da menú Inicio, autostart opcional y desinstalador de fábrica.
Se descartaron:

- **Un solo `.exe` (Node SEA o `@yao-pkg/pkg`)**: `better-sqlite3` es un módulo nativo y no
  se puede embeber; igual habría que dejar archivos al lado, y el `pkg` original está
  discontinuado. Más complejidad de la que rinde.
- **Zip portable + `install.ps1`**: sin desinstalador prolijo.

El `node.exe` se copia del que compila para que el binario nativo de `better-sqlite3`
coincida siempre con el runtime incluido.

## 9. `npm ci --ignore-scripts` en el build

`better-sqlite3` 13 trae su binario de Windows en `prebuilds/`, pero al instalar desde el
lockfile npm dispara un `node-gyp rebuild` (el lock no registra `gypfile: false`) que falla
sin Python ni Visual Studio. Se saltean los scripts y el único que hace falta, copiar
`NoSleep.min.js`, se hace a mano en el build.

## 10. `[UninstallRun]`, no `CurrentUninstallStepChanged`

Para cerrar la app antes de desinstalar se probó primero el evento de código
`CurrentUninstallStepChanged(usUninstall)`: en pruebas reales nunca se ejecutó en el
desinstalador y la app quedaba corriendo con archivos bloqueados. `[UninstallRun]` (que corre
antes de borrar archivos) funcionó.

## 11. Logs en `%LOCALAPPDATA%\WebWatchCompanion\logs`

La carpeta de instalación no es un buen lugar para escribir, y en desarrollo tampoco conviene
ensuciar el repo. Un único destino para ambos casos; el desinstalador lo borra.

## 12. Ícono "Segunda pantalla"

Un subagente propuso tres ideas relacionadas con el concepto de "watch companion" y se eligió
la segunda:

1. *Vigía*: círculo gris con un punto central verde `#25D366` (la recomendada por ser la más
   legible a 16 px).
2. **Segunda pantalla** (elegida): rectángulo apaisado redondeado (el iPhone en horizontal)
   con relleno `#2B2F36`, borde claro `#E6EDF3` y un cuadrado verde `#25D366` adentro.
3. *Antena de alerta*: punto verde con arcos, descartada por parecerse al ícono genérico de
   Wi-Fi/RSS.

Un segundo subagente la diseñó dibujando cada tamaño por separado con geometría alineada a la
grilla de píxeles (a 16 px: 16×10, cuadrado verde 6×6, borde de 1 px). Sobre fondo claro el
borde casi desaparece y el contorno lo da el relleno oscuro; sobre fondo oscuro lo da el borde
claro.

## 13. Nombre "Web Watch Companion" y WhatsApp como módulo (pendiente)

El proyecto se llamaba `iphone6s-watch-companion` y mostraba "WhatsApp Watch Companion", pero
sirve para cualquier dispositivo con navegador y se quiere poder sumar otras fuentes de
alertas. Se renombró el producto (bandeja, instalador, accesos directos, logs). Aislar
WhatsApp como módulo se acordó como el camino a seguir, pero **todavía no se implementó**;
ver ROADMAP 1b. El repo y la carpeta conservan el nombre viejo.
