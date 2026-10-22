import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logica/teclas.dart';
import '../modelos/formato_imagen.dart';
import '../servicios/estado_app.dart';
import 'tema.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key, required this.estado});
  final EstadoApp estado;

  static String _descripcion(FormatoImagen f) => switch (f) {
        FormatoImagen.original => 'Original (respeta la proporción del canal)',
        FormatoImagen.estirar => 'Estirado a pantalla completa 16:9',
        FormatoImagen.zoom => 'Zoom (agranda y recorta arriba y abajo)',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: estado,
        builder: (context, _) {
          final c = estado.cartelera;
          return ListView(padding: const EdgeInsets.fromLTRB(60, 32, 60, 32), children: [
            const LogoSandyTv(tam: 26),
            const SizedBox(height: 20),
            const Text('Ajustes', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            SwitchListTile(
              autofocus: true,
              title: const Text('Al abrir, retomar el último canal'),
              subtitle: const Text('Si está apagado, SandyTV abre en el Inicio.'),
              value: estado.retomarAlAbrir,
              onChanged: estado.cambiarRetomar,
            ),
            ListTile(
              title: const Text('Formato de imagen por defecto'),
              subtitle: Text('${_descripcion(estado.formatoDefecto)}. Se cambia canal por canal con el botón azul del control.'),
              onTap: () => estado.cambiarFormatoDefecto(estado.formatoDefecto.siguiente),
            ),
            ListTile(
              title: const Text('Buscar cartelera nueva ahora'),
              subtitle: Text(estado.actualizando
                  ? 'Buscando…'
                  : c == null ? 'Sin cartelera' : '${c.canales.length} canales · versión ${c.version}'),
              onTap: estado.actualizando ? null : () async {
                final messenger = ScaffoldMessenger.of(context);
                final hubo = await estado.refrescar();
                messenger.showSnackBar(SnackBar(content: Text(hubo ? 'Cartelera actualizada' : 'Ya tenés la más nueva')));
              },
            ),
            ListTile(
              title: const Text('Probar las teclas del control'),
              subtitle: const Text('Muestra qué tecla manda tu control remoto.'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaTeclas())),
            ),
          ]);
        },
      ),
    );
  }
}

/// Muestra la última tecla apretada, para saber qué manda cada control remoto.
class PantallaTeclas extends StatefulWidget {
  const PantallaTeclas({super.key});
  @override
  State<PantallaTeclas> createState() => _PantallaTeclasState();
}

class _PantallaTeclasState extends State<PantallaTeclas> {
  String _ultima = 'Apretá una tecla del control';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent) return KeyEventResult.handled;
          final t = mapearTecla(e.logicalKey);
          // Atrás siempre sale: esta pantalla se queda con todas las teclas, así que lo resuelve acá.
          if (t.accion == Accion.atras) {
            Navigator.of(context).maybePop();
            return KeyEventResult.handled;
          }
          setState(() => _ultima =
              'Tecla: ${e.logicalKey.keyLabel.isEmpty ? e.logicalKey.debugName : e.logicalKey.keyLabel}\nCódigo: ${e.logicalKey.keyId}\nSandyTV la usa para: ${t.accion.name}');
          return KeyEventResult.handled;
        },
        child: Stack(children: [
          Center(child: Text(_ultima, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30))),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Text('Para salir apretá Atrás', style: TextStyle(fontSize: 18, color: Colores.textoSuave)),
            ),
          ),
        ]),
      ),
    );
  }
}
