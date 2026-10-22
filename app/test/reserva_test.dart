import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/logica/apertura.dart';
import 'package:sandytv/logica/salud_enlaces.dart';
import 'package:sandytv/modelos/cartelera.dart';

Enlace enlace(String url, int puntaje) =>
    Enlace(url: url, alto: 720, kbps: null, puntaje: puntaje, userAgent: null, referrer: null);

Canal canal(String id, List<Enlace> enlaces) => Canal(
      id: id, numero: 1, nombre: id, emisora: null, pais: 'AR', paisNombre: null,
      categoria: 'argentina', logo: null, web: null, forzado: false, enlaces: enlaces,
    );

class MotorFalso implements MotorVideo {
  MotorFalso(this.funcionan);
  final Set<String> funcionan;
  final intentos = <String>[];
  @override
  Future<void> abrir(Enlace e, {required Duration timeout}) async {
    intentos.add(e.url);
    if (!funcionan.contains(e.url)) throw Exception('falla');
  }
}

class MotorCancelador implements MotorVideo {
  MotorCancelador(this.alAbrir);
  final void Function() alAbrir;
  final intentos = <String>[];
  @override
  Future<void> abrir(Enlace e, {required Duration timeout}) async {
    intentos.add(e.url);
    alAbrir();
    throw Exception('cancelado');
  }
}

class MotorLento implements MotorVideo {
  @override
  Future<void> abrir(Enlace e, {required Duration timeout}) => throw TimeoutException('x', timeout);
}

void main() {
  group('salud de enlaces', () {
    test('ordena primero los que no fallaron y después por puntaje', () {
      final s = SaludEnlaces();
      final c = canal('A', [enlace('u1', 100), enlace('u2', 80), enlace('u3', 60)]);
      s.registrarFallo('u1');
      expect(s.ordenar(c).map((e) => e.url), ['u2', 'u3', 'u1']);
    });

    test('un éxito borra los fallos', () {
      final s = SaludEnlaces();
      s.registrarFallo('u1');
      s.registrarFallo('u1');
      s.registrarExito('u1');
      expect(s.fallosDe('u1'), 0);
    });

    test('un canal con todos los enlaces con 3 fallos seguidos es "con fallas"', () {
      final s = SaludEnlaces();
      final c = canal('A', [enlace('u1', 90), enlace('u2', 80)]);
      for (var i = 0; i < 3; i++) {
        s.registrarFallo('u1');
      }
      expect(s.canalConFallas(c), isFalse);
      for (var i = 0; i < 3; i++) {
        s.registrarFallo('u2');
      }
      expect(s.canalConFallas(c), isTrue);
    });

    test('se guarda y se recupera como texto', () {
      final s = SaludEnlaces();
      s.registrarFallo('u1');
      s.registrarFallo('u1');
      final otra = SaludEnlaces.desdeTexto(s.comoTexto());
      expect(otra.fallosDe('u1'), 2);
    });

    test('un texto roto da una salud vacía', () {
      expect(SaludEnlaces.desdeTexto('basura').fallosDe('u1'), 0);
      expect(SaludEnlaces.desdeTexto(null).fallosDe('u1'), 0);
    });
  });

  group('abrir con enlace de reserva', () {
    test('usa el primer enlace si anda', () async {
      final motor = MotorFalso({'u1', 'u2'});
      final r = await abrirConReserva(canal('A', [enlace('u1', 90), enlace('u2', 80)]), motor, SaludEnlaces(), timeout: const Duration(seconds: 1));
      expect(r.enlace!.url, 'u1');
      expect(motor.intentos, ['u1']);
    });

    test('si el primero falla pasa al de reserva y anota el fallo', () async {
      final motor = MotorFalso({'u2'});
      final salud = SaludEnlaces();
      final r = await abrirConReserva(canal('A', [enlace('u1', 90), enlace('u2', 80)]), motor, salud, timeout: const Duration(seconds: 1));
      expect(r.enlace!.url, 'u2');
      expect(salud.fallosDe('u1'), 1);
      expect(salud.fallosDe('u2'), 0);
    });

    test('si fallan todos devuelve sin enlace (nunca queda colgado)', () async {
      final motor = MotorFalso({});
      final r = await abrirConReserva(canal('A', [enlace('u1', 90), enlace('u2', 80)]), motor, SaludEnlaces(), timeout: const Duration(seconds: 1));
      expect(r.ok, isFalse);
      expect(motor.intentos.length, 2);
    });

    test('si fallan todos, guarda el motivo de cada enlace para mostrarlo', () async {
      final motor = MotorFalso({});
      final r = await abrirConReserva(
          canal('A', [enlace('http://uno.com/a.m3u8', 90), enlace('http://dos.com/b.m3u8', 80)]), motor, SaludEnlaces(),
          timeout: const Duration(seconds: 1));
      expect(r.errores.length, 2);
      expect(r.errores.first, startsWith('uno.com: '));
      expect(r.errores.first, contains('falla'));
    });

    test('un enlace que no arranca a tiempo lo dice con claridad', () async {
      final r = await abrirConReserva(canal('A', [enlace('http://lento.com/a.m3u8', 90)]), MotorLento(), SaludEnlaces(),
          timeout: const Duration(seconds: 3));
      expect(r.errores.single, 'lento.com: no arrancó en 3 s');
    });

    test('si se cancela mientras se prueba, no se anota como fallo del enlace', () async {
      final salud = SaludEnlaces();
      var cancelar = false;
      final motor = MotorCancelador(() => cancelar = true);
      final r = await abrirConReserva(canal('A', [enlace('u1', 90), enlace('u2', 80)]), motor, salud,
          timeout: const Duration(seconds: 1), cancelado: () => cancelar);
      expect(r.ok, isFalse);
      expect(salud.fallosDe('u1'), 0);
      expect(motor.intentos, ['u1'], reason: 'no sigue con el de reserva');
    });

    test('la próxima vez prueba primero el enlace que anduvo', () async {
      final salud = SaludEnlaces();
      final c = canal('A', [enlace('u1', 90), enlace('u2', 80)]);
      await abrirConReserva(c, MotorFalso({'u2'}), salud, timeout: const Duration(seconds: 1));
      final motor2 = MotorFalso({'u1', 'u2'});
      await abrirConReserva(c, motor2, salud, timeout: const Duration(seconds: 1));
      expect(motor2.intentos.first, 'u2');
    });
  });
}
