import 'package:flutter/services.dart';

enum Accion { canalSiguiente, canalAnterior, izquierda, derecha, digito, aceptar, atras, info, guia, menu, ninguna }

class TeclaMapeada {
  const TeclaMapeada(this.accion, [this.digito]);
  final Accion accion;
  final int? digito;
}

final _digitos = <LogicalKeyboardKey, int>{
  LogicalKeyboardKey.digit0: 0, LogicalKeyboardKey.digit1: 1, LogicalKeyboardKey.digit2: 2,
  LogicalKeyboardKey.digit3: 3, LogicalKeyboardKey.digit4: 4, LogicalKeyboardKey.digit5: 5,
  LogicalKeyboardKey.digit6: 6, LogicalKeyboardKey.digit7: 7, LogicalKeyboardKey.digit8: 8,
  LogicalKeyboardKey.digit9: 9,
  LogicalKeyboardKey.numpad0: 0, LogicalKeyboardKey.numpad1: 1, LogicalKeyboardKey.numpad2: 2,
  LogicalKeyboardKey.numpad3: 3, LogicalKeyboardKey.numpad4: 4, LogicalKeyboardKey.numpad5: 5,
  LogicalKeyboardKey.numpad6: 6, LogicalKeyboardKey.numpad7: 7, LogicalKeyboardKey.numpad8: 8,
  LogicalKeyboardKey.numpad9: 9,
};

/// Traduce una tecla del control remoto a lo que hace SandyTV.
/// Las teclas de volumen devuelven `ninguna` a propósito: las maneja el televisor.
TeclaMapeada mapearTecla(LogicalKeyboardKey k) {
  final d = _digitos[k];
  if (d != null) return TeclaMapeada(Accion.digito, d);
  if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp) return const TeclaMapeada(Accion.canalSiguiente);
  if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown) return const TeclaMapeada(Accion.canalAnterior);
  if (k == LogicalKeyboardKey.arrowLeft) return const TeclaMapeada(Accion.izquierda);
  if (k == LogicalKeyboardKey.arrowRight) return const TeclaMapeada(Accion.derecha);
  if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.gameButtonA) {
    return const TeclaMapeada(Accion.aceptar);
  }
  if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.browserBack) {
    return const TeclaMapeada(Accion.atras);
  }
  if (k == LogicalKeyboardKey.info || k == LogicalKeyboardKey.colorF0Red) return const TeclaMapeada(Accion.info);
  if (k == LogicalKeyboardKey.guide || k == LogicalKeyboardKey.colorF1Green) return const TeclaMapeada(Accion.guia);
  if (k == LogicalKeyboardKey.contextMenu || k == LogicalKeyboardKey.settings || k == LogicalKeyboardKey.colorF2Yellow) {
    return const TeclaMapeada(Accion.menu);
  }
  return const TeclaMapeada(Accion.ninguna);
}
