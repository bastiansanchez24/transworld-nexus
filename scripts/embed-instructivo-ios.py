"""Empaqueta el instructivo iOS/iPad como base64 para el correo de credenciales."""

from __future__ import annotations

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "Instructivo de Instalacion RegisPro iOS-iPad.pdf"
DEST = ROOT / "supabase" / "functions" / "_shared" / "instructivo_ios_pdf.ts"

HEADER = '''/**
 * PDF del instructivo iOS/iPad, embebido para adjuntarlo al correo
 * (Brevo). Fuente: docs/Instructivo de Instalacion RegisPro iOS-iPad.pdf
 *
 * Si actualiza el PDF, regenere este archivo con:
 *   python scripts/embed-instructivo-ios.py
 */
export const NOMBRE_INSTRUCTIVO_IOS =
  "Instructivo de Instalacion RegisPro iOS-iPad.pdf";

export const INSTRUCTIVO_IOS_PDF_BASE64 =
  `
'''

FOOTER = '''
`.replace(/\\s+/g, "");
'''


def main() -> None:
    b64 = base64.b64encode(SRC.read_bytes()).decode("ascii")
    wrapped = "\n".join(b64[i : i + 100] for i in range(0, len(b64), 100))
    DEST.write_text(HEADER + wrapped + FOOTER, encoding="utf-8")
    print(f"wrote {DEST.relative_to(ROOT)} ({DEST.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
