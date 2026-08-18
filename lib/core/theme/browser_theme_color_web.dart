import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

String? _lastHex;

void setBrowserThemeColor(Color color) {
  final argb = color.toARGB32();
  final hex = '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  if (_lastHex == hex) return;
  _lastHex = hex;

  final head = web.document.head;
  if (head == null) return;

  final existing = web.document.querySelectorAll('meta[name="theme-color"]');
  if (existing.length > 0) {
    for (var i = 0; i < existing.length; i++) {
      final node = existing.item(i);
      if (node == null) continue;
      (node as web.HTMLMetaElement).content = hex;
    }
    return;
  }

  final meta = web.document.createElement('meta') as web.HTMLMetaElement;
  meta.name = 'theme-color';
  meta.content = hex;
  head.append(meta);
}
