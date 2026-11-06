-- Contrats purs de l'observatoire : echeances, provenances et bornes.
_G.__BLOCKSPIN_PURE_TEST=true
local H=load(SCRIPT_SOURCE,'=workspace-core')().Hub
check('timer : formats mm:ss et hh:mm:ss',H.parseDuration('04:32')==272 and H.parseDuration('01:04:32')==3872)
check('timer : unites et RichText',H.parseDuration('<b>2m 30s</b>')==150 and H.parseDuration('1h 2m 3s')==3723)
check('timer : prix et nombres nus non interpretes',H.parseDuration('250')==nil and H.parseDuration('$250')==nil)
check('timer : secondes invalides et infinis refuses',H.parseDuration('01:90')==nil and H.parseDuration(math.huge)==nil and H.parseDuration(-1)==nil)
check('croissance : decimales et bornes',H.parsePercent('35,5 %')==35.5 and H.parsePercent('100%')==100 and H.parsePercent('101%')==nil)
check('croissance : texte ambigu refuse',H.parsePercent('3 plantes 50%')==nil)
check('timer : formatage stable et arrondi conservateur',H.duration(61.1)=='01:02' and H.duration(3600)=='01:00:00' and H.duration(nil)=='N/D')
local t=H.newPlants('server-a')
local sample={serverKey='server-a',id='A',crop='Corn',owned=true,remaining=120,percent=50,position={10,0,0}}
check('plantes : premiere lecture reelle',t:observe(sample,10))
local r=t:rows(12,{0,0,0})[1]
check('plantes : compte a rebours et distance',r.remaining==118 and r.distance==10 and not r.estimated)
t:observe(sample,20)
check('plantes : relire la meme valeur ne repousse pas le timer',t:rows(20)[1].remaining==110 and t.plots.A.deadline==130)
check('plantes : source figee explicitement estimee',t:rows(20)[1].estimated and t:rows(20)[1].projectedPercent>50)
check('plantes : echeance sans maturite observee ne prouve pas prete',not t:rows(140)[1].ready and t:rows(140)[1].status=='Echeance estimee')
local bad=H.copy(sample);bad.owned=false
check('plantes : propriete non confirmee refusee',not t:observe(bad,21))
bad=H.copy(sample);bad.serverKey='server-b'
check('plantes : autre serveur refuse',not t:observe(bad,21) and t.plots.A.deadline==130)
bad=H.copy(sample);bad.position={0/0,0,0};bad.remaining=110
check('plantes : position invalide rejetee sans mutation',not t:observe(bad,21) and t.plots.A.seconds==120)
sample.remaining=30;sample.percent=90;t:observe(sample,22)
check('plantes : acceleration recale le timer',t.plots.A.deadline==52)
local alerts=t:alerts(23,60)
check('plantes : alerte seuil dedoublonnee',#alerts==1 and alerts[1].kind=='soon' and #t:alerts(24,60)==0)
sample.remaining=0;sample.percent=100;t:observe(sample,52)
check('plantes : maturite observee distincte',t:rows(52)[1].ready and t:alerts(52,60)[1].kind=='ready')
t:observe(sample,60)
check('plantes : maturite relue conservee sans faux redemarrage',not t:rows(60)[1].estimated and t.plots.A.generation==1)
sample.remaining=240;sample.percent=0;t:observe(sample,61)
check('plantes : redemarrage remet les alertes a zero',t.plots.A.generation==2 and next(t.plots.A.alerts)==nil)
t.plots.A.missing=true
check('plantes : streaming absent conserve un suivi estime',t:rows(61)[1].estimated and not t:remove('A',false))
sample.id='B';sample.crop='Pumpkin';sample.remaining=50;sample.percent=80;t:observe(sample,62)
check('plantes : tri par prochaine echeance',t:rows(62)[1].id=='B')
check('plantes : regroupement par culture',t:rows(62,nil,true)[1].id=='A')
check('plantes : retrait explicite uniquement',t:remove('B',true) and not t.plots.B)
local summary=H.pingSummary({10,20,false,30,40})
check('ping : min mediane moyenne max sans valeurs absentes',summary.min==10 and summary.median==25 and summary.mean==25 and summary.max==40 and summary.count==4)
check('ping : absence reste inconnue',H.pingSummary({false}).mean==nil)
local server=H.newServer(0,30);server:add(1,'Alpha','Premier',1,true);server:add(2,'Beta','Deuxieme',2,false)
check('serveur : recherche username ou display sans motif Lua',#H.filterRoster(server,'premier','name',{})==1 and #H.filterRoster(server,'[','name',{})==0)
check('serveur : tri recence et amis',H.filterRoster(server,'','recent',{})[1].id==2 and H.filterRoster(server,'','friends',{[2]=true})[1].id==2)
local payload={data={{id='here',playing=1,maxPlayers=30},{id='one',playing=5,maxPlayers=30},{id='two',playing=30,maxPlayers=30},{id='one',playing=1,maxPlayers=30},{id='bad',playing=31,maxPlayers=30}},nextPageCursor='abc + /'}
local rows,cursor=H.validateServers(payload,'here',1,10)
check('serveurs publics : filtres places libres/population, courant et doublons',#rows==1 and rows[1].id=='one' and cursor=='abc + /')
check('serveurs publics : schema et curseur rejetes',H.validateServers({data={},nextPageCursor={}},'',0,100)==nil and H.validateServers({},'',0,100)==nil)
local valid={schema=1,serverKey='server-a',favorites={{job='abc-def',place=100,name='Mon serveur'}},sessions={{id='session-1',at=100,elapsed=60,increases=100,decreases=50,job='abc-def',place=100}},plants={{id='A',crop='Corn',remaining=50,percent=20,savedAt=100}}}
local parsed=H.validWorkspace(valid)
check('observatoire : validation et copie des donnees locales',parsed and parsed.favorites[1].name=='Mon serveur' and parsed~=valid)
valid.plants[1].percent=101
check('observatoire : rejet atomique plante corrompue',H.validWorkspace(valid)==nil)
valid.plants={};valid.favorites[2]=H.copy(valid.favorites[1])
check('observatoire : favoris dupliques refuses',H.validWorkspace(valid)==nil)
local q=H.validateQueue({{kind='pause',timeout=2},{kind='route',name='Vendeur',timeout=600}})
check('file : plan borne et copie independante',q and #q==2)
check('file : timeout, destination et type requis',H.validateQueue({{kind='route',timeout=1}})==nil and H.validateQueue({{kind='unknown',timeout=1}})==nil and H.validateQueue({{kind='pause',timeout=0}})==nil)
for i=1,55 do t:observe({serverKey='server-a',id='P'..i,crop='Corn',owned=true,remaining=i,percent=50},100+i) end
check('plantes : historique et nombre de parcelles bornes',#t:rows(200)==50 and #t.events<=80)
