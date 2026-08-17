import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/desktop/desktop_window_metrics.dart';

void main() {
  test('el tamaño por defecto es 4:3 y cabe en un monitor 1080p', () {
    const work = Size(1920, 1040);
    final size = DesktopWindowMetrics.defaultSizeForWorkArea(work);
    expect(
      size.width / size.height,
      closeTo(DesktopWindowMetrics.aspect, 0.01),
    );
    expect(size.width, lessThan(work.width));
    expect(size.height, lessThan(work.height));
    expect(
      size.width,
      greaterThanOrEqualTo(DesktopWindowMetrics.minSize.width),
    );
  });

  test('en un portátil 1366x768 el 4:3 no se sale del área de trabajo', () {
    const work = Size(1366, 728);
    final size = DesktopWindowMetrics.defaultSizeForWorkArea(work);
    expect(
      size.width / size.height,
      closeTo(DesktopWindowMetrics.aspect, 0.01),
    );
    expect(size.width, lessThanOrEqualTo(work.width));
    expect(size.height, lessThanOrEqualTo(work.height));
  });

  test('a escala 150% abre más chica y sigue en 4:3', () {
    // 1920×1080 a 150%: escritorio lógico ~1280×693.
    const work = Size(1280, 693);
    final size = DesktopWindowMetrics.defaultSizeForWorkArea(work);
    expect(
      size.width / size.height,
      closeTo(DesktopWindowMetrics.aspect, 0.01),
    );
    expect(size.width, lessThan(DesktopWindowMetrics.minSize.width));
    expect(size.height, lessThan(work.height));

    final min = DesktopWindowMetrics.minSizeFor(
      workArea: work,
      scaleFactor: 1.5,
    );
    expect(min.width, lessThanOrEqualTo(size.width));
    expect(min.height, lessThanOrEqualTo(size.height));
    expect(min.width, lessThan(DesktopWindowMetrics.minSize.width));
  });

  test('el mínimo a 100% sigue siendo 900×600', () {
    const work = Size(1920, 1040);
    expect(
      DesktopWindowMetrics.minSizeFor(workArea: work),
      DesktopWindowMetrics.minSize,
    );
  });

  test('sin área de trabajo usa el fallback 4:3', () {
    expect(
      DesktopWindowMetrics.defaultSizeForWorkArea(Size.zero),
      DesktopWindowMetrics.fallbackSize,
    );
    expect(
      DesktopWindowMetrics.fallbackSize.width /
          DesktopWindowMetrics.fallbackSize.height,
      closeTo(DesktopWindowMetrics.aspect, 0.01),
    );
  });
}
