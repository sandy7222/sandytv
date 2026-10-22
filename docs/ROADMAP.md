# SandyTV — Hoja de ruta de construcción

> Plan para construir **SandyTV**, una app de televisión por internet para los televisores de la familia.
> Pensado para que una IA (por ejemplo **Sonnet 5.5**) lo siga **fase por fase**, con criterios claros de
> "terminado". Antes de empezar, leer `AGENTS.md` y `docs/ESTADO.md`.

---

## 0. Qué es SandyTV (resumen para quien implementa)

- App para **Android TV** (y cualquier aparato Android conectado a un televisor: TV Box, Chromecast con
  Google TV, Fire TV Stick). Se instala con un **APK** (sin Google Play).
- **Uso personal y familiar.** No se publica en ninguna tienda.
- Muestra canales de TV **en español, para Argentina y Latinoamérica**, con **logos**, **categorías** y una
  **grilla de programación**.
- Los enlaces de los canales **se actualizan solos**: un proceso automático en GitHub prueba cada enlace,
  descarta los caídos o de mala calidad y publica una **cartelera** limpia que la app descarga.
- Extras: **reloj** con hora de Argentina (se muestra u oculta), **tecla de información** del canal,
  **mensajes entre los televisores** de la familia y **calendario de recordatorios**.
- Costo: **cero**. GitHub (gratis) para la cartelera y Supabase (plan gratis, **proyecto nuevo**) para los
  mensajes y el calendario.

### Televisores de la casa (conocidos hoy)

| Televisor | Sistema | Cómo recibe SandyTV |
|---|---|---|
| Noblex 50" **DM50X7550** (etiqueta; el dueño lo identifica con el DR50X7550 de Megatone) | **Android** (según la ficha de Megatone) | APK directo (pendrive o adb) |
| Philips 50" **50PUD8100/77** (dormitorio; misma serie que el 75PUD8100/77 de Frávega) | **Titan OS** (no Android, sin Play Store) | No acepta el APK. Usar un aparato Android por HDMI (Chromecast con Google TV, Fire TV Stick o TV Box) |

---

## 1. Decisiones técnicas (ya tomadas; no cambiarlas sin hablar con el dueño)

| Tema | Decisión | Por qué |
|---|---|---|
| Lenguaje de la app | **Flutter** (Android) | El dueño ya lo tiene instalado (`C:\flutter`) y lo usa en otro proyecto. |
| Reproductor | **`video_player`** (por dentro usa ExoPlayer/Media3, que maneja bien HLS `.m3u8`). Alternativa si falla con algún formato: **`media_kit`**. | No se inventa un reproductor: se usa uno probado. |
| Plataforma | Solo **Android / Android TV**. Ni web, ni Samsung, ni LG por ahora. | Un solo paquete. Los televisores sin Android usan un aparato Android por HDMI. |
| Fuente de canales | **iptv-org** (`github.com/iptv-org/iptv`) + su base de datos (`iptv-org/api`) + una lista propia `mis_canales.json`. | Gratis, se actualiza varias veces por día y trae logo, país y categoría. |
| Cartelera | La arma un script en **GitHub Actions** cada 6 horas y se publica en **GitHub Pages**. | Gratis, sin servidor propio. |
| Mensajes y calendario | **Supabase**, **proyecto nuevo `SandyTV`**. **Nunca** usar el proyecto de CapitanYA. | Necesita tiempo real y datos privados por familia. |
| Instalación | **Pendrive (USB)** como camino principal. Alternativas: **adb por la red** (para el desarrollo) y **Downloader con una URL** (para actualizar). | Ver Fase 6. |
| Idioma | Todo en **español rioplatense**. | |
| Zona horaria | `America/Argentina/Buenos_Aires` (UTC−3, sin horario de verano). | |
| Nombre | App: **SandyTV**. Paquete Android: `ar.sandytv.app`. | |

---

## 2. Cómo está armado (mapa del proyecto)

