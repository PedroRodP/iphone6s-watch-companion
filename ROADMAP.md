# ROADMAP.md — Web Watch Companion

Próximos pasos para un agente futuro — no hacer ahora salvo que se pida explícitamente.

El MVP funciona end-to-end, incluido el instalador. Lo que sigue, en orden aproximado de
prioridad:

1. ~~**Ejecutable con acceso directo para arrancar/parar el servidor.**~~ **Hecho**: ícono en
   la bandeja del sistema con "Salir" por click derecho (apagado prolijo vía
   `POST /shutdown`), autostart con Windows, puerto propio (47613) e instalador
   (`npm run dist`, Inno Setup, con Node incluido). Ver [docs/TRAY.md](docs/TRAY.md) y
   [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).

   Pendiente de probar con la versión **instalada**: arranque tras reiniciar Windows y
   conexión de un dispositivo (firewall).

   Mejoras opcionales:
   - Que el ícono de bandeja cambie de color cuando hay mensajes sin leer.
   - Firmar el instalador (evita el aviso de SmartScreen; requiere certificado de pago).
   - Regla de firewall automática desde el instalador (requiere permisos de admin).
   - Mini lanzador `.exe` compilado con el `csc.exe` de Windows, para que el Administrador
     de tareas muestre "Web Watch Companion" en vez de "Windows PowerShell".

2. **Aislar WhatsApp como módulo** (motivo del renombre a "Web Watch Companion"; camino
   acordado para sumar funcionalidades nuevas e independientes). Hoy la detección vive en
   `server.js` (polling de `wpndatabase.db`, `hasUnread`, broadcasts `whatsapp_*`) y la UI en
   `public/index.html`. Separar un núcleo genérico (Express, WebSocket, `/shutdown`,
   `/status`, ciclo de vida) de módulos de fuente de alertas (WhatsApp sería el primero) con
   un contrato simple, y que el cliente renderice por tipo de módulo. También queda pendiente
   renombrar la carpeta/repo (`iphone6s-watch-companion`).

3. **Emprolijar y preparar el proyecto para publicarlo en redes sociales.** La documentación
   técnica ya existe (`README.md` y `docs/`, incluyendo la arquitectura completa y el registro
   de decisiones), a un nivel que sirve de base para un post. Falta pulir README/imágenes/demo
   para mostrar la creación: por ejemplo un video corto o GIF del ícono prendiéndose y
   screenshots del cliente.

> Ya implementado y verificado en sesión real (no son pendientes): corte de NoSleep al apagar
> el servidor, reconexión del WebSocket al volver de background/pantalla bloqueada,
> re-enable automático del NoSleep al reconectar, y apagado automático del ícono cuando se
> leen los mensajes. Detalle en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
