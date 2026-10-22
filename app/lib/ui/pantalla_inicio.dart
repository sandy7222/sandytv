import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelos/cartelera.dart';
import '../servicios/estado_app.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_canal.dart';
import 'tema.dart';
import 'tile_canal.dart';

/// Inicio de SandyTV: acá no hay video. El reproductor arranca recién al elegir un canal.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key, required this.estado});
  final EstadoApp estado;

  void _abrirCanal(BuildContext context, Canal c) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaCanal(estado: estado, canalInicial: c)));
  }

  Future<void> _confirmarSalida(BuildContext context) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colores.superficie,
        title: const Text('¿Salir de SandyTV?'),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Quedarme')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
        ],
      ),
    );
    if (salir == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida(context);
      },
      child: Scaffold(
        body: ListenableBuilder(
          listenable: estado,
          builder: (context, _) {
            final cartelera = estado.cartelera;
            if (cartelera == null) return const Center(child: Text('Sin cartelera todavía.'));
            final destacado = estado.ultimoCanal ?? _canalDestacado(cartelera);
            final seguir = estado.ultimoCanal;
            return ListView(
              cacheExtent: 900,
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
              children: [
                Row(children: [
                  const LogoSandyTv(tam: 30),
                  const Spacer(),
                  _BotonMenu(alElegir: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaAjustes(estado: estado)))),
                ]),
                const SizedBox(height: 20),
                if (destacado != null)
                  _Destacado(canal: destacado, titulo: seguir != null ? 'Seguir viendo' : 'Para empezar', alElegir: () => _abrirCanal(context, destacado)),
                for (final g in cartelera.gruposConCanales) _Fila(
                  titulo: g.nombre,
                  canales: _ordenadas(cartelera.canalesDe(g.id)),
                  estado: estado,
                  alElegir: (c) => _abrirCanal(context, c),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Los canales cuyos enlaces fallaron todos varias veces seguidas pasan al final de su fila.
  List<Canal> _ordenadas(List<Canal> canales) {
    final buenos = canales.where((c) => !estado.salud.canalConFallas(c)).toList();
    final malos = canales.where((c) => estado.salud.canalConFallas(c)).toList();
    return [...buenos, ...malos];
  }

  Canal? _canalDestacado(Cartelera c) {
    final ar = c.canalesDe('argentina');
    if (ar.isNotEmpty) return ar.first;
    return c.canales.isEmpty ? null : c.canales.first;
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.titulo, required this.canales, required this.estado, required this.alElegir});
  final String titulo;
  final List<Canal> canales;
  final EstadoApp estado;
  final void Function(Canal) alElegir;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 22, left: 8),
        child: Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colores.texto)),
      ),
      SizedBox(
        height: 170,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: canales.length,
          itemBuilder: (_, i) => TileCanal(
            canal: canales[i],
            alElegir: () => alElegir(canales[i]),
            atenuado: estado.salud.canalConFallas(canales[i]),
          ),
        ),
      ),
    ]);
  }
}

class _Destacado extends StatefulWidget {
  const _Destacado({required this.canal, required this.titulo, required this.alElegir});
  final Canal canal;
  final String titulo;
  final VoidCallback alElegir;

  @override
  State<_Destacado> createState() => _DestacadoState();
}

class _DestacadoState extends State<_Destacado> {
  bool _enfocado = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.canal;
    return FocusableActionDetector(
      autofocus: true,
      onShowFocusHighlight: (v) => setState(() => _enfocado = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.alElegir(); return null; })},
      child: GestureDetector(
        onTap: widget.alElegir,
        child: Container(
          height: 220,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF16233F), Color(0xFF0F3A4A)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _enfocado ? Colores.acento : Colors.transparent, width: 4),
          ),
          child: Row(children: [
            SizedBox(width: 180, child: LogoCanal(url: c.logo, nombre: c.nombre, alto: 110)),
            const SizedBox(width: 32),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(widget.titulo.toUpperCase(), style: const TextStyle(fontSize: 14, letterSpacing: 2, color: Colores.acento, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(c.nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colores.texto)),
                Text('Canal ${c.numero}${c.paisNombre != null ? ' · ${c.paisNombre}' : ''}',
                    style: const TextStyle(fontSize: 16, color: Colores.textoSuave)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(color: Colores.acento, borderRadius: BorderRadius.circular(24)),
                  child: const Text('▶  Ver ahora', style: TextStyle(color: Colores.fondo, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BotonMenu extends StatefulWidget {
  const _BotonMenu({required this.alElegir});
  final VoidCallback alElegir;
  @override
  State<_BotonMenu> createState() => _BotonMenuState();
}

class _BotonMenuState extends State<_BotonMenu> {
  bool _enfocado = false;
  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _enfocado = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.alElegir(); return null; })},
      child: GestureDetector(
        onTap: widget.alElegir,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _enfocado ? Colores.acento : Colores.textoSuave.withValues(alpha: 0.4), width: 2),
          ),
          child: const Text('⚙  Ajustes', style: TextStyle(color: Colores.texto, fontSize: 15)),
        ),
      ),
    );
  }
}
