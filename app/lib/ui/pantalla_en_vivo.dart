import 'package:flutter/material.dart';

import '../modelos/en_vivo.dart';
import '../servicios/estado_app.dart';
import 'dialogos.dart';
import 'tema.dart';

/// Canales que transmiten en vivo por YouTube (los que elegís vos). Al elegir uno se abre su transmisión con la
/// app oficial de YouTube del televisor; Atrás vuelve a este menú. Con el editor se agregan, cambian y borran.
class PantallaEnVivo extends StatefulWidget {
  const PantallaEnVivo({super.key, required this.estado});
  final EstadoApp estado;

  @override
  State<PantallaEnVivo> createState() => _PantallaEnVivoState();
}

class _PantallaEnVivoState extends State<PantallaEnVivo> {
  bool _editando = false;
  EstadoApp get _e => widget.estado;

  Future<void> _ver(CanalEnVivo c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _e.abrirVideo(c.url);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo abrir YouTube. Fijate que la app de YouTube esté instalada en el televisor.'),
      ));
    }
  }

  Future<void> _opciones(CanalEnVivo c) async {
    if (!c.propio) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este canal viene con la app y no se puede cambiar.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colores.superficie,
        title: Text(c.titulo),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final t = await pedirTexto(context, titulo: 'Título del canal', inicial: c.titulo);
              if (t != null && t.trim().isNotEmpty) {
                c.titulo = t.trim();
                await _e.cambioEnVivo();
              }
            },
            child: const Text('Cambiar el título', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final g = await _elegirGrupo(c.grupo);
              if (g != null) {
                c.grupo = g;
                await _e.cambioEnVivo();
              }
            },
            child: const Text('Cambiar de grupo', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              if (await confirmar(context, '¿Borrar "${c.titulo}"?', si: 'Borrar')) {
                _e.borrarEnVivo(c.id);
                await _e.cambioEnVivo();
              }
            },
            child: const Text('Borrar el canal', style: TextStyle(fontSize: 18, color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
  }

  Future<String?> _elegirGrupo(String actual) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colores.superficie,
        title: const Text('¿En qué grupo va?'),
        children: [
          for (final g in _e.enVivo.grupos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g.id),
              child: Text('${g.id == actual ? '✓  ' : '     '}${g.nombre}', style: const TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
  }

  Future<void> _agregar() async {
    final grupos = _e.enVivo.grupos;
    final titulo = TextEditingController();
    final direccion = TextEditingController();
    var grupo = grupos.first.id;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colores.superficie,
          title: const Text('Agregar un canal de YouTube en vivo'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: titulo, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: 'Título del canal')),
                TextField(
                  controller: direccion,
                  decoration: const InputDecoration(
                    labelText: 'Dirección del vivo de YouTube',
                    helperText: 'Pegá la del canal (youtube.com/@canal) o la de la transmisión; se completa solo.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Grupo', style: TextStyle(color: Colores.textoSuave)),
                Wrap(spacing: 8, children: [
                  for (final g in grupos)
                    ChoiceChip(label: Text(g.nombre), selected: grupo == g.id, onSelected: (_) => setLocal(() => grupo = g.id)),
                ]),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Color(0xFFF87171)))),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final url = normalizarUrlYoutube(direccion.text);
                if (titulo.text.trim().isEmpty) {
                  setLocal(() => error = 'Poné un título para el canal.');
                } else if (url == null) {
                  setLocal(() => error = 'Eso no es una dirección de YouTube. Tiene que empezar con youtube.com o youtu.be.');
                } else {
                  _e.agregarEnVivo(titulo: titulo.text, url: url, grupo: grupo);
                  await _e.cambioEnVivo();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    // Los controladores no se liberan a mano: el diálogo todavía los usa mientras se cierra (la animación de salida).
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _e,
        builder: (context, _) {
          final catalogo = _e.enVivo;
          final grupos = catalogo.gruposConCanales;
          return ListView(
            cacheExtent: 900,
            padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
            children: [
              const LogoSandyTv(tam: 30),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: Text('En vivo (YouTube)', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800))),
                FilledButton.tonal(autofocus: grupos.isEmpty, onPressed: _agregar, child: const Text('＋ Agregar canal')),
                const SizedBox(width: 10),
                FilledButton.tonal(onPressed: () => setState(() => _editando = !_editando), child: Text(_editando ? '✔ Listo' : '✎ Editar')),
              ]),
              const SizedBox(height: 4),
              Text(_editando ? 'Modo editar: elegí un canal para cambiarlo o borrarlo.' : 'Elegí un canal con OK. Atrás te trae de vuelta acá.',
                  style: const TextStyle(fontSize: 16, color: Colores.textoSuave)),
              if (grupos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Todavía no cargaste ningún canal. Tocá "＋ Agregar canal" y pegá la dirección del vivo de YouTube de los canales que te interesan.',
                    style: TextStyle(fontSize: 20, color: Colores.texto),
                  ),
                ),
              for (final g in grupos) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24, left: 8),
                  child: Text(g.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  height: 230,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: catalogo.delGrupo(g.id).length,
                    itemBuilder: (_, i) {
                      final c = catalogo.delGrupo(g.id)[i];
                      return _TileEnVivo(
                        canal: c,
                        editando: _editando,
                        alElegir: () => _editando ? _opciones(c) : _ver(c),
                        autofocus: g == grupos.first && i == 0,
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TileEnVivo extends StatefulWidget {
  const _TileEnVivo({required this.canal, required this.alElegir, this.autofocus = false, this.editando = false});
  final CanalEnVivo canal;
  final VoidCallback alElegir;
  final bool autofocus;
  final bool editando;

  @override
  State<_TileEnVivo> createState() => _TileEnVivoState();
}

class _TileEnVivoState extends State<_TileEnVivo> {
  bool _enfocado = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.canal;
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
            width: 240,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colores.superficie,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _enfocado ? Colores.acento : (widget.editando && c.propio ? const Color(0xFFFACC15) : Colors.transparent), width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  if (c.portada != null)
                    Image.network(c.portada!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1E293B)))
                  else
                    const ColoredBox(color: Color(0xFF1E293B)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(6)),
                      child: const Text('EN VIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Text(c.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colores.texto)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
