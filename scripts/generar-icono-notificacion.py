"""Genera el icono de la bandeja de notificaciones de Android desde el logo.

Android ignora el color del *small icon*: toma solo el canal alfa y lo pinta
del color del sistema. Por eso el icono no puede ser el logo a color —quedaría
un borron blanco— sino una silueta.

El logo son dos "visto bueno" superpuestos (el azul delante del verde). En
monocromo se fundirian en una sola mancha, asi que se recorta un hueco en el
verde siguiendo el contorno del azul: es lo que mantiene la W legible a 24dp.

Uso:
    python scripts/generar-icono-notificacion.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageFilter

ORIGEN = "android/app/src/main/res/drawable-nodpi/splash_logo.png"
DESTINO = "android/app/src/main/res/drawable-{densidad}/ic_notification.png"

# Tamaños del small icon: 24dp en cada densidad.
DENSIDADES = {
    "mdpi": 24,
    "hdpi": 36,
    "xhdpi": 48,
    "xxhdpi": 72,
    "xxxhdpi": 96,
}

# Resolución de trabajo: se recorta y compone acá, y recién al final se baja a
# cada densidad. Hacerlo al revés dejaría el hueco dentado en los tamaños
# chicos.
TRABAJO = 1024

# Fracción del lado que ocupan el hueco entre ambos vistos y el margen exterior.
# Expresadas sobre el icono final, para que el peso visual sea el mismo en
# todas las densidades.
HUECO = 0.055
MARGEN = 0.04


def _mascaras(imagen: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Separa el verde y el azul del fondo blanco del logo."""
    ancho, alto = imagen.size
    pixeles = imagen.load()
    verde = Image.new("L", imagen.size, 0)
    azul = Image.new("L", imagen.size, 0)
    pv, pa = verde.load(), azul.load()

    for y in range(alto):
        for x in range(ancho):
            r, g, b, a = pixeles[x, y]
            if a < 32:
                continue
            # Gris claro = fondo. El logo es siempre saturado.
            if max(r, g, b) - min(r, g, b) < 40 and max(r, g, b) > 180:
                continue
            if g > b:
                pv[x, y] = 255
            else:
                pa[x, y] = 255
    return verde, azul


def _silueta(verde: Image.Image, azul: Image.Image, hueco_px: int) -> Image.Image:
    """Une ambos vistos dejando aire alrededor del azul, que va delante."""
    if hueco_px > 0:
        radio = hueco_px * 2 + 1
        azul_engrosado = azul.filter(ImageFilter.MaxFilter(radio))
    else:
        azul_engrosado = azul

    ancho, alto = verde.size
    salida = Image.new("L", verde.size, 0)
    pv, pa, pe, ps = verde.load(), azul.load(), azul_engrosado.load(), salida.load()
    for y in range(alto):
        for x in range(ancho):
            if pa[x, y]:
                ps[x, y] = 255
            elif pv[x, y] and not pe[x, y]:
                ps[x, y] = 255
    return salida


def main() -> None:
    origen = Image.open(ORIGEN).convert("RGBA")
    if origen.size != (TRABAJO, TRABAJO):
        origen = origen.resize((TRABAJO, TRABAJO), Image.LANCZOS)

    verde, azul = _mascaras(origen)
    silueta = _silueta(verde, azul, round(TRABAJO * HUECO))

    caja = silueta.getbbox()
    if caja is None:
        raise SystemExit("No se encontró el logo dentro de %s" % ORIGEN)
    recorte = silueta.crop(caja)

    # Lienzo cuadrado con margen, para que ninguna densidad recorte el trazo.
    lado = max(recorte.size)
    margen = round(lado * MARGEN * 2)
    lienzo = Image.new("L", (lado + margen, lado + margen), 0)
    lienzo.paste(
        recorte,
        (
            (lienzo.width - recorte.width) // 2,
            (lienzo.height - recorte.height) // 2,
        ),
    )

    for densidad, tamano in DENSIDADES.items():
        alfa = lienzo.resize((tamano, tamano), Image.LANCZOS)
        icono = Image.new("RGBA", alfa.size, (255, 255, 255, 0))
        icono.putalpha(alfa)
        ruta = DESTINO.format(densidad=densidad)
        os.makedirs(os.path.dirname(ruta), exist_ok=True)
        icono.save(ruta, "PNG", optimize=True)
        print("%-56s %dx%d" % (ruta, tamano, tamano))


if __name__ == "__main__":
    main()
