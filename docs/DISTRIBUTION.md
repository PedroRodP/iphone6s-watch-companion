# Distribución (para quien arma y publica el instalador)

Cómo generar y distribuir `WebWatchCompanion-Setup-<versión>.exe`. Lo que ve el usuario
final está en [INSTALL.md](INSTALL.md).

## Resumen

```bash
npm run dist
# → dist/WebWatchCompanion-Setup-<versión>.exe  (~25 MB)
```

Ese único `.exe` es lo que se distribuye. Trae la app, sus dependencias y un `node.exe`
propio: quien lo instala no necesita Node.js.

## Requisitos de la máquina de build

- Windows 10/11 x64.
- **Node.js ≥ 22** en el PATH (lo pide `better-sqlite3` 13). Este mismo `node.exe` es el que
  se copia dentro del instalador, así que **la versión de Node del build es la que llega a
  los usuarios**.
- **Inno Setup 6**: `winget install JRSoftware.InnoSetup --scope user` (queda en
  `%LOCALAPPDATA%\Programs\Inno Setup 6`). El script lo busca en el PATH y en las rutas
  habituales; si no lo encuentra, falla con un mensaje claro.
- Acceso a internet la primera vez (`npm ci` baja las dependencias).

No hace falta tener el repo con `node_modules` instalado: el build usa su propia copia.

## Publicar una versión

1. Subir la versión en `package.json` (`"version"`, y el mismo campo en `package-lock.json`).
   El nombre del archivo y la versión que muestra Windows salen de ahí.
2. `npm run dist`.
3. **Probar el instalador** con el ciclo de abajo.
4. Distribuir el `.exe` (por ejemplo, adjuntándolo a un GitHub Release del repo). `dist/`
   está en `.gitignore`: el instalador no se commitea.

### Ciclo de prueba antes de publicar

Idealmente en una PC o VM sin Node instalado. Estos pasos se probaron en sesión real:

1. Instalar (con la casilla de autostart) y arrancar desde el menú Inicio: debe aparecer el
   ícono en la bandeja y `http://localhost:47613/status` debe responder.
2. Con la app corriendo, **actualizar** ejecutando el mismo instalador encima: debe cerrarla
   sola y terminar sin errores.
3. Con la app corriendo, **desinstalar**: no debe quedar la carpeta de instalación, ni
   `%LOCALAPPDATA%\WebWatchCompanion`, ni accesos directos, ni procesos, y el puerto debe
   quedar libre.
4. Reiniciar Windows con el autostart activado: la app debe levantar sola.
5. Conectar un dispositivo (ver el aviso de firewall abajo) y probar `/test`.

Los pasos 1–3 se verificaron. Los pasos 4 y 5 **todavía no se verificaron con la versión
instalada** (el arranque tras reinicio sí se probó con la versión de desarrollo).

## Qué hace el build (`tools/build-installer.ps1`)

1. Arma `dist/stage/` con `server.js`, `config.json`, `package.json`, `public/`, `tray/` y
   `assets/` (sin `tray-preview.png`).
2. Corre `npm ci --omit=dev --ignore-scripts` ahí adentro y copia `NoSleep.min.js` a
   `public/` a mano.
   - `--ignore-scripts` es necesario: `better-sqlite3` 13 trae su binario de Windows en
     `prebuilds/`, pero al instalar desde el lockfile npm intenta igual un `node-gyp
     rebuild`, que falla sin Python ni Visual Studio.
3. Poda `better-sqlite3`: deja solo `prebuilds/win32-x64.node` y borra `deps/` y `src/`.
4. Copia el `node.exe` del build a `dist/stage/runtime/`.
5. Prueba de humo: con ese `node.exe`, abre una base SQLite en memoria y carga `express` y
   `ws`. Si falla, corta antes de empaquetar.
6. Compila `installer/setup.iss` con `ISCC.exe`, pasando la versión.

## Qué hace el instalador (`installer/setup.iss`)

- **Por usuario, sin admin** (`PrivilegesRequired=lowest`): instala en
  `%LOCALAPPDATA%\Programs\Web Watch Companion`.
- Crea la entrada **Web Watch Companion** en el menú Inicio (así la encuentra la búsqueda de
  Windows) y, si el usuario tilda la tarea `autostart`, un acceso directo en la carpeta
  Startup. Todos apuntan a `wscript.exe tray\launch.vbs`, que lanza el tray sin ventana.
- Ofrece iniciar la app al terminar (se omite en instalaciones silenciosas).
- Se registra en Aplicaciones para desinstalar.
- **Actualización**: `PrepareToInstall` ejecuta `tray/stop.ps1` para cerrar la app y que no
  haya archivos bloqueados.
- **Desinstalación**: `[UninstallRun]` ejecuta el mismo `stop.ps1` antes de borrar archivos, y
  `[UninstallDelete]` elimina `%LOCALAPPDATA%\WebWatchCompanion` (logs).

### Cosas que no hay que romper

- **`AppId`** en `setup.iss`: es lo que hace que una versión nueva se reconozca como
  actualización de la anterior. No cambiarlo nunca.
- **No usar `CurrentUninstallStepChanged`** para cerrar la app al desinstalar: en pruebas
  reales nunca se ejecutó en el desinstalador y la app quedaba corriendo con archivos
  bloqueados. `[UninstallRun]` funciona.
- **Rutas con espacios**: la carpeta de instalación tiene espacios; los `Parameters` de los
  accesos directos y de `[UninstallRun]` van entre comillas.
- **`tray.ps1` y `stop.ps1` en ASCII** (ver [TRAY.md](TRAY.md)).
- El `node.exe` incluido es **x64**. Un Windows ARM lo ejecuta por emulación; no se probó.

## Firma y avisos de Windows

- El instalador **no está firmado**. En otras PCs SmartScreen muestra "Windows protegió su
  PC"; se salta con *Más información → Ejecutar de todas formas*. Firmarlo requiere un
  certificado de firma de código (de pago) y es la única forma de evitar el aviso del todo.
- El **Firewall de Windows** pregunta la primera vez que corre el `node.exe` incluido; hay
  que permitir **redes privadas**. Una regla automática desde el instalador requeriría
  permisos de administrador; está anotada en el [ROADMAP](../ROADMAP.md).
- Windows Defender puede analizar el `.exe` la primera vez. Nunca produjo un bloqueo en las
  pruebas, pero no está garantizado en otras PCs.

## Alternativas que se descartaron

Están explicadas en [DECISIONS.md](DECISIONS.md) (un solo `.exe` con Node SEA o `pkg`, zip
portable).
