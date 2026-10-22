import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/logica/marcado_numerico.dart';
import 'package:sandytv/logica/navegacion.dart';
import 'package:sandytv/modelos/cartelera.dart';

Canal canal(String id, int numero) => Canal(
      id: id, numero: numero, nombre: id, emisora: null, pais: 'AR', paisNombre: null,
      categoria: 'argentina', logo: null, web: null, forzado: false,
      enlaces: [Enlace(url: 'http://a/$id', alto: 720, kbps: null, puntaje: 90, userAgent: null, referrer: null)],
    );

void main() {
  final lista = [canal('A', 1), canal('B', 2), canal('C', 5)];

  group('cambio de canal', () {
    test('siguiente y anterior', () {
      expect(canalSiguiente(lista, 'A')!.id, 'B');
      expect(canalAnterior(lista, 'C')!.id, 'B');
    });

    test('del último pasa al primero y del primero al último', () {
      expect(canalSiguiente(lista, 'C')!.id, 'A');
      expect(canalAnterior(lista, 'A')!.id, 'C');
    });

    test('si el canal actual no está en la lista, arranca por el primero', () {
      expect(canalSiguiente(lista, 'X')!.id, 'A');
      expect(canalAnterior(lista, 'X')!.id, 'A');
    });

    test('lista vacía devuelve null', () {
      expect(canalSiguiente([], 'A'), isNull);
      expect(canalAnterior([], 'A'), isNull);
    });

    test('por número', () {
      expect(canalPorNumero(lista, 5)!.id, 'C');
      expect(canalPorNumero(lista, 3), isNull);
    });
  });

  group('marcado por números', () {
    test('junta los dígitos y avisa al terminar la espera', () async {
      final terminados = <int>[];
      final m = MarcadoNumerico(espera: const Duration(milliseconds: 40), alTerminar: terminados.add);
      m.digito(1);
      m.digito(2);
      expect(m.actual, '12');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(terminados, [12]);
      expect(m.actual, '');
    });

    test('cada dígito nuevo reinicia la espera', () async {
      final terminados = <int>[];
      final m = MarcadoNumerico(espera: const Duration(milliseconds: 80), alTerminar: terminados.add);
      m.digito(3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      m.digito(4);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(terminados, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(terminados, [34]);
    });

    test('con el máximo de dígitos termina de inmediato', () {
      final terminados = <int>[];
      final m = MarcadoNumerico(espera: const Duration(seconds: 5), maxDigitos: 3, alTerminar: terminados.add);
      m.digito(1);
      m.digito(2);
      m.digito(3);
      expect(terminados, [123]);
    });

    test('cancelar descarta lo marcado', () async {
      final terminados = <int>[];
      final m = MarcadoNumerico(espera: const Duration(milliseconds: 30), alTerminar: terminados.add);
      m.digito(7);
      m.cancelar();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(terminados, isEmpty);
      expect(m.actual, '');
    });
  });
}
