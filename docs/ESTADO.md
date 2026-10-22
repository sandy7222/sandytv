# Estado de SandyTV

**Última actualización:** 2026-10-21

## Dónde estamos

- Creada la carpeta `C:\SandyTV` con `AGENTS.md`, `CLAUDE.md`, `docs/ROADMAP.md` y este archivo.
- **Fase 0, pasos 1 y 2 hechos (2026-10-21):** `git init` en rama `main`, `.gitignore` creado.
  Herramientas verificadas: Flutter 3.41.9 (Dart 3.11.5), Node v26.4.0, npm 11.17.0, git 2.55.0,
  gh 2.97.0 con sesión iniciada en la cuenta `sandy7222`.
- **Fase 0, paso 3 hecho (2026-10-21):** repositorio público creado en
  https://github.com/sandy7222/sandytv y primer push de `main` (con OK del dueño).
- **Todavía no hay código ni proyecto de Supabase.**

- **Fase 1, pasos 1.1 a 1.5 y 1.7 hechos (2026-10-21), sin subir a GitHub todavía:**
  - Generador en `cartelera/` (Node, sin dependencias): `armar_cartelera.mjs` + `lib/`. **45 tests, todos pasan**
    (`cd cartelera && npm test`). Se escribieron primero y se vieron fallar.
  - Se verificó que las URL de `iptv-org.github.io/api/*.json` responden (channels, streams, logos, feeds,
    countries, guides). Los canales sin `channel` en `streams.json` (1.943, entre ellos "TV Publica" suelto)
    se ignoran porque no traen datos; se pueden agregar a mano en `mis_canales.json`.
  - **Corrida real desde la PC del dueño (Argentina):** 1.301 canales candidatos, 1.733 enlaces probados,
    **892 canales aceptados** (72 Argentina aire, 57 noticias, 26 deportes, 28 cine, 43 documentales,
    14 infantiles, 96 música, 556 Latinoamérica). Primer enlace: 347 en 1080p, 373 en 720p, 119 con
    resolución no declarada (la lista no la informa). Están Telefe, El Trece, América, A24, TN, Canal 26,
    DeporTV, TyC Sports. **No** pasaron: TV Pública (`TelevisionPublica.ar`, 404), El Nueve (403),
    Canal 9 Litoral (404). Descartados: 409 (404: 115, calidad baja: 88, no conecta: 64, tiempo: 57, 403: 40).
  - Workflow `.github/workflows/cartelera.yml` escrito (cada 6 h, tests, publicación en GitHub Pages, con la
    protección del 50 %). **No se probó en GitHub** (falta el push y activar Pages).
  - Ojo: la corrida de GitHub sale desde servidores de EE. UU./Europa; los 403 y 404 de canales argentinos
    pueden ser **más** ahí por geobloqueo. Ver el primer informe del workflow antes de confiar en el resultado.
- **Pendiente de Fase 1:** 1.6 (programación/EPG, ver nota en el roadmap) y la confirmación del dueño de que
  30 canales se ven en VLC.

- **Push, GitHub Pages y primer workflow hechos (2026-10-22, con OK del dueño):** Pages activado en modo
  "GitHub Actions". El workflow corrió bien (3 min 44 s) y la cartelera quedó en
  https://sandy7222.github.io/sandytv/cartelera.json (y `informe.json`). Resultado en GitHub: **940 canales de
  1.301** (Argentina 72, noticias 64, deportes 25, cine 31, documentales 46, infantiles 13, música 100,
  Latinoamérica 589). Comparado con la PC del dueño (892): en Argentina 112 vs 116 canales. **Solo pasan desde
  la PC** (probable geobloqueo): DeporTV, Fox Sports, ESPN Premium, Pakapaka, Telefe Salta, Canal 4 Jujuy,
  Metro TV y otros. **Solo desde GitHub** (probable intermitencia): El Nueve y algunos canales chicos.
  **Decidido (2026-10-22):** DeporTV, Fox Sports, ESPN Premium y Pakapaka quedan en `forzar` de `mis_canales.json`
  (se incluyen siempre; si fallan la prueba en GitHub salen sin puntaje de calidad). Pendiente: subirlo con `git push`.
- Aviso de GitHub: las acciones usadas anuncian pasarse a Node 24; no rompe nada hoy, revisar versiones más
  adelante.
