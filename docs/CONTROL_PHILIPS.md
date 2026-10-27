# Cómo se maneja el Philips 50PUD8100/77 (Titan OS) con su control remoto

> Conocimiento ganado **investigando con el dueño** (2026-10-22 al 2026-10-26) con la sonda `web/p/sonda/` y el
> reproductor `web/p/`. Sirve para no volver a descubrirlo. **Si el código no coincide con esto, manda el código.**

## 1. El televisor

- **Philips 50PUD8100/77** (fabricado en Argentina por FAPESA), software `TPM257L_V253.003.073.081` (28/5/2026).
- Sistema **Titan OS** (no es Android): **no instala APK** (ni por pendrive ni con Downloader).
- Navegador: **Opera TV** (Chrome 112, Linux armv7l). Reproduce HLS de forma **nativa** y con hls.js; mezcla de
  contenido: una página **https** **no** puede reproducir canales **http**.
- Tiene la app **DevView** de Titan OS (para probar apps web), pero hace falta una cuenta aprobada en
  `partners.titanos.tv` (solicitud enviada, sin respuesta al 2026-10-26).
- Tiene AirPlay y transmisión de pantalla; **"Ajustes de mouse"** es solo para un mouse físico.

## 2. El control remoto y el navegador: qué le llega a la página

El control funciona en el navegador **como puntero** (flechas = mueven la flecha del mouse, OK = clic). **La mayoría de
los botones NO llegan como teclas.** Resultado de la sonda (huella de cada botón):

| Botón | Qué le llega a la página | Se usa en SandyTV |
|---|---|---|
| **Rojo** (dibujo ◀◀) | tecla `ColorF0Red`, keyCode **403** | canal **anterior** |
| **Amarillo** (dibujo ▶) | tecla `ColorF2Yellow`, keyCode **405** | cambiar **formato** de imagen |
| **Azul** (dibujo ▶▶) | tecla `ColorF3Blue`, keyCode **406** | canal **siguiente** |
| **Verde** (dibujo ⏸) | **no llega nada** (sonda repetida 2026-10-27: "no llegó NADA") | **no se puede usar**: el favorito se agrega con la ☆ o el botón en pantalla |
| **CH +** | **no llega nada** (sonda repetida 2026-10-27; la primera vez se había anotado una rueda hacia arriba, no se repitió) | **no se puede usar** |
| **CH −** | **no llega nada** (idem) | **no se puede usar** |
| **▲** | rueda `deltaY=-50` y scroll hacia arriba (50 px) | canal siguiente (ver abajo) |
| **▼** | rueda `deltaY=+50` | canal anterior (ver abajo) |
| **◀ ▶** | rueda con `deltaY=0` | nada |
| **VOL +, VOL −, Silencio** | la página pierde el foco una vez (barra del televisor); **no se distinguen entre sí** | los maneja el televisor solo |
| **OK** | es el **clic**: no se puede grabar como tecla | clic |
| **Atrás** | tecla `Backspace` (keyCode 8) y además el navegador vuelve (se vio con el detective, 2026-10-26) | volver a la lista |
| **Cualquier botón** | además deja `mousemove` (el puntero aparece) y `blur`/`focus`: **es ruido** | — |

### Comportamiento de ▲ y ▼ (confirmado por el dueño)
Primero mueven el **puntero** hacia arriba o abajo; **recién cuando el puntero llega al borde de la pantalla (techo o
piso) cambia de canal**. Por eso en el reproductor hay un botón **"↕ ▲▼ y CH: sí/no"** para apagarlo.

### Volumen, silencio y aspecto
- **Volumen y silencio** funcionan **solos**: los maneja el televisor, la página no hace nada.
- **Formato de imagen** (original / estirado 16:9 / zoom): botón **amarillo** o el botón en pantalla.

> **Nota (2026-10-26):** en el control del dueño los colores tienen dibujo de reproductor (rojo ◀◀, verde ⏸, amarillo ▶, azul ▶▶), por eso se reasignaron: rojo/azul = canal anterior/siguiente, amarillo = formato.

## 3. Cómo se descubrió (para repetirlo con otro televisor)

1. `web/p/control/` ("Aprender el control"): casillas con forma de control; **solo escucha teclas** → en el Philips
   todo dio "no llegó". No alcanza.
2. `web/p/sonda/`: escucha **todo** (teclas, texto, rueda, scroll, Atrás, multimedia, foco/visibilidad, mouse,
   gamepad) y guarda la **huella por botón** durante 3 s. Ahí aparecieron los colores como teclas y CH+/▲▼ como rueda.
3. Lección: **el código infrarrojo crudo no lo ve la página**; solo lo que el televisor decide reenviar como evento.
4. Trampas que se encontraron: `overflow-x:hidden` en `body` lo vuelve contenedor de scroll (la página no se alarga y no
   se detecta el scroll); cada pulsación manda **muchos avisos seguidos** (hace falta *debounce* de ~700 ms); el
   scroll se detecta con una página alta invisible (6000 px) y recentrándola en 3000 px.

## 4. Pendiente

- **CH + / CH −: CONFIRMADO que no llegan, ni con el detective en el reproductor ni con la sonda repetida (2026-10-27).** Tampoco el **verde**. El televisor se queda con esos botones. Lo anotado la primera vez (CH+ como rueda hacia arriba) no se repitió. Desde una página web **no se pueden usar**: solo una app oficial de Titan OS (DevView/Partner Portal, solicitud pendiente) podría recibirlos. Llegan como tecla: **rojo, amarillo, azul y Atrás (`Backspace`)**; ▲▼ ◀▶ como rueda y puntero; volumen/silencio solo un aviso de foco. Rojo, amarillo, azul y ▲▼ andan también con YouTube en pantalla.
- Por probar con el detective (puede haber más botones que lleguen): números 0–9, INFO, GUÍA, MENÚ, OK largo, ◀ ▶, play/pausa/avance/retroceso.
- Probar el **verde** (favorito) con un canal.
- Una app web real de Titan OS (DevView) recibiría teclas como las apps oficiales: depende de la aprobación.
