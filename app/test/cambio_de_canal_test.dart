import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/modelos/cartelera.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/motor_video.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_canal.dart';
import 'package:video_player/video_player.dart';

import 'cartelera_test.dart' show canalJson;

/// Motor de mentira: cada enlace puede tardar y andar o no, sin tocar ningún reproductor real.
class MotorDePrueba extends MotorPantalla {
  MotorDePrueba(this.reglas);

  /// url -> (cuánto tarda, si anda)
  final Map<String, (Duration, bool)> reglas;
  final abiertos = <String>[];
  @override
  final ValueNotifier<VideoPlayerController?> actual = ValueNotifier(null);

  @override
  Future<void> abrir(Enlace e, {required Duration timeout}) async {
    final (demora, anda) = reglas[e.url] ?? (Duration.zero, false);
    await Future<void>.delayed(demora);
    if (!anda) throw Exception('falla de prueba');
    abiertos.add(e.url);
  }

  @override
  Future<void> soltar() async {}

  @override
  Future<void> dispose() async {}
}

Future<EstadoApp> estadoCon3Canales() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final texto = jsonEncode({
    'formato': 1,
    'version': 'test',
    'categorias': [
      {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1}
    ],
    'canales': [canalJson('A.ar', 1), canalJson('B.ar', 2), canalJson('C.ar', 3)],
  });
  final repo = RepositorioCartelera(
    almacen: AlmacenPrefs(prefs),
    url: Uri.parse('https://x/c.json'),
    descargar: (_) async => throw Exception('sin internet'),
    cargarInicial: () async => texto,
  );
  final estado = EstadoApp(repo: repo, prefs: prefs, actualizacionAutomatica: false);
  await estado.iniciar();
  return estado;
}

Widget pantalla(EstadoApp estado, MotorDePrueba motor) => MaterialApp(
      home: PantallaCanal(
        estado: estado,
        canalInicial: estado.cartelera!.canales.first,
        crearMotor: () => motor,
        timeoutApertura: const Duration(seconds: 5),
      ),
    );

const urlA = 'http://a/A.ar.m3u8';
const urlB = 'http://a/B.ar.m3u8';
const urlC = 'http://a/C.ar.m3u8';

void main() {
  testWidgets('al cambiar de canal no aparece la pantalla de espera: el canal sigue y la barra avisa', (t) async {
    final estado = await estadoCon3Canales();
    final motor = MotorDePrueba({
      urlA: (Duration.zero, true),
      urlB: (const Duration(milliseconds: 600), true),
    });
    await t.pumpWidget(pantalla(estado, motor));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('1  A.ar'), findsOneWidget, reason: 'barra del canal que arrancó');

    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Conectando…'), findsNothing, reason: 'no hay pantalla entera de espera');
    expect(find.text('Este canal no está disponible ahora'), findsNothing);
    expect(find.text('2  B.ar'), findsOneWidget, reason: 'la barra ya muestra el canal nuevo');
    expect(find.text('Sintonizando…'), findsOneWidget);

    await t.pump(const Duration(seconds: 1));
    expect(find.text('Sintonizando…'), findsNothing);
    expect(find.text('2  B.ar'), findsOneWidget);
    expect(estado.ultimoCanalId, 'B.ar');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('si el canal nuevo no anda, el anterior sigue y se avisa abajo', (t) async {
    final estado = await estadoCon3Canales();
    final motor = MotorDePrueba({
      urlA: (Duration.zero, true),
      urlB: (const Duration(milliseconds: 300), false),
      urlC: (Duration.zero, true),
    });
    await t.pumpWidget(pantalla(estado, motor));
    await t.pump(const Duration(milliseconds: 100));

    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Canal 2 no disponible'), findsOneWidget);
    expect(find.text('Este canal no está disponible ahora'), findsNothing, reason: 'no se corta lo que se estaba mirando');
    expect(estado.ultimoCanalId, 'A.ar', reason: 'el último canal visto sigue siendo el que anda');

    // otra vez ↑: sigue desde el canal que se intentó (el 2), no se queda trabado en él
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('3  C.ar'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('si recién se abre y no anda, sí se muestra la pantalla entera con el motivo', (t) async {
    final estado = await estadoCon3Canales();
    final motor = MotorDePrueba({});
    await t.pumpWidget(pantalla(estado, motor));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Este canal no está disponible ahora'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('varios cambios seguidos: gana el último', (t) async {
    final estado = await estadoCon3Canales();
    final motor = MotorDePrueba({
      urlA: (Duration.zero, true),
      urlB: (const Duration(milliseconds: 800), true),
      urlC: (const Duration(milliseconds: 100), true),
    });
    await t.pumpWidget(pantalla(estado, motor));
    await t.pump(const Duration(milliseconds: 100));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 50));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('3  C.ar'), findsOneWidget);
    expect(estado.ultimoCanalId, 'C.ar');
    await t.pump(const Duration(seconds: 6));
  });
}
