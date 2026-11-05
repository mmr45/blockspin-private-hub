"""Assemble src/main.lua (script complet a coller dans Xeno ou charge par loader.lua) : injecte data/route_data.json dans src/cycle.lua.
Usage : python -I build.py   (depuis n'importe quel dossier)"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
src = (ROOT / "src" / "cycle.lua").read_text(encoding="utf-8")
data = json.loads((ROOT / "data" / "route_data.json").read_text(encoding="utf-8"))


def num(v):
    return repr(float(v))


def pts(name):
    rows = ",\n".join("        {%s}" % ", ".join(num(c) for c in p) for p in data[name])
    return "    %s = {\n%s\n    }," % (name, rows)


def cf(name):
    return "    %s = {%s}," % (name, ", ".join(num(c) for c in data[name]))


block = "\n".join([
    "-- Donnees par defaut = data/route_data.json (aller 19 points, retour 20 points DISTINCTS).",
    "-- Un fichier blockspin_data_v080.json valide dans le dossier workspace de l'executeur les remplace.",
    "local DEFAULT_DATA = {",
    "    version = 1,",
    pts("route_to_vendor"),
    pts("route_to_fishing"),
    cf("fish"), cf("vendor"), cf("atm"),
    "}",
])
marker = "--@@DEFAULT_DATA@@"
assert src.count(marker) == 1, "marqueur absent"
out = src.replace(marker, block)
(ROOT / "src" / "main.lua").write_text(out, encoding="utf-8", newline="\n")
print("ecrit src/main.lua", len(out.splitlines()), "lignes")