```
C:\SandyTV\
├── AGENTS.md                ← reglas para cualquier IA (leer primero)
├── CLAUDE.md                ← apunta a AGENTS.md
├── docs\
│   ├── ROADMAP.md           ← este archivo
│   └── ESTADO.md            ← dónde quedó el trabajo (actualizar al final de cada paso)
├── cartelera\               ← generador de la cartelera (Node.js)
│   ├── armar_cartelera.mjs
│   ├── probar_enlace.mjs
│   ├── mis_canales.json     ← canales agregados a mano, favoritos y excluidos
│   ├── config.json          ← filtros: países, idiomas, calidad mínima, etc.
│   └── test\
├── app\                     ← la app Flutter "SandyTV"
│   ├── lib\
│   └── test\
├── supabase\                ← migraciones SQL del proyecto SandyTV (mensajes, calendario)
│   └── migrations\
├── web_celular\             ← página para el celular: mandar mensajes y cargar recordatorios
├── instalacion\             ← guía con fotos/pasos para el pendrive
└── .github\workflows\
    ├── cartelera.yml        ← corre cada 6 h y publica en GitHub Pages
    └── apk.yml              ← (Fase 6) arma el APK y lo deja en Releases
```

**Flujo de datos:**

```
iptv-org (GitHub) ──► script en GitHub Actions ──► cartelera.json + epg.json (GitHub Pages)
                                                                │
                                                                ▼
                    Supabase SandyTV ◄──── mensajes / recordatorios ────► App SandyTV en cada TV
                          ▲
                          └──── página web desde el celular
```

---

## 3. Fases

Cada fase se hace en **pasos chicos**, con **un commit por paso**, y termina con su **criterio de terminado**.
No pasar a la fase siguiente sin cumplir el criterio, o sin anotarlo en `docs/ESTADO.md` si no se pudo.

---

### Fase 0 — Preparar el terreno

1. `git init` en `C:\SandyTV`, rama `main`. Crear `.gitignore` (Flutter, Node, `.env`, `*.jks`, `*.keystore`).
2. Verificar herramientas y anotar versiones en `ESTADO.md`: `flutter --version`, `flutter doctor`,
   `node --version` (si no hay Node, pedirle al dueño que instale la versión LTS).
3. Crear el repositorio en GitHub `sandytv` (**público**, porque GitHub Pages gratis lo pide).
   ⚠️ Crear el repositorio y hacer `git push` requiere **OK del dueño**.
4. Pedirle al dueño el **modelo exacto del Philips** (etiqueta trasera) y anotar qué sistema tiene.

**Terminado cuando:** el repositorio existe, las herramientas responden y el sistema del Philips está anotado.

---

### Fase 1 — La cartelera automática (base de todo)

Objetivo: un archivo `cartelera.json` con **solo canales que funcionan, en español, de calidad aceptable**,
que se regenera solo.

**1.1 Leer las fuentes.** Verificar primero que estas URL existen y anotar en `ESTADO.md` si alguna cambió
(el código manda sobre este documento):
- Base de datos de iptv-org: `https://iptv-org.github.io/api/channels.json`, `streams.json`, `logos.json`,
  `categories.json`, `countries.json`, `languages.json`, `feeds.json`.
- La lista propia `cartelera/mis_canales.json`.

**1.2 Filtrar por región e idioma** (todo configurable en `config.json`):
- Países: `AR` primero; después `UY, CL, PY, BO, PE, CO, VE, EC, MX` y resto de Latinoamérica.
- Idioma: `spa`. **Excluir canales de España** (país `ES`) salvo que estén en `mis_canales.json`.
- Excluir categorías no deseadas (por defecto: `xxx`, `religious` opcional, `shop`) y canales marcados
  `is_nsfw`.
- Agrupar en categorías en español: **Argentina (aire)**, **Noticias**, **Deportes**, **Cine y series**,
  **Documentales**, **Infantiles**, **Música**, **Latinoamérica**, **Otros**.

**1.3 Probar cada enlace** (`probar_enlace.mjs`), en paralelo con un límite (por ejemplo 10 a la vez):
1. Descargar el `.m3u8` (tiempo máximo 8 s). Si falla → **caído**.
2. Si es una lista maestra, leer las variantes (`RESOLUTION`, `BANDWIDTH`) y quedarse con la mejor que
   cumpla los límites.
3. Descargar **un segmento** de video y medir la velocidad.
4. Puntaje: resolución (alto = mejor), velocidad de descarga ≥ 1,5 × el bitrate declarado, tiempo de respuesta.

