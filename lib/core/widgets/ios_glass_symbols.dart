import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// SF Symbol equivalente a un icono de cabecera (atrás, editar, borrar, compartir).
///
/// Si no hay homólogo nativo, [TwIosGlassIconButton] usa el [IconData] como
/// `customIcon` y el botón sigue siendo Liquid Glass.
String? sfSymbolForHeaderIcon(IconData icon) {
  if (icon == Symbols.arrow_back_rounded ||
      icon == Symbols.arrow_back_ios_new_rounded ||
      icon == Symbols.arrow_back ||
      icon == Symbols.chevron_left_rounded ||
      icon == Icons.arrow_back ||
      icon == Icons.arrow_back_ios_new) {
    return 'chevron.left';
  }
  if (icon == Symbols.edit_rounded || icon == Symbols.edit) {
    return 'pencil';
  }
  if (icon == Symbols.delete_outline_rounded ||
      icon == Symbols.delete_rounded ||
      icon == Symbols.delete) {
    return 'trash';
  }
  if (icon == Symbols.ios_share_rounded || icon == Symbols.share_rounded) {
    return 'square.and.arrow.up';
  }
  return null;
}
