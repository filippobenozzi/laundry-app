#!/usr/bin/env bash
# Compiles and runs Bucato's logic checks on the host Mac: the fibre catalogue,
# the composition parser against real label text, the symbol lookup and the
# advice engine. No simulator involved.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${TMPDIR:-/tmp}/bucato-checks"
mkdir -p "$BUILD_DIR"

xcrun swiftc -O -o "$BUILD_DIR/checks" \
  Bucato/Model/Fiber.swift \
  Bucato/Model/CareSymbol.swift \
  Bucato/Model/Composition.swift \
  Bucato/Model/CareReading.swift \
  Bucato/Model/WashPlan.swift \
  Bucato/Support/CareGlyphPath.swift \
  Bucato/Support/GlyphRaster.swift \
  Bucato/Scan/BinaryImage.swift \
  Bucato/Scan/ShapeDescriptor.swift \
  Bucato/Scan/Deskew.swift \
  Bucato/Scan/SymbolDetector.swift \
  Tests/BucatoChecks/GlyphRasterizer.swift \
  Tests/BucatoChecks/main.swift

"$BUILD_DIR/checks"