**Calidad aceptable (valores iniciales en `config.json`):**

| Criterio | Mínimo | Preferido |
|---|---|---|
| Resolución | 480p (si no hay otra opción para ese canal) | 720p o más |
| Respuesta del `.m3u8` | < 8 s | < 3 s |
| Velocidad del segmento | ≥ 1,5 × bitrate | ≥ 3 × bitrate |

⚠️ **Limitación conocida:** GitHub Actions corre en servidores de **EE. UU./Europa**. Algunos canales
argentinos **bloquean conexiones del exterior** (geobloqueo) y van a parecer caídos aunque en Argentina
anden. Por eso:
- Los canales de `mis_canales.json` marcados `"forzar": true` se incluyen aunque fallen la prueba.
- La app **también** prueba los enlaces desde la casa y ordena por lo que realmente anda (Fase 2.6).
- Anotar en `ESTADO.md` qué canales argentinos de aire aparecen como caídos por esto.

**1.4 Elegir un enlace principal por canal** y guardar hasta **2 de reserva**, ordenados por puntaje.

**1.5 Escribir `cartelera.json`** con este formato (versión de formato `1`):

```json
{
  "formato": 1,
  "version": "2026-10-21T18:00:00Z",
  "categorias": [{ "id": "argentina", "nombre": "Argentina (aire)", "orden": 1 }],
  "canales": [
    {
      "id": "Telefe.ar",
      "numero": 1,
      "nombre": "Telefe",
      "emisora": "Telefe S.A.",
      "pais": "AR",
      "ciudad": "Buenos Aires",
      "categoria": "argentina",
      "logo": "https://...",
      "web": "https://...",
      "enlaces": [
        { "url": "https://.../index.m3u8", "alto": 720, "kbps": 2500, "puntaje": 92 }
      ],
      "epg_id": "Telefe.ar"
    }
  ]
}
```

- El **número de canal** es estable: si un canal ya tenía número, lo conserva entre versiones. **Como se
  hizo (2026-10-21):** el mapa `numeros` viaja dentro del propio `cartelera.json` (incluye los canales que
  desaparecieron, para no reutilizar su número) y el generador lo lee de la cartelera ya publicada. No hay
  `numeros.json` en el repo ni commits del bot.
- **No inventar datos:** si iptv-org no trae emisora o logo, el campo queda `null` y la app muestra
  "Sin dato". **Ojo:** iptv-org **no trae la ciudad** del canal, solo el país; por eso el campo `ciudad`
  no existe en la cartelera y la ficha (Fase 3) muestra solo el país.

**1.6 Programación (EPG).** *(Hallazgo del 2026-10-21: iptv-org **no publica las guías ya armadas**: solo
el programa para bajarlas, `iptv-org/epg`, que hay que correr uno mismo y es pesado. Además, de los 181
canales argentinos con enlace, solo ~33 tienen una guía asignada en `guides.json`. Se deja para después
de que la cartelera funcione.)* Investigar el proyecto `iptv-org/epg` y otras guías XMLTV gratuitas para canales
argentinos. Generar `epg.json` con las **próximas 24 h** de los canales que tengan datos. Si un canal no tiene
programación, **no se inventa**: la grilla muestra solo el nombre del canal. Anotar en `ESTADO.md` qué
porcentaje de canales quedó con programación.

**1.7 GitHub Actions** (`.github/workflows/cartelera.yml`): corre cada 6 horas y a mano
(`workflow_dispatch`), ejecuta los tests, genera los archivos y los publica en GitHub Pages.
Si la cartelera nueva tiene **menos del 50 %** de los canales de la anterior, **no publicar** (protección
contra una caída de iptv-org) y dejar el aviso en el log.

**Tests (escribirlos primero):** parseo de m3u8 maestro y simple, filtros de país/idioma/categoría, elección
de la mejor variante, estabilidad de los números de canal, protección del 50 %.

**Terminado cuando:** `https://<usuario>.github.io/sandytv/cartelera.json` existe, se regenera solo, y tiene
al menos 30 canales que el dueño confirma que se ven en VLC desde su casa.

---

