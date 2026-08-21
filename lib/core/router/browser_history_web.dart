import 'package:web/web.dart' as web;

/// Retrocede [pasos] entradas del historial del navegador.
///
/// `history.go(-n)` es lo mismo que pulsar atrás n veces: el navegador emite
/// `popstate`, el motor entrega la `RouteInformation` guardada y go_router
/// restaura la pila que había. Un `pop` del `Navigator`, en cambio, **añade**
/// una entrada nueva, y esa era la razón de que el atrás del navegador —o el
/// botón lateral del mouse— tuviera que pulsarse varias veces para avanzar
/// una sola pantalla.
bool retrocederEnHistorial(int pasos) {
  if (pasos <= 0) return false;
  web.window.history.go(-pasos);
  return true;
}
