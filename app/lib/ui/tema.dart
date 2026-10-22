import 'package:flutter/material.dart';

// Colores provisorios de SandyTV (los definitivos los elige el dueño).
class Colores {
  static const fondo = Color(0xFF0A0E1A);
  static const superficie = Color(0xFF141B2D);
  static const acento = Color(0xFF22D3EE);
  static const texto = Color(0xFFF1F5F9);
  static const textoSuave = Color(0xFF94A3B8);
}

ThemeData temaSandyTv() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colores.fondo,
      colorScheme: const ColorScheme.dark(primary: Colores.acento, surface: Colores.superficie),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );

/// Logo provisorio: texto simple, sin imitar a ninguna otra marca.
class LogoSandyTv extends StatelessWidget {
  const LogoSandyTv({super.key, this.tam = 32});
  final double tam;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Sandy', style: TextStyle(fontSize: tam, fontWeight: FontWeight.w800, color: Colores.texto, letterSpacing: -0.5)),
      const SizedBox(width: 4),
      Container(
        padding: EdgeInsets.symmetric(horizontal: tam * 0.25, vertical: tam * 0.02),
        decoration: BoxDecoration(color: Colores.acento, borderRadius: BorderRadius.circular(tam * 0.2)),
        child: Text('TV', style: TextStyle(fontSize: tam, fontWeight: FontWeight.w900, color: Colores.fondo)),
      ),
    ]);
  }
}

/// Logo de un canal; si no hay logo o no carga, muestra el nombre.
class LogoCanal extends StatelessWidget {
  const LogoCanal({super.key, required this.url, required this.nombre, this.alto = 56});
  final String? url;
  final String nombre;
  final double alto;

  @override
  Widget build(BuildContext context) {
    Widget nombreTexto() => Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(nombre, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: alto * 0.28, fontWeight: FontWeight.w600, color: Colores.texto)),
          ),
        );
    if (url == null) return nombreTexto();
    return Image.network(
      url!,
      height: alto,
      fit: BoxFit.contain,
      cacheHeight: (alto * 2).round(),
      errorBuilder: (_, _, _) => nombreTexto(),
      loadingBuilder: (c, child, p) => p == null ? child : SizedBox(height: alto),
    );
  }
}