### Fase 2 — App mínima: ver canales con el control remoto

**2.1** Crear el proyecto Flutter en `app\` (`flutter create --org ar.sandytv --project-name sandytv app`).
En `AndroidManifest.xml`:
- Nombre visible **SandyTV**, ícono propio.
- `<uses-feature android:name="android.software.leanback" android:required="false"/>` y
  `android.hardware.touchscreen required="false"`.
- Categoría `LEANBACK_LAUNCHER` además de `LAUNCHER` (para que aparezca en el menú del televisor) y un
  **banner** de 320×180.
- Permiso `INTERNET`. Permitir tráfico `http` (hay canales sin https):
  `android:usesCleartextTraffic="true"`.
- Mantener la pantalla encendida mientras se reproduce.

**2.2 Al abrir:** cargar la última cartelera guardada en el aparato (para arrancar rápido y sin internet de
GitHub) y en segundo plano pedir la nueva.

**2.3 Pantalla de inicio de SandyTV (pedido del dueño, 2026-10-21).** Al abrir la app **no aparece un
reproductor ni video**: aparece la **cartelera de inicio de SandyTV**, al estilo de la pantalla de inicio de
Pluto TV, y el reproductor recién arranca cuando se elige un canal.
1. **Presentación (1,5 a 2 s):** logo de SandyTV sobre fondo propio mientras carga la cartelera guardada.
2. **Inicio:** arriba un **destacado grande** (el canal que estás mirando seguido, o un canal de Argentina
   según la hora), y debajo **filas horizontales por categoría** ("Argentina (aire)", "Noticias",
   "Deportes", "Cine y series", etc.) con el **logo** de cada canal. Una fila **"Seguir viendo"** con el
   último canal y otra de **"Favoritos"**. Se navega con las flechas y **OK** pone el canal.
3. **El reproductor es invisible como marca:** se usa solo el motor de video, **sin controles nativos**, sin
   pantalla negra con botones del sistema ni nombre del reproductor. Todo lo que se ve (barra de canal,
   menús, errores, "cargando") es diseño de SandyTV. Mientras un canal conecta se muestra el logo del canal
   sobre fondo de SandyTV, nunca un cuadro negro.
4. **Volver al inicio:** ATRÁS desde el canal abre el Inicio (en vez de cerrar la app).
5. **Opción en Ajustes:** "Al abrir: mostrar Inicio / retomar el último canal" (por defecto: Inicio).
6. Los logos y colores de SandyTV (nombre, ícono, fondo) los define el dueño; hasta tenerlos, usar un
   diseño provisorio simple y sin imitar marcas de terceros (nada del logo ni de los colores de Pluto TV).

**2.3b Reproducción a pantalla completa** del canal elegido (por defecto, el último visto o el 1 la primera
vez), con las teclas del punto siguiente.

**2.4 Control remoto** (probar en el Noblex; los controles cambian según la marca):

| Tecla | Acción |
|---|---|
| ↑ / ↓ y CH+ / CH− | Canal siguiente / anterior |
| Números 0–9 | Ir al canal por número (esperar 1,5 s a que termine de marcar) |
| OK | Mostrar u ocultar la barra del canal (nombre, logo, programa actual) |
| ← / → | Con la barra visible: canal anterior/siguiente **dentro de la categoría** |
| INFO, o mantener OK 1 s, o botón rojo | **Ficha del canal** (Fase 3) |
| GUÍA / EPG, o botón verde | **Grilla** (Fase 3) |
| MENÚ, o botón amarillo | Ajustes |
| ATRÁS | Cerrar lo que esté abierto; en pantalla limpia, pedir confirmación para salir |
| VOLUMEN + / − / SILENCIO | **No interceptarlas**: las maneja el televisor. Solo verificar que funcionan |

Usar `Focus`/`Shortcuts` de Flutter y registrar en un log (modo depuración) los códigos de tecla que manda
cada control, para mapear los que falten. Anotar en `ESTADO.md` qué teclas tiene cada control real.

**2.5 Si un canal no arranca en 10 s:** probar el enlace de reserva; si todos fallan, mostrar
"Este canal no está disponible ahora" y ofrecer pasar al siguiente. Nunca quedar en pantalla negra.

**2.6 Prueba desde la casa:** guardar en el aparato qué enlaces anduvieron y cuáles no, y usar eso para
ordenar los enlaces de reserva (un canal que falla 3 veces seguidas pasa al final de su categoría).

**2.7 Actualización automática de la cartelera:** al abrir y cada 3 horas, comparar `version`; si cambió,
reemplazar la cartelera **sin cortar** el canal que se está mirando.

**Tests:** cambio de canal (incluye pasar del último al primero), marcado por números, elección de enlace de
reserva, actualización sin cortar el canal, cartelera rota o vacía → se mantiene la anterior.

**Terminado cuando:** el dueño instala el APK en el Noblex (por adb o pendrive), cambia de canal con las
flechas y con CH+/CH−, el volumen funciona, y un canal caído no deja la pantalla negra.

---

### Fase 3 — Reloj, ficha del canal y grilla con logos

**3.1 Reloj** en una esquina, hora de Argentina (`America/Argentina/Buenos_Aires`), formato `22:46`.
Ajuste: **mostrar / ocultar** y elegir la esquina. Se guarda en `SharedPreferences` (`sandytv_reloj_*`).
Semitransparente para no tapar el video.

**3.2 Barra del canal** (al cambiar de canal o con OK): número, logo, nombre, programa actual y siguiente con
horario (si hay EPG), reloj. Se oculta sola a los 5 s.

**3.3 Ficha del canal** (tecla INFO / botón rojo / OK mantenido): logo grande, nombre, **emisora**, **país y
ciudad**, categoría, web, calidad del enlace actual (por ejemplo "720p · 2,5 Mbps") y la programación del día.
Los datos que no estén dicen "Sin dato".

**3.4 Grilla** (tecla GUÍA / botón verde):
- Columna izquierda: categorías. Al lado: canales con **logo**, número y nombre.
- A la derecha: franjas de 30 minutos con el **programa** de cada canal, una línea marcando la hora actual.
- Navegación con flechas; OK sobre un canal lo pone.
- Logos guardados en caché en el aparato (descargar una vez).
- Canal sin programación: una sola franja que dice el nombre del canal.

**3.5 Mi lista (cartelera de favoritos) — pedido del dueño, 2026-10-22.** La cartelera completa tiene cientos
de canales (hoy ~940); el uso diario tiene que ser sobre **una lista corta y propia** de cada televisor.
- **Dos modos** que se alternan con un botón (por ejemplo, el azul) o desde Ajustes: **Mi lista** (solo los
  canales elegidos) y **Todos los canales** (la cartelera completa, para descubrir y sumar canales).
- **Agregar:** desde la ficha del canal (INFO), desde la grilla o manteniendo OK sobre un canal en cualquier
  fila: "➕ Agregar a Mi lista". **Quitar:** igual, "➖ Quitar de Mi lista". Un canal puede estar en la
  lista aunque sea de otra categoría.
- **Primera vez:** la app propone una lista inicial corta (por ejemplo los canales del grupo "Argentina
  (aire)" mejor puntuados) y el dueño la ajusta. Mi lista **nunca** arranca vacía.
- **Orden propio:** en Mi lista los canales se pueden **mover** (subir/bajar). CH+/CH− y los números cambian
  de canal **dentro de Mi lista** cuando está activa (los números de Mi lista son 1, 2, 3… propios; el número
  global del canal se ve en la ficha).
- **Las categorías** (Noticias, Deportes…) en modo Mi lista muestran solo los canales de la lista; las
  categorías vacías se ocultan.
- **Si un canal de Mi lista desaparece de la cartelera** (lo sacó el generador por caído): queda en la lista
  **atenuado y con el aviso "No disponible ahora"**, no se borra solo; vuelve a andar si el canal regresa.
- **Dónde se guarda:** primero en el aparato (`SharedPreferences`, clave `sandytv_milista`, guardando el `id`
  del canal, por ejemplo `Telefe.ar`, no el número). **En la Fase 4**, opcional: sincronizar Mi lista entre los
  televisores del hogar (tabla en Supabase), con la posibilidad de que cada televisor tenga la suya.
- **Pantalla "Editar Mi lista"** (desde Ajustes): lista de todos los canales con buscador por nombre y
  filtro por categoría y país, para tildar y destildar muchos de una vez.
- **Tests:** agregar, quitar, reordenar, persistencia al reiniciar, canal que desaparece de la cartelera,
  cambio de canal con CH+/CH− en cada modo.

**Terminado cuando:** el dueño puede ver y ocultar el reloj, abrir la ficha y la grilla con el control, y
elegir un canal desde la grilla.

---

### Fase 4 — Registro de televisores y mensajes entre ellos

**4.1 Proyecto Supabase nuevo `SandyTV`** (plan gratis). ⚠️ Crearlo y aplicar migraciones requiere **OK
del dueño**. Plan gratis: se **pausa a los 7 días sin uso**; anotar cómo reactivarlo en
`instalacion\LEEME.md`.

**4.2 Tablas** (migraciones en `supabase\migrations\`):
- `hogares` (id, nombre, codigo_union de 6 dígitos que vence en 15 min, creado_en).
- `dispositivos` (id, hogar_id, nombre visible —"Living", "Dormitorio"—, tipo `tv` o `celular`,
  usuario_auth, ultimo_contacto).
- `mensajes` (id, hogar_id, de_dispositivo, para_dispositivo o `null` = todos, texto ≤ 200 caracteres,
  creado_en, leido_en).

**4.3 Inscripción entre televisores:**
1. El primer televisor crea el **hogar** y muestra un **código de 6 dígitos** en pantalla.
2. Cada televisor o celular nuevo entra con **inicio de sesión anónimo** de Supabase, escribe el código y
   elige su nombre ("Dormitorio").
3. Desde Ajustes se puede ver la lista de aparatos del hogar, renombrar o quitar uno.

**4.4 Seguridad (RLS):** cada aparato solo lee y escribe mensajes de **su hogar**. El código de unión se
canjea por una función `SECURITY DEFINER` que usa `auth.uid()`. En la app va **solo la clave publicable**
de Supabase, nunca la `service_role`. Escribir tests SQL de RLS (un aparato de otro hogar no ve nada).

**4.5 En el televisor:**
- Mensaje nuevo → cartel arriba del video por 10 s con el nombre de quien lo manda y un sonido corto.
  No corta el video.
- Botón azul (o desde el menú) → **bandeja de mensajes**.
- Responder con **respuestas rápidas**: "Ok", "Ya voy", "Dale", "Ahora no", "👍", y **frases propias** que se
  configuran (por ejemplo "Prepará los mates", "La comida está lista").
- Escribir texto libre con el teclado en pantalla (lento pero posible).

**4.6 Página para el celular** (`web_celular\`, publicada en GitHub Pages): se une al hogar con el mismo
código, elige destino (un televisor o todos) y manda mensajes largos.

**Limitación:** el mensaje llega **mientras SandyTV está abierta**. Si el televisor está apagado o en otra
app, lo ve al volver (bandeja con "no leídos").

**Terminado cuando:** desde el Noblex se manda "Prepará los mates que ya me levanto" al otro televisor
(o al celular), aparece el cartel, y se contesta "Ok, ya estoy preparando" con una respuesta rápida.

---

### Fase 5 — Calendario de recordatorios

**5.1 Tabla** `recordatorios` (id, hogar_id, texto, fecha_hora, repetir: `no` / `diario` / `semanal` /
`mensual` / `anual`, para_dispositivos o `null` = todos, creado_por, activo) y `recordatorios_hechos`
(recordatorio_id, fecha de la ocurrencia, dispositivo, hecho / pospuesto_hasta). Con RLS por hogar, igual
que los mensajes.

**5.2 En el televisor:**
- A la hora indicada, cartel arriba del video: "📅 Hoy hay que salir a hacer compras" con dos opciones:
  **Listo** y **Recordame en 30 min**.
- Si el televisor estaba apagado: al abrir SandyTV muestra los **pendientes** ("Pendiente desde las 10:00").
- **Vista Calendario** (desde el menú): la semana con los recordatorios de cada día.
- La hora se evalúa en el aparato con la zona de Argentina; no hace falta un servidor.

**5.3 Cargar recordatorios:** desde la **página del celular** (cómodo) y desde el televisor (con el control).

**Tests:** cálculo de la próxima ocurrencia para cada tipo de repetición (incluye 29 de febrero y fin de
mes), pendientes al encender, posponer.

**Terminado cuando:** un recordatorio cargado desde el celular aparece a la hora justa en los dos
televisores, y uno semanal vuelve a aparecer la semana siguiente.

---

### Fase 6 — Paquete cerrado de instalación

**6.1 APK firmado:** crear una **clave de firma** propia (`sandytv.jks`). ⚠️ **No subirla a GitHub** y
guardar una copia en lugar seguro: sin esa clave no se puede actualizar la app sin desinstalarla.
Compilar `flutter build apk --release` y llamar al archivo `SandyTV-<version>.apk`.

**6.2 Instalación por pendrive (camino principal).** Escribir `instalacion\LEEME.md` en lenguaje simple:
1. Copiar `SandyTV-x.y.z.apk` a la raíz de un pendrive (formato FAT32 o exFAT).
2. En el televisor: **Ajustes → Seguridad / Privacidad → Fuentes desconocidas** y permitir instalar
   desde el **administrador de archivos**. (El nombre exacto cambia según la marca; anotar el del Noblex.)
   Este cambio lo hace el dueño en su televisor.
3. Si el televisor no trae administrador de archivos, instalar uno desde Google Play (por ejemplo
   "File Commander" o "X-plore"). Verificar cuál anda en el Noblex.
4. Conectar el pendrive, abrir el archivo `.apk`, **Instalar**.
5. Abrir SandyTV desde el menú de apps. Primera vez: elegir nombre del televisor y unirse al hogar.

**6.3 Caminos alternativos:**
- **adb por la red** (para el desarrollo, sin pendrive): activar *Opciones de desarrollador → Depuración por
  red* en el televisor y desde la PC `adb connect <IP>` + `adb install`.
- **Downloader** (app gratuita de Play Store): escribir la dirección del APK publicado en GitHub Releases.
  Útil para actualizar sin pendrive.

**6.4 Aviso de versión nueva:** la app consulta `version_app.json` en GitHub Pages; si hay una versión
nueva de la app, muestra "Hay una actualización de SandyTV" y, si el dueño acepta, la descarga e inicia la
instalación (permiso `REQUEST_INSTALL_PACKAGES`). Opcional: si complica, alcanza con el aviso.

**6.5 Workflow `apk.yml`** (opcional): compila el APK al crear una etiqueta `vX.Y.Z` y lo sube a Releases.
La clave de firma va como **secreto de GitHub**, nunca en el repositorio.

**Terminado cuando:** con solo el pendrive y `LEEME.md`, SandyTV queda instalada y funcionando en el
Noblex y en el segundo televisor (o en su aparato Android por HDMI).

---

## 4. Riesgos y límites (contárselos al dueño cuando corresponda)

- **Enlaces de terceros:** un canal puede dejar de transmitir en cualquier momento. La cartelera lo saca en
  la siguiente actualización, pero no se puede garantizar el 100 %.
- **Geobloqueo:** ver Fase 1.3.
- **Calidad:** si un canal emite en baja resolución, no se puede mejorar. Solo se elige el mejor enlace.
- **Programación (EPG):** puede no existir para muchos canales argentinos chicos. No se inventa.
- **Legalidad:** se usan enlaces públicos, para uso personal y familiar. No publicar la app ni la lista
  en tiendas.
- **Supabase gratis** se pausa con 7 días sin uso.
- **Televisores sin Android** (posiblemente el Philips): necesitan un aparato Android por HDMI.

---

## 5. Orden y tamaño aproximado

| Fase | Qué | Tamaño |
|---|---|---|
| 0 | Preparar | Chica |
| 1 | Cartelera automática | Grande (es la base) |
| 2 | App mínima con control remoto | Grande |
| 3 | Reloj, ficha, grilla | Mediana |
| 4 | Registro y mensajes | Grande |
| 5 | Calendario | Mediana |
| 6 | Paquete de instalación | Mediana |

Se puede adelantar la **Fase 6.2** (instalar por pendrive) apenas termine la Fase 2, para que el dueño
use SandyTV en sus televisores mientras se construye el resto.
