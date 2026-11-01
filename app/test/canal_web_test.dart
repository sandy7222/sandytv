import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/logica/canal_web.dart';

void main() {
  test('la dirección del canal de pesca sale de la de la cartelera', () {
    final u = urlCanalPesca(Uri.parse('https://sandy7222.github.io/sandytv/cartelera.json'));
    expect(u.toString(), 'https://sandy7222.github.io/sandytv/p/?solo=pesca');
  });

  test('si la cartelera está en otra carpeta, la página queda al lado', () {
    final u = urlCanalPesca(Uri.parse('https://x.com/a/b/cartelera.json'));
    expect(u.toString(), 'https://x.com/a/b/p/?solo=pesca');
  });
}
