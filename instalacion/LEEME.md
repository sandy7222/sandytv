# Cómo instalar SandyTV en un televisor Android (por pendrive)

> Sirve para el **Noblex** (Android). El **Philips (Titan OS)** no acepta este archivo: ahí hay que
> instalarla en un aparato Android conectado por HDMI (Chromecast con Google TV, Fire TV Stick o TV Box).

## Lo que necesitás
- El archivo **`SandyTV-0.1.0-prueba.apk`** (está en esta carpeta, `C:\SandyTV\instalacion`).
- Un **pendrive** (formato FAT32 o exFAT) y la **PC**.

## Pasos
1. **En la PC:** copiá el archivo `.apk` a la raíz del pendrive (sin carpetas).
2. **En el televisor:** conectá el pendrive a un puerto USB.
3. **Abrí un administrador de archivos** en el televisor. Si no tiene uno, instalá desde la tienda de
   aplicaciones (Google Play) uno gratuito, por ejemplo *X-plore* o *File Commander*.
4. Entrá al pendrive y elegí el archivo `SandyTV-0.1.0-prueba.apk`.
5. Si el televisor avisa **"Por seguridad, no se permite instalar apps de fuentes desconocidas"**: tocá
   **Configuración** y activá el permiso **para ese administrador de archivos** (no para todo el televisor).
   Volvé atrás y elegí el archivo otra vez.
6. Tocá **Instalar**. Al terminar, tocá **Abrir** (o buscá SandyTV en el menú de aplicaciones).

## Qué deberías ver
1. El logo de **SandyTV** unos segundos.
2. La pantalla de **Inicio** con un canal destacado y filas por categoría (sin video todavía).
3. Con las flechas elegís un canal y con **OK** se abre.
4. En el canal: **↑ / ↓** (o **CH+ / CH−**) cambian de canal, los **números** van a un canal, **OK** muestra
   u oculta la barra del canal, **Atrás** vuelve al Inicio. El **volumen** lo maneja el televisor como siempre.

## Si algo no anda
- **No encuentro el archivo:** fijate que esté en la raíz del pendrive y que el pendrive sea FAT32 o exFAT.
- **"App no instalada":** puede haber una versión anterior con otra firma; desinstalá SandyTV y probá de nuevo.
- **Un canal no abre:** es normal que algunos enlaces estén caídos; la app prueba sola otro enlace del mismo
  canal y, si no hay ninguno, lo avisa. Pasá a otro con ↑.
- **Una tecla del control no hace nada:** en *Ajustes → Probar las teclas del control* se ve qué tecla manda
  tu control. Anotala y pasásela a quien programa la app.

## Para quien mantiene el proyecto
- Cómo se genera el APK de prueba: `cd app && flutter build apk --release`
  (queda en `app\build\app\outputs\flutter-apk\app-release.apk`).
- Este APK de prueba va firmado con la clave de depuración. La clave propia de SandyTV se crea en la Fase 6.
