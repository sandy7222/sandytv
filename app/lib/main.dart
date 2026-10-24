import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logica/reloj.dart';
import 'servicios/estado_app.dart';
import 'servicios/repositorio_cartelera.dart';
import 'ui/pantalla_presentacion.dart';
import 'ui/tema.dart';

const urlCartelera = 'https://sandy7222.github.io/sandytv/cartelera.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final prefs = await SharedPreferences.getInstance();
  final reloj = RelojArgentino();
  final repo = RepositorioCartelera(
    almacen: AlmacenPrefs(prefs),
    url: Uri.parse(urlCartelera),
    descargar: (url) async {
      final r = await http.get(url).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw Exception('respuesta ${r.statusCode}');
      // La respuesta de GitHub trae su hora exacta: sirve para corregir el reloj del televisor.
      final fecha = RelojArgentino.fechaDeEncabezado(r.headers['date']);
      if (fecha != null) reloj.sincronizar(fecha);
      return utf8.decode(r.bodyBytes);
    },
    cargarInicial: () => rootBundle.loadString('assets/cartelera_inicial.json'),
  );
  runApp(SandyTvApp(
    estado: EstadoApp(
      repo: repo,
      prefs: prefs,
      reloj: reloj,
      cargarPeliculas: () => rootBundle.loadString('assets/peliculas_inicial.json'),
      cargarEnVivo: () => rootBundle.loadString('assets/envivo_inicial.json'),
      // Las películas se abren con la app oficial de YouTube del televisor (con sus propias publicidades).
      abrirVideo: (url) async {
        try {
          return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          return false;
        }
      },
    ),
  ));
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
