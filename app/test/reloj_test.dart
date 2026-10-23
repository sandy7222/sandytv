import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/logica/reloj.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_ajustes.dart';
import 'package:sandytv/ui/pantalla_canal.dart';

import 'cambio_de_canal_test.dart' show MotorDePrueba, urlA;
import 'cartelera_test.dart' show canalJson;

void main() {
  group('hora de Argentina', () {
    test('es la hora UTC menos 3, sin importar la zona del televisor', () {
      final r = RelojArgentino(ahoraUtc: () => DateTime.utc(2026, 10, 22, 23, 10, 5));
      expect(r.hora(), '20:10');
      expect(r.ahoraArgentina().day, 22);
    });

    test('pasa de día a las 3 de la mañana UTC', () {
      final r = RelojArgentino(ahoraUtc: () => DateTime.utc(2026, 10, 23, 2, 59));
      expect(r.hora(), '23:59');
      expect(r.ahoraArgentina().day, 22);
      final r2 = RelojArgentino(ahoraUtc: () => DateTime.utc(2026, 10, 23, 3, 0));
      expect(r2.hora(), '00:00');
      expect(r2.ahoraArgentina().day, 23);
    });

    test('los minutos y las horas de un solo dígito llevan cero adelante', () {
      final r = RelojArgentino(ahoraUtc: () => DateTime.utc(2026, 10, 22, 11, 5));
      expect(r.hora(), '08:05');
    });
  });

  group('sincronización con la hora de GitHub', () {
    test('si el reloj del televisor está atrasado, se corrige con la hora del servidor', () {
      var ahora = DateTime.utc(2026, 10, 22, 20, 0, 0); // reloj del televisor: 20:00 UTC
      final r = RelojArgentino(ahoraUtc: () => ahora);
      expect(r.hora(), '17:00');
      r.sincronizar(DateTime.utc(2026, 10, 22, 23, 30, 0)); // el servidor dice 23:30 UTC → 20:30 en Argentina
      expect(r.hora(), '20:30');
      expect(r.sincronizado, isTrue);
      ahora = ahora.add(const Duration(minutes: 5)); // pasan 5 minutos en el televisor
      expect(r.hora(), '20:35', reason: 'sigue avanzando con el reloj del televisor, con la diferencia ya corregida');
    });

    test('sin sincronizar usa el reloj del televisor', () {
      final r = RelojArgentino(ahoraUtc: () => DateTime.utc(2026, 10, 22, 12, 0));
      expect(r.sincronizado, isFalse);
      expect(r.hora(), '09:00');
    });

    test('lee la fecha del encabezado HTTP de GitHub', () {
      final f = RelojArgentino.fechaDeEncabezado('Thu, 22 Oct 2026 23:10:05 GMT');
      expect(f, DateTime.utc(2026, 10, 22, 23, 10, 5));
    });

    test('un encabezado vacío o roto se ignora', () {
      expect(RelojArgentino.fechaDeEncabezado(null), isNull);
      expect(RelojArgentino.fechaDeEncabezado('mañana a la tarde'), isNull);
    });
  });

  group('reloj en pantalla', () {
    Future<EstadoApp> crear({bool mostrar = true}) async {
      SharedPreferences.setMockInitialValues({if (!mostrar) EstadoApp.claveReloj: false});
      final prefs = await SharedPreferences.getInstance();
      final texto = jsonEncode({
        'formato': 1,
        'version': 'test',
        'categorias': [
          {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1}
        ],
        'canales': [canalJson('A.ar', 1)],
      });
      final repo = RepositorioCartelera(
        almacen: AlmacenPrefs(prefs),
        url: Uri.parse('https://x/c.json'),
        descargar: (_) async => throw Exception('sin internet'),
        cargarInicial: () async => texto,
      );
      final e = EstadoApp(
        repo: repo,
        prefs: prefs,
        actualizacionAutomatica: false,
        reloj: RelojArgentino(ahoraUtc: () => DateTime.utc(2026, 10, 22, 23, 10)),
      );
      await e.iniciar();
      return e;
    }

    testWidgets('el reloj se ve abajo a la izquierda con la hora de Argentina', (t) async {
      final e = await crear();
      final motor = MotorDePrueba({urlA: (Duration.zero, true)});
      await t.pumpWidget(MaterialApp(
        home: PantallaCanal(estado: e, canalInicial: e.cartelera!.canales.first, crearMotor: () => motor, timeoutApertura: const Duration(seconds: 5)),
      ));
      await t.pump(const Duration(milliseconds: 100));
      final reloj = find.byKey(const Key('reloj'));
      expect(reloj, findsOneWidget);
      expect(find.text('20:10'), findsOneWidget);
      final pantalla = t.getSize(find.byType(Scaffold));
      final c = t.getRect(reloj).center;
      expect(c.dx, lessThan(pantalla.width * 0.3), reason: 'a la izquierda');
      expect(c.dy, greaterThan(pantalla.height * 0.8), reason: 'abajo');
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('si se oculta en Ajustes, no se ve', (t) async {
      final e = await crear(mostrar: false);
      final motor = MotorDePrueba({urlA: (Duration.zero, true)});
      await t.pumpWidget(MaterialApp(
        home: PantallaCanal(estado: e, canalInicial: e.cartelera!.canales.first, crearMotor: () => motor, timeoutApertura: const Duration(seconds: 5)),
      ));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('reloj')), findsNothing);
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('en Ajustes se muestra u oculta y se recuerda', (t) async {
      final e = await crear();
      expect(e.mostrarReloj, isTrue);
      await t.pumpWidget(MaterialApp(home: PantallaAjustes(estado: e)));
      await t.pump();
      await t.tap(find.text('Mostrar el reloj'));
      await t.pump();
      expect(e.mostrarReloj, isFalse);
      expect(e.prefs.getBool(EstadoApp.claveReloj), isFalse);
    });
  });
}
