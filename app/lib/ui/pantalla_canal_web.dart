import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Muestra una página de SandyTV dentro de la app (hoy: el canal propio de pesca, con su grilla y sus espacios
/// auspiciados). Es la misma página del Philips, así que lo que se cambie ahí llega solo al Noblex.
/// Atrás: primero cierra lo que la página tenga abierto (la grilla) y recién después vuelve al Inicio.
class PantallaCanalWeb extends StatefulWidget {
  const PantallaCanalWeb({super.key, required this.url});
  final Uri url;

  @override
  State<PantallaCanalWeb> createState() => _PantallaCanalWebState();
}

class _PantallaCanalWebState extends State<PantallaCanalWeb> {
  late final WebViewController _web;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        if (mounted) setState(() => _cargando = false);
      }));
    final plataforma = _web.platform;
    if (plataforma is AndroidWebViewController) {
      // Sin esto, el video de YouTube no arranca solo (pide un toque en la pantalla).
      plataforma.setMediaPlaybackRequiresUserGesture(false);
    }
    _web.loadRequest(widget.url);
  }

  Future<void> _atras() async {
    var cerroAlgo = false;
    try {
      final r = await _web.runJavaScriptReturningResult('window.__atras ? window.__atras() : false');
      cerroAlgo = r.toString() == 'true';
    } catch (_) {}
    if (!cerroAlgo && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (volvio, _) {
        if (!volvio) _atras();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          WebViewWidget(controller: _web),
          if (_cargando) const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }
}
