#!/usr/bin/env python3
"""Generate lib/core/data/astro_ephemeris_tables.dart from PyMeeus (Meeus).

Self-contained: downloads the pinned PyMeeus sdist from PyPI, parses the
VSOP87 series (Meeus ch.32) for Mercury..Neptune, the Moon periodic terms
(Meeus ch.47) and the Pluto tables (Meeus ch.37), trims negligible terms
(|A| < 1000 for L/B, |A| < 5000 for R) and emits const Dart tables.

Usage:  python3 tool/gen_ephemeris_tables.py
"""

from __future__ import annotations

import ast
import io
import json
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

PYMEEUS_VERSION = "0.5.12"
OUT = Path(__file__).resolve().parent.parent / "lib" / "core" / "data" / (
    "astro_ephemeris_tables.dart"
)
PLANETS = ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]


def download_sdist() -> Path:
    url = f"https://pypi.org/pypi/PyMeeus/{PYMEEUS_VERSION}/json"
    with urllib.request.urlopen(url, timeout=60) as resp:
        meta = json.loads(resp.read().decode("utf-8"))
    sdist_url = next(
        u["url"] for u in meta["urls"] if u["packagetype"] == "sdist"
    )
    print(f"downloading {sdist_url}")
    data = urllib.request.urlopen(sdist_url, timeout=120).read()
    tar = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
    root = Path(__file__).resolve().parent.parent / ".cache" / "pymeeus"
    root.mkdir(parents=True, exist_ok=True)
    tar.extractall(root)
    return root / f"PyMeeus-{PYMEEUS_VERSION}" / "pymeeus"


def read_file(root: Path, name: str) -> str:
    return (root / f"{name}.py").read_text(encoding="utf-8")


def extract_list(source: str, name: str) -> list:
    """Parse a module-level `name = [ ... ]` Python literal."""
    match = re.search(rf"^{name}\s*=\s*\[", source, re.MULTILINE)
    if not match:
        raise SystemExit(f"table {name} not found")
    start = match.end() - 1  # the opening bracket
    depth = 0
    i = start
    while i < len(source):
        ch = source[i]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return ast.literal_eval(source[start : i + 1])


def dart_number(value: float) -> str:
    s = f"{value:.12g}"
    if "." not in s and "e" not in s:
        s += ".0"
    return s


def emit_series(f, lines: list, indent: str, threshold: int) -> None:
    """One VSOP order: list of (A, B, C) terms above the threshold."""
    kept = [t for t in lines if abs(t[0]) >= threshold]
    f.write(f"{indent}[\n")
    for a, b, c in kept:
        f.write(
            f"{indent}  [{dart_number(a)}, {dart_number(b)}, "
            f"{dart_number(c)}],\n"
        )
    f.write(f"{indent}],\n")


