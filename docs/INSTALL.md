# Instalación (para quien usa la app)

Guía para instalar y usar **Web Watch Companion** en una PC con Windows. No hace falta
instalar Node.js ni nada más: el instalador trae todo lo que necesita.

## Requisitos

- Windows 10 o 11, 64 bits.
- **WhatsApp Desktop** instalado y abierto al menos una vez (crea la base de datos de
  notificaciones que la app lee).
- Un dispositivo con navegador (por ejemplo un iPhone con Safari) en la **misma red Wi-Fi**
  que la PC.

## 1. Instalar

1. Ejecutá `WebWatchCompanion-Setup-<versión>.exe`.
2. Windows puede mostrar **"Windows protegió su PC"** (SmartScreen), porque el instalador
   no está firmado digitalmente. Elegí **Más información → Ejecutar de todas formas**.
3. En el asistente:
   - Dejá tildada **"Iniciar Web Watch Companion con Windows"** si querés que arranque solo
     al iniciar sesión (recomendado).
   - Al terminar, dejá tildada **"Iniciar Web Watch Companion ahora"**.
4. Cuando arranque por primera vez, Windows pregunta por el **Firewall**. Marcá
   **Redes privadas** y permití el acceso. Sin esto el dispositivo no puede conectarse.

No pide permisos de administrador: se instala solo para tu usuario, en
`%LOCALAPPDATA%\Programs\Web Watch Companion`.

## 2. Ver que está corriendo

Aparece un ícono (un rectángulo apaisado oscuro con un cuadrado verde) en la **bandeja del
sistema**, junto al reloj. Si no lo ves, está dentro del menú de íconos ocultos (flecha `^`).
Al arrancar muestra un globo "Servidor activo en el puerto 47613".

Para comprobarlo, abrí en el navegador de la PC: <http://localhost:47613/status>

## 3. Conectar el dispositivo

1. Averiguá la IP de la PC. La forma más rápida: abrí
   `%LOCALAPPDATA%\WebWatchCompanion\logs\server.out.log` (pegalo en el Explorador de
   archivos) y buscá la línea `Network → http://<IP>:47613`. Alternativa: `ipconfig` en una
   terminal, y usar la "Dirección IPv4" de tu adaptador Wi-Fi/Ethernet.
2. En el dispositivo, abrí esa dirección en el navegador (en un iPhone: Safari, en
   horizontal).
3. **Tocá la pantalla una vez.** Eso activa el modo "pantalla siempre encendida"; sin ese
   toque el dispositivo se puede bloquear solo.
4. Para probarlo sin esperar un mensaje real, abrí en la PC
   <http://localhost:47613/test>: el ícono del dispositivo debería ponerse verde.

## Uso diario

- **Abrir la app a mano**: buscá **Web Watch Companion** en el menú Inicio.
  Si ya estaba corriendo, te avisa con un cartel.
- **Cerrarla**: click derecho en el ícono de la bandeja → **Salir**. Los dispositivos
  conectados reciben el aviso y sueltan la pantalla encendida. Matar los procesos a la
  fuerza (Administrador de tareas, `taskkill /F`) **no** avisa a los dispositivos y puede
  dejar el servidor colgado ocupando el puerto: usá siempre "Salir".
- **Qué muestra el dispositivo**: un ícono de WhatsApp gris que se pone verde con la
  cantidad de mensajes sin leer. Se apaga solo cuando leés los mensajes en cualquier lado;
  también podés tocar la pantalla para apagarlo.

## Actualizar

Ejecutá el instalador de la versión nueva encima. Cierra la app sola, actualiza los
archivos y conserva tus opciones. No hace falta desinstalar antes.

## Desinstalar

**Configuración → Aplicaciones → Web Watch Companion → Desinstalar.** Cierra la app si
está corriendo, y borra los archivos, los accesos directos, el arranque automático y los
logs.

## Cambiar el puerto (opcional)

El puerto por defecto es `47613`. Para cambiarlo, cerrá la app (Salir), editá
`%LOCALAPPDATA%\Programs\Web Watch Companion\config.json` y volvé a abrirla. Ojo: una
actualización del instalador restaura el archivo original.

## Si algo no anda

Mirá [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
