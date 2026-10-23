import 'package:flutter/material.dart';

import '../modelos/cartelera.dart';
import '../servicios/estado_app.dart';
import 'tema.dart';

/// Pide un texto (por ejemplo el título de una lista). En el televisor se escribe con el teclado en pantalla.
Future<String?> pedirTexto(BuildContext context, {required String titulo, String inicial = '', String ayuda = ''}) {
  final controlador = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colores.superficie,
      title: Text(titulo),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: controlador,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(hintText: ayuda),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, controlador.text), child: const Text('Aceptar')),
      ],
    ),
  );
}

Future<bool> confirmar(BuildContext context, String pregunta, {String si = 'Borrar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colores.superficie,
      title: Text(pregunta),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(si)),
      ],
    ),
  );
  return r ?? false;
}

/// Elegir con qué lista se mira ("Todos los canales" o una lista).
Future<void> elegirListaActiva(BuildContext context, EstadoApp estado) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: Colores.superficie,
      title: const Text('¿Qué querés ver?'),
      children: [
        SimpleDialogOption(
          onPressed: () {
            estado.activarLista(null);
            Navigator.pop(ctx);
          },
          child: Text('${estado.listaActivaId == null ? '✓  ' : '     '}Todos los canales', style: const TextStyle(fontSize: 18)),
        ),
        for (final l in estado.listas.listas)
          SimpleDialogOption(
            onPressed: () {
              estado.activarLista(l.id);
              Navigator.pop(ctx);
            },
            child: Text('${estado.listaActivaId == l.id ? '✓  ' : '     '}${l.titulo}  (${l.canales.length})',
                style: const TextStyle(fontSize: 18)),
          ),
      ],
    ),
  );
}

/// Agregar o quitar un canal de las listas (tecla verde dentro de un canal).
Future<void> dialogoFavorito(BuildContext context, EstadoApp estado, Canal canal) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: estado,
      builder: (_, _) => AlertDialog(
        backgroundColor: Colores.superficie,
        title: Text('Agregar ${canal.nombre} a una lista'),
        content: SizedBox(
          width: 480,
          child: ListView(shrinkWrap: true, children: [
            for (final l in estado.listas.listas)
              CheckboxListTile(
                autofocus: l == estado.listas.listas.first,
                title: Text(l.titulo),
                subtitle: Text('${l.canales.length} canales'),
                value: l.canales.contains(canal.id),
                onChanged: (v) {
                  if (v == true) {
                    estado.listas.agregar(l.id, canal.id);
                  } else {
                    estado.listas.quitar(l.id, canal.id);
                  }
                  estado.cambioEnListas();
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Nueva lista…'),
              onTap: () async {
                final t = await pedirTexto(ctx, titulo: 'Título de la lista nueva', ayuda: 'Por ejemplo: Familia');
                if (t == null) return;
                final nueva = estado.crearLista(t);
                estado.listas.agregar(nueva.id, canal.id);
                await estado.cambioEnListas();
              },
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo'))],
      ),
    ),
  );
}
