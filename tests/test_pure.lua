-- Tests purs : validation des donnees + pilote sur modele cinematique.
-- Appele par run_tests.py avec SCRIPT_SOURCE, CAR_SOURCE et check(nom, ok, detail).
_G.__BLOCKSPIN_PURE_TEST = true
local M = load(SCRIPT_SOURCE, '=blockspin_cycle_v080')()
local Car = load(CAR_SOURCE, '=car_model')()
local D = M.DEFAULT_DATA

-- Donnees
local v, err = M.validateData(D)
check('donnees par defaut valides', v ~= nil, err)
check('aller = 19 points', v and #v.route_to_vendor == 19)
check('retour = 20 points distincts', v and #v.route_to_fishing == 20 and v.route_to_fishing[1][1] ~= v.route_to_vendor[19][1])
check('schema v0.6.8 refuse', M.validateData({ points = D.route_to_vendor, fish = D.fish }) == nil)
local bad = { route_to_vendor = { { 1, 2, 3 }, { 1, 2 } }, route_to_fishing = D.route_to_fishing, fish = D.fish, vendor = D.vendor, atm = D.atm }
check('point a 2 composantes refuse', M.validateData(bad) == nil)
bad.route_to_vendor = { { 1, 2, 3 }, { 0 / 0, 2, 3 } }
check('NaN refuse', M.validateData(bad) == nil)
bad.route_to_vendor = D.route_to_vendor; bad.atm = { 1, 2, 3 }
check('CFrame incomplet refuse', M.validateData(bad) == nil)

check('texte : DÉPÔT -> depot', M.fold('DÉPÔT') == 'depot', M.fold('DÉPÔT'))
check('texte : Équilibre des mains', M.fold('Équilibre des mains : $1 200'):find('equilibre des mains', 1, true) == 1)
check('texte : CONFIRMER', M.fold('CONFIRMER') == 'confirmer')

local function cfg(over)
    local c = {}
    for k, val in pairs(M.DRIVE_DEFAULTS) do c[k] = val end
    for k, val in pairs(over or {}) do c[k] = val end
    return c
end
local function flat(list) local o = {}; for i, p in ipairs(list) do o[i] = { p[1], p[3] } end; return o end

local function run(name, route, x, z, heading, carParams, cfgOver, maxT)
    local d = M.Driver.new(flat(route), cfg(cfgOver))
    local car = Car.new(x, z, heading, carParams)
    local t, dt, ctrlDt, nextCtrl, cmd = 0, 0.01, d.cfg.dt, 0, {}
    local maxSpeed, pressedBack = 0, 0
    while t < (maxT or 400) do
        if t >= nextCtrl then
            cmd = d:step(car:obs(t)); nextCtrl = t + ctrlDt
            if d.mode == 'DONE' or d.mode == 'FAIL' then break end
        end
        car:step(dt, cmd); t = t + dt
        if car.v > maxSpeed then maxSpeed = car.v end
    end
    local last = route[#route]
    local endDist = math.sqrt((car.x - last[1]) ^ 2 + (car.z - last[3]) ^ 2)
    local res = { mode = d.mode, err = d.err, t = t, uturns = d.uturns, recov = d.recoveries,
        maxCross = d.maxCross, endDist = endDist, endSpeed = math.abs(car.v), maxSpeed = maxSpeed }
    report(name, res)
    return res
end

local A, R = D.route_to_vendor, D.route_to_fishing
-- 1. Cas de l'echec v0.7.4 : garee au pont apres le retour, capot vers le nord (+Z, cap ~0/37 deg)
local r = run('aller, depart cap nord (cas v0.7.4)', A, A[1][1], A[1][3], 20)
check('aller cap nord : arrive', r.mode == 'DONE', r.err)
check('aller cap nord : demi-tour effectue', r.uturns >= 1)
check('aller cap nord : arret < 12 studs du parking', r.endDist < 12, r.endDist)
check('aller cap nord : vitesse finale < 3', r.endSpeed < 3, r.endSpeed)
-- 2. Depart deja oriente vers le sud
r = run('aller, depart cap sud', A, A[1][1], A[1][3], 180)
check('aller cap sud : arrive', r.mode == 'DONE', r.err)
check('aller cap sud : ecart max < 14 studs', r.maxCross < 14, r.maxCross)
-- 3. Retour : arrive au vendeur cap est (~103 deg), le retour repart vers l'ouest
r = run('retour, depart cap est (arrivee aller)', R, R[1][1], R[1][3], 103)
check('retour cap est : arrive', r.mode == 'DONE', r.err)
check('retour cap est : demi-tour effectue', r.uturns >= 1)
r = run('retour, depart cap ouest', R, R[1][1], R[1][3], -80)
check('retour cap ouest : arrive', r.mode == 'DONE', r.err)
-- 4. Robustesse : direction lente, freins faibles, moteur plus rapide
r = run('aller, direction lente + freins faibles', A, A[1][1], A[1][3], 180, { steerRate = 1.5, brakeDecel = 12, vmax = 65, accel = 20 })
check('direction lente : arrive', r.mode == 'DONE', r.err)
r = run('aller, braquage faible (rayon ~20)', A, A[1][1], A[1][3], 20, { maxSteer = 0.38 })
check('braquage faible : arrive', r.mode == 'DONE', r.err)
-- 5. Reprise depuis le milieu du trajet
r = run('aller, reprise au point 9', A, A[9][1] + 3, A[9][3], 180)
check('reprise milieu : arrive', r.mode == 'DONE', r.err)
-- 6. Trop loin du trajet : refus immediat
r = run('depart a 80 studs', A, A[1][1] + 80, A[1][3], 180, nil, nil, 5)
check('trop loin : echec explicite', r.mode == 'FAIL' and tostring(r.err):find('studs du trajet') ~= nil, r.err)
-- 7. Mur devant : echec "bloque" en temps fini, jamais "arrive"
r = run('mur sur la route', A, A[5][1], A[5][3], 180, { wall = { A[6][1] - 30, A[6][3] - 2, A[6][1] + 30, A[6][3] + 2 } }, nil, 200)
check('mur : echec et pas arrivee', r.mode == 'FAIL', r.err)
check('mur : echec en < 120 s', r.t < 120, r.t)
-- 8. Prereglages de vitesse (voiture plus rapide : vmax 65, accel 20)
local fast = { vmax = 65, accel = 20 }
local rN = run('aller Normale 20/7', A, A[1][1], A[1][3], 180, fast, { cruiseSpeed = 20, turnSpeed = 7 })
local rR = run('aller Rapide 30/9', A, A[1][1], A[1][3], 180, fast, { cruiseSpeed = 30, turnSpeed = 9 })
local rM = run('aller Max moteur 45/10 natif', A, A[1][1], A[1][3], 180, fast, { cruiseSpeed = 45, turnSpeed = 10, nativeStraight = true })
check('Rapide : arrive', rR.mode == 'DONE', rR.err)
check('Max moteur : arrive', rM.mode == 'DONE', rM.err)
check('Rapide plus rapide que Normale', rR.t < rN.t and rR.maxSpeed > 25, rR.maxSpeed)
check('Max moteur : depasse la cible Rapide en ligne droite', rM.maxSpeed > 31, rM.maxSpeed)
check('Max moteur : arret < 12 studs', rM.endDist < 12 and rM.endSpeed < 3, rM.endDist)
local rRr = run('retour Max moteur, demi-tour', R, R[1][1], R[1][3], 103, fast, { cruiseSpeed = 45, turnSpeed = 10, nativeStraight = true })
check('retour Max moteur : arrive', rRr.mode == 'DONE', rRr.err)
