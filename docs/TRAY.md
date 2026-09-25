# Bandeja del sistema

Cómo funciona el ícono de la bandeja que arranca y apaga el server. Léelo antes de tocar
`tray/` o el ciclo de vida del proceso.

## Archivos

| Archivo | Rol |
|---|---|
| `tray/tray.ps1` | Host de la bandeja: arranca el server, muestra el ícono, vigila el proceso |
| `tray/launch.vbs` | Lanza `tray.ps1` sin ninguna ventana (los accesos directos apuntan acá) |
| `tray/stop.ps1` | Apaga server + tray y espera a que terminen; lo usa el instalador |
| `assets/tray.ico` | Ícono multi-resolución (16/24/32/48/256), diseño "Segunda pantalla" |
| `tools/make-icon.ps1` | Regenera el `.ico` y `assets/tray-preview.png` (solo System.Drawing) |

`launch.vbs` existe porque `powershell.exe -WindowStyle Hidden` a secas igual muestra una
consola un instante; corriéndolo con `wscript` y estilo de ventana 0 no aparece nada.

## Cómo funciona `tray.ps1`

PowerShell 5.1 + WinForms `NotifyIcon`, sin dependencias.

1. **Instancia única** con el mutex `Local\WebWatchCompanionTray`. Un segundo lanzamiento
   (por ejemplo desde el menú Inicio con la app ya corriendo) muestra un cartel "Ya está en
   ejecución" y sale.
2. **Elige el Node**: `runtime\node.exe` si existe (app instalada); si no, el `node` del PATH
   (repo en desarrollo).
3. **Arranca `node server.js` oculto**, con stdout/stderr redirigidos a
   `%LOCALAPPDATA%\WebWatchCompanion\logs\server.out.log` y `server.err.log`. Justo después
   toca `$proc.Handle`, porque sin eso `ExitCode` puede volver vacío más tarde.
4. **Ícono con un solo ítem de menú: "Salir".** Hace `POST http://127.0.0.1:<port>/shutdown`
   con el header `X-Watch-Companion: 1`, espera hasta 5 s a que node termine (así corre
   `shutdown()` y los dispositivos reciben `server_shutdown`) y solo si no terminó lo mata
   (último recurso). Después cierra el tray.
5. **Timer de 2 s** sobre el proceso node:
   - La primera vez muestra un globo "Servidor activo en el puerto N".
   - Si node terminó con **exit code 0** (apagado prolijo, por ejemplo desde `stop.ps1`), el
     tray se cierra en silencio.
   - Si terminó con otro código (por ejemplo, el puerto ya estaba ocupado), muestra un globo
     de error apuntando a los logs y se cierra, para no dejar un ícono de un server muerto.

## `POST /shutdown` (lado server)

Definido en `server.js`. Solo acepta conexiones loopback y exige el header
`X-Watch-Companion: 1`, que fuerza un preflight CORS: así una página web cualquiera no puede
apagar el server con un POST cross-origin. Sin ellos devuelve 403; un `GET` da 404. Llama a la
misma `shutdown()` que las señales de proceso.

## `stop.ps1`

Hace el `POST /shutdown` y espera hasta ~10 s a que no quede ningún `node`, `powershell` o
`wscript` ejecutándose desde el directorio de instalación (la propia instancia excluida). El
tray sigue al server hacia afuera por el punto 5. Si algo sigue vivo pasado el plazo, lo mata:
un actualizador o desinstalador nunca debe fallar por un archivo bloqueado. Es seguro
ejecutarlo cuando no hay nada corriendo.

## Reglas al editar

- **`tray.ps1` y `stop.ps1` deben ser ASCII puro**: Windows PowerShell 5.1 lee los `.ps1` sin
  BOM como ANSI y rompe acentos y guiones largos. Los textos del globo y de los carteles van
  sin tildes por eso.
- Cualquier variable que el timer modifique debe llevar `$script:` (`$script:announced`); en
  un handler de WinForms, una asignación sin ese prefijo crea una variable local y se pierde.
- Un cambio en el tray se puede probar sin tocar el ícono: una copia temporal del script que
  dispare `$exitItem.PerformClick()` con un timer verifica el flujo de "Salir" (así se probó).

## Limitación conocida

Si alguien mata el `powershell.exe` del tray a la fuerza, el `node.exe` queda huérfano
ocupando el puerto, y el próximo arranque del tray falla con "El servidor se detuvo". Se
arregla ejecutando `tray/stop.ps1` o cerrando ese `node.exe` a mano.

## Estado de verificación

Verificado en sesión real: arranque oculto; `/status`; `/shutdown` rechaza sin header (403) y
con `GET` (404); shutdown por HTTP cierra node y tray; el handler de "Salir"; `stop.ps1` cierra
todo en ~2 s; arranque al reiniciar Windows y click derecho → Salir sobre el ícono real (esto
último con la versión de desarrollo, antes del instalador); la app instalada corre bien y el
ícono se ve correctamente.