- **Fase 2, hecha en código (2026-10-22), sin probar todavía en el televisor:** app Flutter en `app/`
  (paquete `ar.sandytv.sandytv`, versión 0.1.0). **44 tests pasan** (`cd app && flutter test`) y
  `flutter analyze` no marca nada. Lo hecho: manifiesto de Android TV (leanback, sin pantalla táctil, banner
  provisorio, http permitido, pantalla encendida), cartelera guardada en el aparato + una copia incluida en la
  app para el primer arranque sin internet, **presentación → Inicio** (destacado + filas por categoría, sin
  video), **canal a pantalla completa** con barra propia, **↑/↓ y CH+/CH−**, **números**, **OK** muestra/oculta
  la barra, **Atrás** vuelve al Inicio (en el Inicio pide confirmar para salir), **enlaces de reserva** con
  memoria de fallos (un canal con todos los enlaces caídos 3 veces pasa al final de su fila), actualización
  cada 3 h sin cortar el canal, **volumen no interceptado**, y *Ajustes → Probar las teclas del control* para
  descubrir qué manda cada control. Las teclas INFO/GUÍA avisan "llega en la próxima versión" (Fase 3).
  - Decisión: ATRÁS en el canal vuelve al **Inicio** (2.3) y recién en el Inicio pide confirmar la salida.
  - Compilar en esta PC: Flutter usaba el JDK 25 de Android Studio y Gradle fallaba (mensaje "25.0.2");
    se fijó el JDK 17 de la PC en `app/android/gradle.properties` (ruta propia de esta máquina).
  - APK de prueba firmado con la clave de depuración; guía de instalación en `instalacion/LEEME.md`.
  - **Falta para cerrar la Fase 2:** que el dueño lo instale en el Noblex y confirme que cambia de canal con
    las flechas y CH+/CH−, que el volumen anda y que un canal caído no deja la pantalla negra. No se pudo
    probar el video real desde acá (no hay televisor ni emulador conectado).
- **Instalación en el Noblex (2026-10-22):** por pendrive no se pudo: el televisor (visor y X-plore) no muestra los .apk y no deja renombrar un .jpg. Se publicó una **Release pública** `v0.1.0` (pre-release) con el APK para bajarlo con **Downloader**: https://github.com/sandy7222/sandytv/releases/download/v0.1.0/SandyTV.apk . Pendiente: confirmar si Downloader instala; si el Noblex bloquea todo, usar un aparato Android por HDMI.
- **Prueba en el Noblex (2026-10-22, versión 0.1.0):** se instaló con Downloader (código de go.aftvnews.com). La interfaz gusta y las teclas de canal y volumen funcionan. Problemas: (1) *Probar las teclas* dejaba atrapado (no salía con Atrás); (2) los canales cambian pero **no se ve video**: causa sin determinar (enlaces caídos o reproductor del televisor). **Versión 0.1.1** (compilada, sin publicar): Atrás sale de la prueba de teclas y la pantalla de canal sin señal muestra el motivo de cada enlace. 48 tests pasan. Pendiente: que el dueño la instale y diga qué motivo aparece.
- **Cambio de canal sin cortes (pedido del dueño, 2026-10-22, versión 0.1.2):** al cambiar de canal ya no aparece la pantalla entera con el logo: el canal que se mira sigue en vivo hasta que el nuevo arranca, y abajo se ve la barra con el canal nuevo ("Sintonizando…"). Si el nuevo no anda, sigue el anterior y se avisa arriba "Canal N no disponible"; ↑ y ↓ siguen desde el canal elegido, así no se traba. La pantalla entera solo aparece al abrir un canal cuando todavía no hay nada andando. El último canal visto se guarda solo si llegó a arrancar. 53 tests pasan. (Esto hace que haya dos reproductores abiertos un instante durante el cambio; si el Noblex se queda corto de memoria, revisar.)
- **Prueba de la 0.1.2 en el Noblex (2026-10-22): el video SÍ se ve.** Cambio de canal fluido (bien). Problemas y pedidos del dueño: (1) la barra ocupaba toda la pantalla (Column sin mainAxisSize.min): el logo quedaba a media altura y el texto arriba; (2) el logo debe ir **arriba a la derecha** para tapar unos segundos el logo de la imagen; (3) muchos canales vienen en **4:3** y se ven con barras negras; (4) **alternar con el canal anterior**; (5) acelerar el cambio de canal si se puede. Canal 962 Star Channel no abre (el servidor 138.121.15.230 no arrancó en 10 s): enlace lento o caído, normal.
- **Versión 0.1.3 (compilada, sin publicar):** barra de abajo como franja (número, nombre, calidad), **logo arriba a la derecha** (190x100) que se va junto con la barra a los 5 s, **formato de imagen** (original / estirado 16:9 / zoom) con **botón azul** (o tecla de zoom, o F4 en la PC), recordado por canal, y **formato por defecto** en Ajustes; **0 solo = canal anterior** (alterna entre dos canales; también la tecla "último" si el control la tiene). 63 tests pasan. Falta probarla en el Noblex.
  - Sobre la velocidad de cambio: depende de cuánto tarda cada servidor en entregar el primer fragmento de video (1 a 3 s); se podría precargar el canal vecino, pero gasta el doble de datos y memoria. Queda como idea para después.
