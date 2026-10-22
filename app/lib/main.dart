import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'servicios/estado_app.dart';
import 'servicios/repositorio_cartelera.dart';
import 'ui/pantalla_presentacion.dart';
import 'ui/tema.dart';

const urlCartelera = 'https://sandy7222.github.io/sandytv/cartelera.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final prefs = await SharedPreferences.getInstance();
  final repo = RepositorioCartelera(
    almacen: AlmacenPrefs(prefs),
    url: Uri.parse(urlCartelera),
    descargar: (url) async {
      final r = await http.get(url).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw Exception('respuesta ${r.statusCode}');
      return utf8.decode(r.bodyBytes);
    },
    cargarInicial: () => rootBundle.loadString('assets/cartelera_inicial.json'),
  );
  runApp(SandyTvApp(estado: EstadoApp(repo: repo, prefs: prefs)));
}

class SandyTvApp extends StatelessWidget {
  const SandyTvApp({super.key, required this.estado});
  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SandyTV',
      debugShowCheckedModeBanner: false,
      theme: temaSandyTv(),
      home: PantallaPresentacion(estado: estado),
    );
  }
}
