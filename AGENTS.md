# AGENTS.md — Léeme primero

> Instrucciones para **cualquier asistente de IA** que trabaje en SandyTV (Claude, Sonnet, Cursor, Gemini u otro).
> **Antes de hacer nada:** leé este archivo completo, después `docs/ESTADO.md` (dónde quedó el trabajo) y
> `docs/ROADMAP.md` (el plan por fases).
> **Al terminar cada paso:** actualizá `docs/ESTADO.md`.

## 1. Qué es esto

- **SandyTV:** app de televisión por internet (Flutter, Android TV) para los televisores de una familia en
  Argentina. Canales en español que se actualizan solos, grilla con logos, reloj, mensajes entre televisores
  y calendario de recordatorios. Detalle completo en `docs/ROADMAP.md`.
- **Dueño:** una sola persona, **sin presupuesto**, que **no programa**: trabaja con asistentes de IA.
  Todo tiene que ser gratis y mantenible por una persona.
- **Idioma:** español rioplatense, en la app y al hablar con el dueño. Explicar en lenguaje simple, sin jerga.
- **Uso personal y familiar.** No se publica en Google Play ni en ninguna tienda.

## 2. Reglas que no se negocian

1. **Este proyecto está separado de CapitanYA / El Guía YA.** No tocar `C:\CapitanYA` ni su proyecto de
   Supabase (`CapitanYA-MASTER`). SandyTV usa su **propio** proyecto de Supabase `SandyTV`.
2. **La carpeta del proyecto es `C:\SandyTV`.** No trabajar dentro de `C:\Users\sandy\...` (OneDrive/Drive
   sincroniza esa zona y confunde las rutas).
3. **Nunca inventar datos:** ni logos, ni emisoras, ni programación, ni canales. Si no hay dato, "Sin dato".
4. **Nada de secretos en el código ni en el chat.** En la app solo va la clave **publicable** de Supabase.
   La clave de firma del APK (`*.jks`) y la `service_role` **nunca** van al repositorio.
5. **Nada irreversible sin OK explícito del dueño:** crear repositorios, `git push`, crear el proyecto de
   Supabase, aplicar migraciones, borrar datos o archivos, publicar Releases.
6. **Cambios de configuración en los televisores** (fuentes desconocidas, modo desarrollador) los hace el
   dueño. La IA explica los pasos.

## Documento clave del Philips

Cómo se maneja el televisor Philips (Titan OS) con su control remoto y qué le llega al navegador: **`docs/CONTROL_PHILIPS.md`**.

## 3. Cómo se trabaja

1. **Una fase por vez, un paso por vez, un commit por paso.** Mensaje de commit en español: qué cambió y por qué.
2. **Tests primero:** escribir el test, verlo fallar, recién ahí programar. Si un test pasa "de entrada", desconfiar.
3. **Correr los tests antes de cada commit** y reportar el resultado real. Si no se cumple un criterio de
   "terminado" del roadmap, **decirlo**; no ajustar el test para que pase.
4. **Si el código no coincide con el roadmap, manda el código:** anotar la diferencia en `ESTADO.md` y seguir.
5. **Verificar las URL externas** (iptv-org, EPG) antes de usarlas: pueden haber cambiado.
6. **Al terminar cada paso, actualizar `docs/ESTADO.md`:** último paso hecho (con commit), qué sigue y
   problemas nuevos.
7. Si no podés ejecutar comandos, decilo y pedile al dueño que los corra.

**Comandos:**
```bash
# Cartelera
cd cartelera && npm test
# App
cd app && flutter test && flutter analyze
```
