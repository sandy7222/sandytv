import 'package:flutter/material.dart';

import '../logica/listas_favoritos.dart';
import '../modelos/cartelera.dart';
import '../servicios/estado_app.dart';
import 'tema.dart';

/// Elegir los canales de una lista (recorriendo las categorías) y ordenarlos.
class PantallaEditarLista extends StatefulWidget {
  const PantallaEditarLista({super.key, required this.estado, required this.listaId});
  final EstadoApp estado;
  final String listaId;

  @override
  State<PantallaEditarLista> createState() => _PantallaEditarListaState();
}

class _PantallaEditarListaState extends State<PantallaEditarLista> {
  bool _ordenando = false;
  String _busqueda = '';

  EstadoApp get _e => widget.estado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _e,
        builder: (context, _) {
          final lista = _e.listas.porId(widget.listaId);
          final cartelera = _e.cartelera;
          if (lista == null || cartelera == null) return const Center(child: Text('Esta lista ya no existe.'));
          return Padding(
            padding: const EdgeInsets.fromLTRB(60, 28, 60, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const LogoSandyTv(tam: 24),
                const SizedBox(width: 24),
                Expanded(child: Text(lista.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
                Text('${lista.canales.length} canales', style: const TextStyle(fontSize: 16, color: Colores.textoSuave)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton.tonal(
                  autofocus: true,
                  onPressed: () => setState(() => _ordenando = false),
                  child: Text(_ordenando ? 'Elegir canales' : '● Elegir canales'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: () => setState(() => _ordenando = true),
                  child: Text(_ordenando ? '● Ordenar' : 'Ordenar'),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(child: _ordenando ? _ordenar(lista, cartelera) : _elegir(lista, cartelera)),
            ]),
          );
        },
      ),
    );
  }

  Widget _elegir(ListaFav lista, Cartelera cartelera) {
    final q = _busqueda.trim().toLowerCase();
    final filas = <Object>[]; // String = encabezado de categoría, Canal = un canal
    for (final g in cartelera.gruposConCanales) {
      final canales = cartelera.canalesDe(g.id).where((c) => q.isEmpty || c.nombre.toLowerCase().contains(q)).toList();
      if (canales.isEmpty) continue;
      filas.add(g.nombre);
      filas.addAll(canales);
    }
    return Column(children: [
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar un canal por nombre'),
        onChanged: (v) => setState(() => _busqueda = v),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: filas.length,
          itemBuilder: (_, i) {
            final f = filas[i];
            if (f is String) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(f, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colores.acento)),
              );
            }
            final canal = f as Canal;
            return CheckboxListTile(
              title: Text(canal.nombre),
              subtitle: Text('Canal ${canal.numero}${canal.paisNombre != null ? ' · ${canal.paisNombre}' : ''}'),
              value: lista.canales.contains(canal.id),
              onChanged: (v) {
                if (v == true) {
                  _e.listas.agregar(lista.id, canal.id);
                } else {
                  _e.listas.quitar(lista.id, canal.id);
                }
                _e.cambioEnListas();
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _ordenar(ListaFav lista, Cartelera cartelera) {
    final entradas = _e.listas.resolver(lista.id, cartelera);
    return ListView(children: [
      SwitchListTile(
        title: const Text('Mostrar agrupada por categoría'),
        subtitle: const Text('Si está apagado, se ve una sola fila en el orden de abajo.'),
        value: lista.agrupar,
        onChanged: (v) {
          lista.agrupar = v;
          _e.cambioEnListas();
        },
      ),
      if (entradas.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Text('La lista está vacía. Elegí canales en "Elegir canales".', style: TextStyle(fontSize: 18))),
      for (var i = 0; i < entradas.length; i++)
        ListTile(
          title: Text('${i + 1}.  ${entradas[i].canal?.nombre ?? entradas[i].id}', style: TextStyle(color: entradas[i].canal == null ? Colores.textoSuave : null)),
          subtitle: entradas[i].canal == null ? const Text('Ya no está en la cartelera') : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Subir', icon: const Icon(Icons.arrow_upward), onPressed: i == 0 ? null : () { _e.listas.mover(lista.id, i, i - 1); _e.cambioEnListas(); }),
            IconButton(tooltip: 'Bajar', icon: const Icon(Icons.arrow_downward), onPressed: i == entradas.length - 1 ? null : () { _e.listas.mover(lista.id, i, i + 1); _e.cambioEnListas(); }),
            IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close), onPressed: () { _e.listas.quitar(lista.id, entradas[i].id); _e.cambioEnListas(); }),
          ]),
        ),
    ]);
  }
}
