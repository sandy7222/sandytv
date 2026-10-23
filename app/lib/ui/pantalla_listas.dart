import 'package:flutter/material.dart';

import '../logica/listas_favoritos.dart';
import '../servicios/estado_app.dart';
import 'dialogos.dart';
import 'pantalla_editar_lista.dart';
import 'tema.dart';

/// Todas las listas de favoritos: crear, renombrar, editar canales, fijar la de inicio y borrar.
class PantallaListas extends StatelessWidget {
  const PantallaListas({super.key, required this.estado});
  final EstadoApp estado;

  Future<void> _opciones(BuildContext context, ListaFav lista) async {
    final fijada = estado.listas.fijada == lista.id;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colores.superficie,
        title: Text(lista.titulo),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              estado.activarLista(lista.id);
              Navigator.of(context).maybePop();
            },
            child: const Text('Ver esta lista', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaEditarLista(estado: estado, listaId: lista.id)));
            },
            child: const Text('Elegir y ordenar canales', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final t = await pedirTexto(context, titulo: 'Título de la lista', inicial: lista.titulo);
              if (t != null && estado.listas.renombrar(lista.id, t)) await estado.cambioEnListas();
            },
            child: const Text('Cambiar el título', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              estado.fijarLista(fijada ? null : lista.id);
            },
            child: Text(fijada ? 'Dejar de abrir la app con esta lista' : 'Abrir la app siempre con esta lista', style: const TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              lista.agrupar = !lista.agrupar;
              estado.cambioEnListas();
            },
            child: Text(lista.agrupar ? 'Mostrar sin agrupar por categoría' : 'Mostrar agrupada por categoría', style: const TextStyle(fontSize: 18)),
          ),
          if (estado.listas.listas.length > 1)
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (await confirmar(context, '¿Borrar la lista "${lista.titulo}"?')) await estado.borrarLista(lista.id);
              },
              child: const Text('Borrar la lista', style: TextStyle(fontSize: 18, color: Color(0xFFF87171))),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: estado,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(60, 32, 60, 32), children: [
          const LogoSandyTv(tam: 26),
          const SizedBox(height: 20),
          const Text('Mis listas de favoritos', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Elegí una lista para verla, editarla o fijarla como la lista con la que se abre la app.',
              style: TextStyle(fontSize: 16, color: Colores.textoSuave)),
          const SizedBox(height: 16),
          for (final l in estado.listas.listas)
            ListTile(
              autofocus: l == estado.listas.listas.first,
              leading: Icon(estado.listas.fijada == l.id ? Icons.star : Icons.list_alt, color: Colores.acento),
              title: Text(l.titulo, style: const TextStyle(fontSize: 22)),
              subtitle: Text([
                '${l.canales.length} canales',
                if (l.agrupar) 'agrupada por categoría',
                if (estado.listas.fijada == l.id) 'se abre al iniciar',
                if (estado.listaActivaId == l.id) 'la que estás viendo',
              ].join(' · ')),
              onTap: () => _opciones(context, l),
            ),
          ListTile(
            leading: const Icon(Icons.add, color: Colores.acento),
            title: const Text('Nueva lista', style: TextStyle(fontSize: 20)),
            onTap: () async {
              final t = await pedirTexto(context, titulo: 'Título de la lista nueva', ayuda: 'Por ejemplo: Familia, Fútbol, Noticias');
              if (t == null) return;
              final nueva = estado.crearLista(t);
              if (context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaEditarLista(estado: estado, listaId: nueva.id)));
              }
            },
          ),
        ]),
      ),
    );
  }
}
