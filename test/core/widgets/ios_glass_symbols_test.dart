import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/widgets/ios_glass_symbols.dart';

void main() {
  test('atrás, editar, eliminar y compartir tienen SF Symbol nativo', () {
    expect(sfSymbolForHeaderIcon(Symbols.arrow_back_rounded), 'chevron.left');
    expect(
      sfSymbolForHeaderIcon(Symbols.arrow_back_ios_new_rounded),
      'chevron.left',
    );
    expect(sfSymbolForHeaderIcon(Symbols.edit_rounded), 'pencil');
    expect(sfSymbolForHeaderIcon(Symbols.delete_outline_rounded), 'trash');
    expect(
      sfSymbolForHeaderIcon(Symbols.ios_share_rounded),
      'square.and.arrow.up',
    );
  });

  test('un icono sin homólogo nativo no inventa un símbolo', () {
    expect(sfSymbolForHeaderIcon(Symbols.notifications_rounded), isNull);
  });
}
