import 'package:flutter/material.dart';

import '../modelos/peliculas.dart';
import '../servicios/estado_app.dart';
import 'tema.dart';

/// Menú de películas: portadas por género. Al elegir una, se abre con el reproductor oficial de YouTube
/// (con sus propias publicidades) y al volver atrás se regresa a este menú.
class PantallaPelis extends StatelessWidget {
  const PantallaPelis({super.key, required this.estado});
  final EstadoApp estado;

  Future<void> _ver(BuildContext context, Pelicula p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await estado.abrirVideo(p.urlYoutube);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo abrir YouTube. Fijate que la app de YouTube esté instalada en el televisor.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = estado.peliculas;
    return Scaffold(
      body: catalogo == null
          ? const Center(child: Text('No hay películas todavía.', style: TextStyle(fontSize: 22)))
          : ListView(
              cacheExtent: 900,
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
              children: [
                const LogoSandyTv(tam: 30),
                const SizedBox(height: 14),
                const Text('Películas', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Elegí una con OK. Atrás te trae de vuelta acá.', style: TextStyle(fontSize: 16, color: Colores.textoSuave)),
                for (final g in catalogo.generosConPeliculas) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24, left: 8),
                    child: Text(g.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalogo.delGenero(g.id).length,
                      itemBuilder: (_, i) {
                        final p = catalogo.delGenero(g.id)[i];
                        return _TilePelicula(pelicula: p, alElegir: () => _ver(context, p), autofocus: g == catalogo.generosConPeliculas.first && i == 0);
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _TilePelicula extends StatefulWidget {
  const _TilePelicula({required this.pelicula, required this.alElegir, this.autofocus = false});
  final Pelicula pelicula;
  final VoidCallback alElegir;
  final bool autofocus;

  @override
  State<_TilePelicula> createState() => _TilePeliculaState();
}

class _TilePeliculaState extends State<_TilePelicula> {
  bool _enfocado = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pelicula;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _enfocado = v),
      onFocusChange: (v) {
        if (v) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.alElegir(); return null; })},
      child: GestureDetector(
        onTap: widget.alElegir,
        child: AnimatedScale(
          scale: _enfocado ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 250,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colores.superficie,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _enfocado ? Colores.acento : Colors.transparent, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: p.portada == null
                    ? const ColoredBox(color: Color(0xFF1E293B))
                    : Image.network(p.portada!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1E293B))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Text(p.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colores.texto)),
              ),
              if (p.duracionMin != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                  child: Text('${p.duracionMin} min', style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
