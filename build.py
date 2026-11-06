"""Assemble le script unique : cycle, hub_core, interface, visuals, observatory, workspace_ui et route_data.json.
Usage : python -I build.py [--check] (depuis n'importe quel dossier)."""
import argparse
import json
import pathlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true", help="verifier sans reecrire main.lua")
args = parser.parse_args()
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
core_marker = "--@@HUB_CORE@@"
assert src.count(core_marker) == 1, "marqueur hub absent"
core = (ROOT / "src" / "hub_core.lua").read_text(encoding="utf-8")
interface_marker = "--@@INTERFACE@@"
assert src.count(interface_marker) == 1, "marqueur interface absent"
interface = (ROOT / "src" / "interface.lua").read_text(encoding="utf-8")
visuals = (ROOT / "src" / "visuals.lua").read_text(encoding="utf-8")
assert interface.count("--@@VISUALS@@") == 1, "marqueur widgets absent"
interface = interface.replace("--@@VISUALS@@", visuals)
out = src.replace(marker, block).replace(core_marker, "local Hub = (function()\n" + core + "\nend)()").replace(interface_marker, interface)
for name in ("observatory", "workspace_ui"):
    extra_marker = "--@@" + name.upper() + "@@"
    assert out.count(extra_marker) == 1, "marqueur " + name + " absent"
    out = out.replace(extra_marker, (ROOT / "src" / (name + ".lua")).read_text(encoding="utf-8"))
target = ROOT / "src" / "main.lua"
if args.check:
    if not target.exists() or target.read_text(encoding="utf-8") != out:
        parser.exit(1, "src/main.lua obsolete : lancer python -I build.py\n")
    print("OK : src/main.lua correspond aux sources et aux donnees")
else:
    target.write_text(out, encoding="utf-8", newline="\n")
    print("ecrit src/main.lua", len(out.splitlines()), "lignes")
