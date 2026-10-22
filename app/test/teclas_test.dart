import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/logica/teclas.dart';

void main() {
  test('flechas y botones de canal', () {
    expect(mapearTecla(LogicalKeyboardKey.arrowUp).accion, Accion.canalSiguiente);
    expect(mapearTecla(LogicalKeyboardKey.channelUp).accion, Accion.canalSiguiente);
    expect(mapearTecla(LogicalKeyboardKey.arrowDown).accion, Accion.canalAnterior);
    expect(mapearTecla(LogicalKeyboardKey.channelDown).accion, Accion.canalAnterior);
    expect(mapearTecla(LogicalKeyboardKey.arrowLeft).accion, Accion.izquierda);
    expect(mapearTecla(LogicalKeyboardKey.arrowRight).accion, Accion.derecha);
  });

  test('OK, atrás y menú', () {
    expect(mapearTecla(LogicalKeyboardKey.select).accion, Accion.aceptar);
    expect(mapearTecla(LogicalKeyboardKey.enter).accion, Accion.aceptar);
    expect(mapearTecla(LogicalKeyboardKey.goBack).accion, Accion.atras);
    expect(mapearTecla(LogicalKeyboardKey.escape).accion, Accion.atras);
    expect(mapearTecla(LogicalKeyboardKey.contextMenu).accion, Accion.menu);
    expect(mapearTecla(LogicalKeyboardKey.colorF2Yellow).accion, Accion.menu);
  });

  test('info, guía y colores', () {
    expect(mapearTecla(LogicalKeyboardKey.info).accion, Accion.info);
    expect(mapearTecla(LogicalKeyboardKey.colorF0Red).accion, Accion.info);
    expect(mapearTecla(LogicalKeyboardKey.guide).accion, Accion.guia);
    expect(mapearTecla(LogicalKeyboardKey.colorF1Green).accion, Accion.guia);
  });

  test('números, del teclado y del teclado numérico', () {
    expect(mapearTecla(LogicalKeyboardKey.digit7).accion, Accion.digito);
    expect(mapearTecla(LogicalKeyboardKey.digit7).digito, 7);
    expect(mapearTecla(LogicalKeyboardKey.numpad0).digito, 0);
    expect(mapearTecla(LogicalKeyboardKey.numpad9).digito, 9);
  });

  test('botón azul y tecla de zoom cambian el formato de la imagen', () {
    expect(mapearTecla(LogicalKeyboardKey.colorF3Blue).accion, Accion.formato);
    expect(mapearTecla(LogicalKeyboardKey.zoomToggle).accion, Accion.formato);
  });

  test('la tecla "último canal" alterna con el canal anterior', () {
    expect(mapearTecla(LogicalKeyboardKey.mediaLast).accion, Accion.ultimoCanal);
  });

  test('el volumen NO se intercepta (lo maneja el televisor)', () {
    expect(mapearTecla(LogicalKeyboardKey.audioVolumeUp).accion, Accion.ninguna);
    expect(mapearTecla(LogicalKeyboardKey.audioVolumeDown).accion, Accion.ninguna);
    expect(mapearTecla(LogicalKeyboardKey.audioVolumeMute).accion, Accion.ninguna);
  });

  test('una tecla desconocida no hace nada', () {
    expect(mapearTecla(LogicalKeyboardKey.keyQ).accion, Accion.ninguna);
  });
}
