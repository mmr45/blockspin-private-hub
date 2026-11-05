"""Banc d'essai hors Roblox (Python 3 + lupa 2.8).
  python -I tests/run_tests.py
Ce que ces tests prouvent : la logique du script (pilote, cycle, annulation, nettoyage,
donnees) se comporte comme prevu dans une maquette. Ce qu'ils NE prouvent PAS :
la physique reelle du G-Cruzer, les interfaces reelles de BlockSpin, Xeno, l'anti-triche.
"""
import json
import pathlib
import sys

from lupa import lua54

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = (ROOT / "src" / "main.lua").read_text(encoding="utf-8")
CAR = (ROOT / "tests" / "car_model.lua").read_text(encoding="utf-8")
MOCK = (ROOT / "tests" / "mock_roblox.lua").read_text(encoding="utf-8")

results = []


def check(name, ok, detail=None):
    results.append((name, bool(ok), detail))
    print(("  OK   " if ok else "  ECHEC") + " " + str(name) + ("" if ok or detail is None else "  -> " + str(detail)))


def report(name, res):
    r = dict(res.items())
    print("  [sim] %-42s %-5s t=%5.1fs demi-tours=%s degag=%s ecart_max=%.1f fin=%.1f studs v_fin=%.1f v_max=%.1f %s" % (
        name, r["mode"], r["t"], r["uturns"], r["recov"], r["maxCross"], r["endDist"], r["endSpeed"], r["maxSpeed"],
        ("err=" + str(r["err"])) if r.get("err") else ""))


def new_lua():
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.check = check
    g.report = report
    g.SCRIPT_SOURCE = SCRIPT
    g.CAR_SOURCE = CAR
    return lua


# Luau et Lua limitent a 200 les variables locales du bloc principal : garder une marge.
probe = new_lua().eval("function(s) local f, e = load(s, \"=main\") return e end")
margin = next((n - 1 for n in range(0, 200) if probe(SCRIPT + "\n" + "".join("local zz%d=1\n" % i for i in range(n)))), 199)
check("compilation : marge de variables locales >= 10", margin >= 10, margin)

print("== Tests purs (donnees + pilote sur modele cinematique simplifie) ==")
lua = new_lua()
lua.execute((ROOT / "tests" / "test_pure.lua").read_text(encoding="utf-8"))

lua.execute((ROOT / "tests" / "test_v1_core.lua").read_text(encoding="utf-8"))

print("== Tests d'integration (maquette Roblox) ==")
fs = {}


def py_json_encode(t):
    def conv(o):
        if lua54.lua_type(o) == "table":
            keys = list(o.keys())
            if keys and all(isinstance(k, int) for k in keys):
                return [conv(o[i]) for i in range(1, len(keys) + 1)]
            return {str(k): conv(o[k]) for k in keys}
        return o
    return json.dumps(conv(t))


lua = new_lua()
g = lua.globals()


def to_lua(o):
    if isinstance(o, dict):
        return lua.table_from({k: to_lua(v) for k, v in o.items()})
    if isinstance(o, list):
        return lua.table_from([to_lua(v) for v in o])
    return o


g.py_json_encode = py_json_encode
g.py_json_decode = lambda s: to_lua(json.loads(s))
g.MOCK_SOURCE = MOCK
if "--pure" not in sys.argv:
    lua.execute((ROOT / "tests" / "test_integration.lua").read_text(encoding="utf-8"))
    lua.execute((ROOT / "tests" / "test_v1_integration.lua").read_text(encoding="utf-8"))

failed = [r for r in results if not r[1]]
print("\n%d verifications, %d echec(s)" % (len(results), len(failed)))
sys.exit(1 if failed else 0)
