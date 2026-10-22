/// Cómo se acomoda la imagen en la pantalla. Muchos canales vienen en 4:3 y se ven con barras negras a los costados.
enum FormatoImagen {
  /// Se respeta la proporción del canal (los de 4:3 llevan barras negras).
  original('original', 'original'),

  /// Se estira para llenar la pantalla 16:9 (la imagen se ve un poco ensanchada).
  estirar('estirar', 'estirado 16:9'),

  /// Se agranda un tercio y se recorta arriba y abajo, sin deformar. Sirve para canales en 4:3 y para
  /// los 16:9 que traen la imagen 4:3 con barras negras incluidas en el propio video.
  zoom('zoom', 'zoom');

  const FormatoImagen(this.codigo, this.nombre);

  /// Para guardarlo en el aparato.
  final String codigo;

  /// Para mostrarlo en pantalla después de "Formato: ".
  final String nombre;

  FormatoImagen get siguiente => FormatoImagen.values[(index + 1) % FormatoImagen.values.length];

  static FormatoImagen? desdeCodigo(String? codigo) {
    for (final f in FormatoImagen.values) {
      if (f.codigo == codigo) return f;
    }
    return null;
  }
}
