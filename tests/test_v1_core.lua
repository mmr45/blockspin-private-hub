-- Tests purs V1 : argent observe, bibliotheque, journal et limites.
_G.__BLOCKSPIN_PURE_TEST = true
local exports = load(SCRIPT_SOURCE, '=v1-core')()
local Hub = exports.Hub
local h = Hub.new(10)
check('session : aucun taux avant 60 s', h:snapshot(69).hourly == nil)
h:observeCash(500); h:observeCash(900); h:observeCash(200)
check('argent : variations passives exclues des gains', h.money.earned == 0 and h.money.observedIncreases == 400)
check('vente : montant sans preuve refuse', not h:transaction('a', 'sale', 200, 400, false))
check('vente : montant inconnu refuse', not h:transaction('a', 'sale', nil, 400, true))
check('vente : hausse avec preuve acceptee', h:transaction('a', 'sale', 200, 400, true) and h.money.earned == 200)
check('vente : dedoublonnage', not h:transaction('a', 'sale', 200, 400, true) and h.money.sales == 1)
check('depot : baisse observee acceptee', h:transaction('b', 'deposit', 400, 0, true) and h.money.deposited == 400)
check('depot : ne diminue pas les gains', h.money.earned == 200 and h:snapshot(3610).hourly == 200)
check('argent : montants invalides refuses', not h:observeCash(0/0) and not h:transaction('c', 'sale', -1, 50, true))
h:observeBait(10); h:observeBait(7); h:observeBait(20); h:observeBait(0)
check('appats : baisses et ajouts distincts', h.money.baitUsed == 23 and h.money.baitAdded == 13)
check('appats : compte entier fini requis', not h:observeBait(2.5) and not h:observeBait(math.huge))