def main() -> None:
    root = download_sdist()

    # ---- Moon (Meeus ch.47) ----
    moon_src = read_file(root, "Moon")
    moon_lr = extract_list(moon_src, "PERIODIC_TERMS_LR_TABLE")
    moon_b = extract_list(moon_src, "PERIODIC_TERMS_B_TABLE")

    # ---- Planets (VSOP87, Meeus ch.32) ----
    vsop = {}
    for planet in PLANETS:
        src = read_file(root, planet)
        vsop[planet] = {
            "L": extract_list(src, "VSOP87_L"),
            "B": extract_list(src, "VSOP87_B"),
            "R": extract_list(src, "VSOP87_R"),
        }

    # ---- Pluto (Meeus ch.37) ----
    pluto_src = read_file(root, "Pluto")
    pluto_arg = extract_list(pluto_src, "PLUTO_ARGUMENT")
    pluto_lon = extract_list(pluto_src, "PLUTO_LONGITUDE")
    pluto_lat = extract_list(pluto_src, "PLUTO_LATITUDE")
    pluto_rad = extract_list(pluto_src, "PLUTO_RADIUS_VECTOR")
    assert len(pluto_arg) == len(pluto_lon) == len(pluto_lat) == len(pluto_rad)

    with OUT.open("w", encoding="utf-8") as f:
        f.write(
            "// GENERATED FILE — do not hand-edit.\n"
            "// Source: PyMeeus " + PYMEEUS_VERSION + " (Meeus, \"Astronomical "
            "Algorithms\"):\n"
            "//   * VSOP87 heliocentric series, ch.32 (Mercury..Neptune)\n"
            "//   * Moon periodic terms, ch.47\n"
            "//   * Pluto tables, ch.37\n"
            "// Regenerate with: python3 tool/gen_ephemeris_tables.py\n"
            "// Terms are trimmed (|A| >= 1000 for L/B, |A| >= 5000 for R);\n"
            "// the dropped tail is far below the engine's 0.05° target.\n\n"
        )
        f.write("/// Moon longitude/radius periodic terms (D, M, M', F, "
                "coeffL, coeffR).\n")
        f.write("const List<List<double>> astroMoonLr = [\n")
        for row in moon_lr:
            f.write("  [" + ", ".join(dart_number(float(v)) for v in row)
                    + "],\n")
        f.write("];\n\n")
        f.write("/// Moon latitude periodic terms (D, M, M', F, coeffB).\n")
        f.write("const List<List<double>> astroMoonB = [\n")
        for row in moon_b:
            f.write("  [" + ", ".join(dart_number(float(v)) for v in row)
                    + "],\n")
        f.write("];\n\n")
        for series, key, threshold in (("L", "astroVsopL", 1000),
                                       ("B", "astroVsopB", 1000),
                                       ("R", "astroVsopR", 5000)):
            f.write(
                f"/// VSOP87 {series} series per planet: outer list = orders "
                f"{series}0..{series}5 (B/R shorter), each term [A, B, C] "
                f"in A·cos(B + C·t) with t in 100 Julian centuries.\n"
            )
            f.write(f"const Map<String, List<List<List<double>>>> {key} = {{\n")
            for planet in PLANETS:
                f.write(f"  '{planet.lower()}': [\n")
                for order in vsop[planet][series]:
                    emit_series(f, order, "    ", threshold)
                f.write("  ],\n")
            f.write("};\n\n")
        f.write(
            "/// Pluto (Meeus ch.37): one row per term\n"
            "/// [J, S, P, aLonSin, aLonCos, aLatSin, aLatCos, aRadSin, "
            "aRadCos].\n"
            "const List<List<double>> astroPluto = [\n"
        )
        for idx in range(len(pluto_arg)):
            j, s, p = pluto_arg[idx]
            als, alc = pluto_lon[idx]
            bls, blc = pluto_lat[idx]
            ars, arc = pluto_rad[idx]
            f.write(
                f"  [{dart_number(float(j))}, {dart_number(float(s))}, "
                f"{dart_number(float(p))}, {dart_number(float(als))}, "
                f"{dart_number(float(alc))}, {dart_number(float(bls))}, "
                f"{dart_number(float(blc))}, {dart_number(float(ars))}, "
                f"{dart_number(float(arc))}],\n"
            )
        f.write("];\n")
        f.write(
            "\n/// Pluto base constants: [lonBase 238.958116, lonRate 144.96,\n"
            "/// latBase -3.908239, radiusBase 40.7241346].\n"
            "const List<double> astroPlutoBase = "
            "[238.958116, 144.96, -3.908239, 40.7241346];\n"
            "\n/// Pluto argument rates: [jBase 34.35, jRate 3034.9057,\n"
            "/// sBase 50.08, sRate 1222.1138, pBase 238.96, pRate 144.96].\n"
            "const List<double> astroPlutoArgs = "
            "[34.35, 3034.9057, 50.08, 1222.1138, 238.96, 144.96];\n"
        )
    print(f"wrote {OUT}")


if __name__ == "__main__":
    sys.exit(main())