- **Philips (2026-10-22): confirmado que no se puede instalar nada.** El dueño no logra bajar Downloader y el pendrive no reconoce los .apk (Titan OS, sin Play Store ni instalación externa). Camino: un aparato Android por HDMI (TV Box, Chromecast con Google TV o Fire TV Stick) con SandyTV instalada. Decisión de compra pendiente del dueño.
- **Philips tiene navegador web (2026-10-22).** Titan OS corre apps web (HTML5) sobre Chromium; la vía oficial es publicar en su tienda (improbable para esta app). Plan: una **versión web de SandyTV** que se abra en el navegador del Philips. Primer paso: página de prueba `web/p/index.html`, publicada con la cartelera en `https://sandy7222.github.io/sandytv/p/` (el workflow copia `web/` a la página). Mide si el navegador reproduce HLS (nativo o con hls.js) y qué teclas llegan; "Probar todos" recorre 18 canales y deja una tabla para fotografiar. Probada en el navegador de la PC: reproduce (nativo). **Riesgo conocido:** la página es https y Chromium bloquea los canales http (contenido mixto); con hls.js además hace falta que el servidor del canal permita CORS. La prueba lo va a mostrar.
- **Navegador del Philips (2026-10-22):** tiene una pantalla de **accesos** donde el dueño ya guardó una página (la de AFTVnews) y aparece con su ícono. Se agregaron íconos provisorios de SandyTV (`web/icono-*.png`, generados con `tool/generar_iconos_web.mjs`) y `web/manifest.json` para que el acceso a SandyTV muestre su logo. El Philips también tiene AirPlay y transmisión de pantalla (no se usan por ahora).
- **Pedido nuevo del dueño (2026-10-22):** "Mi lista" (cartelera de favoritos para no usar los ~940 canales),
  con agregar y quitar canales. Anotado como paso **3.5** del roadmap (reemplaza al antiguo "Favoritos").
- **Pedido nuevo del dueño (2026-10-21):** al abrir la app se ve una **pantalla de inicio de SandyTV** (como la
  de Pluto TV), sin que se vea el reproductor hasta elegir un canal. Anotado como paso **2.3** del roadmap.

## Qué sigue

0. **Instalar el APK en el Noblex y probar** (ver `instalacion/LEEME.md`).
1. (hecho) `git push` del cambio de `forzar` (con OK) y revisar que esos 4 canales aparezcan en la cartelera publicada.
2. Pedirle al dueño que abra algunos canales de la cartelera en VLC (criterio de "terminado" de la Fase 1).
3. Fase 0, paso 4: modelo del Philips (pendiente del dueño).
4. Después, Fase 2 (app).

## Datos pendientes del dueño

- ~~Modelos~~ **Recibidos (2026-10-22, por foto de las etiquetas):** Philips **50PUD8100/77** (fabricado por FAPESA) y Noblex **DM50X7550**.
  El dueño confirma (2026-10-22): Philips = Titan OS (como el 75PUD8100/77 de Frávega) y Noblex = Android (como el DR50X7550 de Megatone).
  Consecuencia: el **Philips necesita un aparato Android por HDMI**; el Noblex acepta el APK. Pendiente: decidir qué aparato comprar para el Philips.
- Qué controles remotos hay (marca/modelo) y si tienen teclas INFO, GUÍA y de colores.

## Problemas conocidos

- (ninguno todavía)
