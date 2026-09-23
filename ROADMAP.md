# ROADMAP.md — iphone6s-watch-companion

Próximos pasos para un agente futuro — no hacer ahora salvo que se pida explícitamente.

El MVP funciona end-to-end (ver commit que corrige el path de la DB y pasa a detección
por badge count). Lo que sigue, en orden aproximado de prioridad:

1. **Ejecutable con acceso directo para arrancar/parar el servidor.** El usuario quiere
   poder lanzar y apagar el servidor fácilmente antes/después de jugar, sin abrir una
   terminal. Pensar en algo tipo un `.bat`/`.vbs` (o un exe empaquetado, ej. `pkg` o
   `nexe`) con un acceso directo en el escritorio — uno para arrancar (posiblemente
   minimizado/en background) y otro para matar el proceso en el puerto 3001. Debe ser
   robusto a que el server ya esté corriendo (no duplicar procesos) y dar alguna señal
   visible de éxito/error sin depender de que el usuario mire una consola.

   **Requisito importante**: el ejecutable tiene que generar un ícono en la bandeja del
   sistema (system tray) para poder tenerlo minimizado sin una ventana de consola a la
   vista, y ese ícono debe ofrecer un "cerrar"/"salir" por click derecho que dispare el
   apagado — no matar el proceso a la fuerza (`taskkill /F` o equivalente). Como se
   documentó en CLAUDE.md ("Apagado del servidor y NoSleep en el iPhone"), el graceful
   shutdown (`broadcastShutdown()` en `server.js`) depende de que el proceso reciba una
   señal de cierre real (Ctrl+C, `SIGBREAK`, `SIGHUP` por cierre de consola); un kill
   forzado la saltea por completo y el iPhone se queda con el NoSleep activo. Si se
   empaqueta como exe con tray icon (ej. con algo como `node-windows`, o un wrapper
   nativo), el ítem de "salir" del menú del tray tiene que invocar el mismo mecanismo de
   cierre prolijo del proceso hijo (mandarle la señal correspondiente), no simplemente
   matarlo.

2. **Emprolijar el proyecto y documentar la arquitectura.** Una vez que el punto 1
   esté resuelto y el usuario haya probado el flujo real jugando, hacer una pasada de
   limpieza: resumen claro de los componentes (server.js, cliente HTML, WebSocket,
   NoSleep.js) y la lógica funcional completa (detección de badge → broadcast →
   render en el iPhone), a nivel que sirva tanto de documentación técnica como de
   posible base para un post explicando cómo funciona.

3. **Preparar el proyecto para publicarlo en redes sociales.** Pulir README/imágenes/demo
   para mostrar la creación (ej. video corto o GIF del ícono prendiéndose, screenshots
   del cliente). Esto depende de que los puntos 1 y 2 ya estén hechos.

> El corte de NoSleep al apagar el servidor, la reconexión del WebSocket al volver de
> background/pantalla bloqueada, y el re-enable automático del NoSleep al reconectar
> (todos figuraban acá como puntos pendientes) ya están implementados y verificados en
> sesión real — ver "Apagado del servidor y NoSleep en el iPhone" en CLAUDE.md para el
> detalle completo.
>
> El apagado automático del ícono cuando se leen los mensajes también ya está
> implementado y verificado en sesión real — ver "Detección de mensajes leídos
> (auto-clear)" en CLAUDE.md.