local cf = exports.DEFAULT_DATA.fish
local original = cf[1]
check('spot : position precise et visee acceptees', h:addSpot('Pont', cf, { x = 100.25, y = 200.5 }))
cf[1] = 999
check('spot : copie independante', h.library.spots.Pont.cf[1] == original)
cf[1] = original
check('spot : remplacement implicite refuse', not h:addSpot('Pont', cf))
check('spot : NaN refuse', not h:addSpot('Invalide', { 0/0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }))
h:spotEvent('casts'); h:spotEvent('texts'); h:spotEvent('rareSignals'); h:spotTime(2.5)
check('spot : observations distinguees des captures', h.spotStats.Pont.casts == 1 and h.spotStats.Pont.texts == 1 and h.spotStats.Pont.rareSignals == 1 and h.spotStats.Pont.seconds == 2.5)
local points = { {1,2,3}, {4,5,6} }
check('trajet nomme valide', h:addRoute('Vendeur', points))
points[1][1] = 80
check('trajet : copie independante', h.library.routes.Vendeur[1][1] == 1)
check('trajet : doublon refuse', not h:addRoute('Vendeur', points))
check('trajet : points identiques refuses', not h:addRoute('vide', {{1,2,3}, {1,2,3}}))
check('trajet : composante infinie refusee', not h:addRoute('inf', {{1,2,3}, {math.huge,2,3}}))
local big = {}; for i=1,2001 do big[i] = {i,0,0} end
check('trajet : limite 2000 points', not h:addRoute('grand', big))
local before = h.library
check('bibliotheque : rejet atomique', not h:loadLibrary({schema=1, spots={ bad={cf={1}} }, routes={}}) and h.library == before)
check('bibliotheque : aller et retour inchanges', #exports.DEFAULT_DATA.route_to_vendor == 19 and #exports.DEFAULT_DATA.route_to_fishing == 20)
local another = Hub.new(0)
check('bibliotheque : restauration valide', another:loadLibrary(h.library) and another.library.spots.Pont.aim.x == 100.25)
for i=1,49 do h:addSpot('P'..i, cf) end
check('spots : limite de 50', not h:addSpot('P50', cf))
for i=1,49 do h:addRoute('R'..i, points) end
check('trajets : limite de 50', not h:addRoute('R50', points))

h:beginStep('VENTE', 20, 5, 4)
check('etape : delai et token', not h:expired(24,4) and h:expired(25,4) and not h:expired(25,3))
h:finishStep(false, 'preuve absente', 26)
check('etape : echec historise', h.current == nil and h.history[1].ok == false and h.errors[1].stage == 'VENTE')
for i=1,100 do h:error('test', tostring(i), i); h:beginStep('T', i, 1, i); h:finishStep(true, 'ok', i) end
check('journal et historique : bornes a 80', #h.errors == 80 and #h.history == 80)
check('culture : pas d\'adaptateur devine', h:farmAction('A', 'Corn', true) == nil and not h.farm.available)
check('culture : adaptateur incomplet refuse', not h:setFarmAdapter({observe=function() end}))
local state = {state='ready',crop='Corn'}
check('culture : adaptateur explicite accepte', h:setFarmAdapter({observe=function() return state end,plant=function() return true end,harvest=function() return true end}))
check('culture : mauvaise plante refusee', h:farmAction('A','Pumpkin',true) == nil)
check('culture : recolte prete reconnue', h:farmAction('A','Corn',true).kind == 'harvest')
state = {state='growing',crop='Corn'}
check('culture : croissance reconnue', h:farmAction('A','Corn',true).kind == 'wait')

local cfg = Hub.copy(exports.DRIVE_DEFAULTS)
local driver = exports.Driver.new({{0,0},{10,0}}, cfg)
driver:step({t=0,x=9,z=0,lx=1,lz=0,vx=10,vz=0,yaw=0})
driver:step({t=4,x=9,z=0,lx=1,lz=0,vx=10,vz=0,yaw=0})
check('parking : vitesse persistante = echec explicite', driver.mode == 'FAIL' and driver.err:find('stationnement',1,true) ~= nil)
check('argent : decimales conservees', Hub.parseMoney('12.50') == 12.5 and Hub.parseMoney('12,50') == 12.5)
check('argent : milliers acceptes', Hub.parseMoney('1,200') == 1200 and Hub.parseMoney('1.200') == 1200 and Hub.parseMoney('1 200') == 1200)
check('argent : formats mixtes valides', Hub.parseMoney('1,200.50') == 1200.5 and Hub.parseMoney('1.200,50') == 1200.5)
check('argent : formats ambigus refuses', Hub.parseMoney('1,2,3') == nil and Hub.parseMoney('-500') == nil and Hub.parseMoney('abc') == nil)
check('HSV : couleurs primaires', Hub.hsvToHex(0,1,1)=='FF0000' and Hub.hsvToHex(1/3,1,1)=='00FF00' and Hub.hsvToHex(2/3,1,1)=='0000FF')
check('HSV : blanc et noir', Hub.hsvToHex(0.7,0,1)=='FFFFFF' and Hub.hsvToHex(0.2,1,0)=='000000')
check('HSV : valeurs bornees et nombres invalides refuses', Hub.hsvToHex(1,2,1)=='FF0000' and Hub.hsvToHex(0/0,1,1)==nil)
local roundTrip=true
for _,hex in ipairs({'FF475C','12ABEF','000000','FFFFFF','808080','00FFFF','B07CFF'}) do
    local h,s,v=Hub.hexToHSV(hex);if Hub.hsvToHex(h,s,v)~=hex then roundTrip=false end
end
check('HSV : conversion aller-retour exacte des accents', roundTrip)
check('HSV : hexadecimal invalide refuse', Hub.hexToHSV('GGGGGG')==nil and Hub.hexToHSV('123')==nil)
local monitor=Hub.newServer(0,30)
monitor:add(1,'A','Alice',0,true);monitor:add(2,'B','Bob',1,false)
check('serveur pur : baseline distincte d\'une arrivee', monitor.count==2 and monitor.joined==1 and #monitor.events==1)
check('serveur pur : id invalide refuse', not monitor:add(0/0,'x','x',1,false) and not monitor:add(1.5,'x','x',1,false))
monitor:remove(2,2)
check('serveur pur : depart identifie', monitor.left==1 and monitor:recent('leave',1)[1].player.display=='Bob')
for i=3,120 do monitor:add(i,'P'..i,'P'..i,i,false);monitor:remove(i,i+1) end
check('serveur pur : historique borne a 80', #monitor.events==80 and monitor.count==1)
local view=monitor:roster();view[1].name='Modifie'
check('serveur pur : snapshots independants', monitor.players[1].name=='A')
check('cash texte : libelle accentue et espace fine', Hub.cashText('Équilibre des mains : $1 234,50',false)==1234.5)
check('cash texte : RichText sans faux prix', Hub.cashText('<b>Cash: $120</b>',false)==120 and Hub.cashText('Buy: $120',true)==nil)
check('cash texte : montant seul seulement sur choix explicite', Hub.cashText('$500',false)==nil and Hub.cashText('$500',true)==500)
check('cash texte : formats invalides refuses', Hub.cashText('Cash: $1,2,3',false)==nil and Hub.cashText('Cash: $-10',false)==nil)
local finance=Hub.new(0);finance:observeCash(100,'wallet',0);finance:observeCash(120,'wallet',1);finance:observeCash(2000,'other',2)
check('cash sources : changement de compteur ne cree pas de gain', finance.money.observedIncreases==20 and finance.money.cash==2000)
local lib=Hub.new(0)
check('visee : metadonnees monde et viewport acceptees', lib:addSpot('A',exports.DEFAULT_DATA.fish,{x=10,y=20,world={1,2,3},viewport={x=800,y=600}}))
check('visee : monde non fini refuse', not lib:updateSpotAim('A',{x=10,y=20,world={1,0/0,3}}))
check('visee : viewport nul refuse', not lib:updateSpotAim('A',{x=10,y=20,viewport={x=0,y=600}}))
local restored=Hub.new(0)
check('visee : sauvegarde/restauration conserve le point monde', restored:loadLibrary(lib.library) and restored.library.spots.A.aim.world[3]==3)
check('cash texte : variantes explicites du portefeuille anglais', Hub.cashText('Hand balance: $900',false)==900 and Hub.cashText('Cash in hand: $1,200',false)==1200)
