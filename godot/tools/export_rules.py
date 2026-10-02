"""Golden data from the HTML game (polderrace-3d.html) for the game rules of the Godot port.

Writes godot/tests/golden/rules.json: scripted scenarios (inputs) and what the HTML game makes of them (outputs): credits
per mode/position/laps/difficulty, championship points and standings with ties, the career (results, bonuses, what opens,
achievements), the achievements at the end of a race, rival tuning, result order and position, elimination, lap and
checkpoint messages with the records they save, the save keys, number formats, upgrade prices, event lines and the
career fields. The Godot test (tests/test_rules.gd) runs the same inputs through the port and compares.
usage: python godot/tools/export_rules.py   (needs the HTML test setup: pip -r requirements-dev.txt, playwright)
"""
import json, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT

DIFFS = ['easy', 'normal', 'hard', 'extreme']
I = {}

# ---- credits: awardCredits(pos) per mode
cr = []
for mode in ['race', 'elim', 'champ']:
    for diff in DIFFS:
        for laps in [1, 2, 3, 5]:
            for pos in [0, 1, 2, 3, 4, 5, 8, 9]:
                c = {'mode': mode, 'diff': diff, 'laps': laps, 'pos': pos}
                if mode == 'champ':
                    c['cdiff'] = 'easy' if diff == 'hard' else 'hard'   # a championship pays at its own difficulty
                cr.append(c)
for d in [0, 999, 1234.5, 5000, 12345]:
    cr.append({'mode': 'time', 'diff': 'hard', 'laps': 3, 'pos': 0, 'dist': d})
for nl in [0, 1, 3]:
    for gs in [False, True]:
        cr.append({'mode': 'ghost', 'diff': 'extreme', 'laps': 3, 'pos': 0, 'nl': nl, 'gs': gs})
I['credits'] = cr

# ---- championship: three rounds with ties (you first on a tie, the others in their order)
I['champ'] = {'bots': [{'name': n, 'type': t, 'color': '#1d4f9e'} for n, t in
                       [('Henk', 'gt'), ('Ingrid', 'muscle'), ('Daan', 'fastback'), ('Fenna', 'sedan'), ('Kees', 'wagon')]],
              'orders': [['Henk', 'Jij', 'Ingrid', 'Daan', 'Fenna', 'Kees'], ['Jij', 'Henk', 'Kees', 'Fenna', 'Ingrid', 'Daan'],
                         ['Kees', 'Fenna', 'Daan', 'Ingrid', 'Henk', 'Jij']]}

# ---- career: a whole run with failed and passed events
I['career'] = [['b1', 4], ['b1', 3], ['b2', 1], ['b3', 3], ['b3', 2], ['b4', 2], ['b4', 1], ['B', 4], ['B', 3], ['B', 1], ['a1', 1],
               ['a2', 2], ['a3', 1], ['a4', 1], ['A', 2], ['s1', 1], ['s2', 3], ['s3', 2], ['s4', 1], ['S', 1], ['l1', 1], ['l2', 2],
               ['l2', 1], ['l3', 1], ['L', 2], ['L', 1]]
I['owned'] = [[{'hatch': True}, {}, 'gt'], [{'hatch': True, 'gt': True, 'super': True}, {'A': 'gt'}, 'evo'],
              [{'hatch': True, 'muscle': True, 'gt': True}, {}, 'evo'], [{'hatch': True, 'super': True}, {'S': 'super'}, 'evo'],
              [{'super': True}, {}, 'hatch'], [{}, {}, 'gt'], [{'rally': True}, {'B': 'mini'}, 'xyz'], [{'gt': True}, {}, 'gt']]
I['defs'] = [['b1', '#f36f21'], ['b4', '#d62a2a'], ['a3', '#1d4f9e'], ['l2', '#1d4f9e'], ['l3', '#f2c200'], ['L', '#1b1b1b']]

# ---- achievements at the end of a race
I['ach'] = [{'pos': 1, 'mode': 'race', 'time': 'day', 'weather': 'dry', 'contacts': 0, 'grid': 'back', 'bots': 5},
            {'pos': 1, 'mode': 'race', 'time': 'night', 'weather': 'rain', 'contacts': 3, 'grid': 'pole', 'bots': 3},
            {'pos': 2, 'mode': 'race', 'time': 'night', 'weather': 'rain', 'contacts': 0, 'grid': 'back', 'bots': 7},
            {'pos': 1, 'mode': 'elim', 'time': 'dusk', 'weather': 'fog', 'contacts': 0, 'grid': 'back', 'bots': 5},
            {'pos': 1, 'mode': 'champ', 'time': 'night', 'weather': 'dry', 'contacts': 1, 'grid': 'back', 'bots': 5},
            {'pos': 1, 'mode': 'ghost', 'time': 'night', 'weather': 'rain', 'contacts': 0, 'grid': 'back', 'bots': 0},
            {'pos': 1, 'mode': 'time', 'time': 'day', 'weather': 'dry', 'contacts': 0, 'grid': 'back', 'bots': 0},
            {'pos': 1, 'mode': 'race', 'time': 'day', 'weather': 'dry', 'contacts': 2, 'grid': 'back', 'bots': 4, 'wins': 'others'},
            {'pos': 1, 'mode': 'race', 'time': 'dusk', 'weather': 'rain', 'contacts': 0, 'grid': 'mid', 'bots': 6}]

# ---- rival tuning
I['rival'] = [{'cars': {}, 'car': 'gt', 'p2car': 'hatch', 'split': False},
              {'cars': {'gt': {'eng': 3, 'turbo': 2, 'tyre': 1, 'brake': 0}}, 'car': 'gt', 'p2car': 'hatch', 'split': False},
              {'cars': {'gt': {'eng': 3, 'turbo': 2, 'tyre': 1, 'brake': 0}, 'hatch': {'eng': 1, 'turbo': 0, 'tyre': 3, 'brake': 2}},
               'car': 'gt', 'p2car': 'hatch', 'split': True}]

# ---- result order and position (fake bots: only the fields the order uses)
def bot(n, t, lap, s, fin=False, ft=0, out=False, ep=0, best=0):
    return {'name': n, 'type': t, 'lap': lap, 's': s, 'finished': fin, 'finishTime': ft, 'out': out, 'elimPos': ep, 'bestLap': best}
I['order'] = [
    {'mode': 'race', 'laps': 2, 'pl': {'lap': 3, 's': 40, 'done': True, 'out': False, 'ft': 102.5, 'ep': 0, 'best': 50.1},
     'bots': [bot('Henk', 'gt', 3, 60, True, 100, best=49.5), bot('Ingrid', 'muscle', 2, 500), bot('Daan', 'evo', 3, 20, True, 105.25),
              bot('Fenna', 'sedan', 2, 800, best=51)]},
    {'mode': 'race', 'laps': 3, 'pl': {'lap': 1, 's': 300, 'done': False, 'out': False, 'ft': 0, 'ep': 0, 'best': 0},
     'bots': [bot('Henk', 'gt', 1, 250), bot('Ingrid', 'muscle', 0, 1900), bot('Daan', 'evo', 1, 310), bot('Fenna', 'sedan', 2, 5)]},
    {'mode': 'elim', 'laps': 4, 'pl': {'lap': 3, 's': 100, 'done': True, 'out': True, 'ft': 150, 'ep': 3, 'best': 44},
     'bots': [bot('Henk', 'gt', 4, 60), bot('Ingrid', 'muscle', 2, 500, out=True, ep=5), bot('Daan', 'evo', 4, 80),
              bot('Fenna', 'sedan', 3, 50, out=True, ep=4)]}]

# ---- elimination after a lap
I['elim'] = [{'pl': {'lap': 3, 's': 100}, 'bots': [bot('Henk', 'gt', 2, 900), bot('Ingrid', 'muscle', 2, 50), bot('Daan', 'evo', 3, 10)]},
             {'pl': {'lap': 2, 's': 30}, 'bots': [bot('Henk', 'gt', 3, 20), bot('Ingrid', 'muscle', 2, 50), bot('Daan', 'evo', 2, 400)]},
             {'pl': {'lap': 2, 's': 30}, 'bots': [bot('Henk', 'gt', 2, 20), bot('Ingrid', 'muscle', 1, 0, out=True, ep=3)]},
             {'pl': {'lap': 1, 's': 30}, 'bots': [bot('Henk', 'gt', 1, 20), bot('Ingrid', 'muscle', 1, 50)]}]

# ---- laps and checkpoints: messages, lap times and the records they save
I['laps'] = [{'mode': 'race', 'laps': 3, 'car': 'gt', 'times': [1.0, 63.25, 125.5, 186.0, 250.0]},
             {'mode': 'elim', 'laps': 3, 'car': 'super', 'times': [0.5, 70.0, 131.04]},
             {'mode': 'time', 'car': 'hatch', 'cps': [1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 0],
              'clock': [10, 20, 30, 40, 50, 85.37, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155, 160, 165, 170]}]

# ---- save keys, number formats, prices, event lines
I['keys'] = {'tracks': ['polder', 'dorp', 'circuit', 'afsluitdijk', 'haven', 'veluwe', 'grachten', 'limburg', 'rotterdam', 'zeeland'],
             'ids': [['polder', 'fwd', 'gt'], ['dorp', 'rev', 'super'], ['zeeland', 'fwd', 'hatch']]}
# (2.25, 1250 m, 0.125: exactly halfway, where JS toFixed rounds up and printf to even)
I['fmt'] = {'lap': [0, 0.05, 0.25, 9.95, 9.96, 59.94, 59.96, 60, 61.04, 62.25, 62.75, 125.55, 599.99, 3599.99],
            'km': [0, 49, 50, 250, 1234.5, 1250, 5000, 99999], 'cr': [0, 5, 999, 1000, 20000.5, 1234567],
            'd': [0, -0.004, 0.125, 1.234, -2.375, -12.345, 0.5, 3.75]}

JS = r"""(()=>{const I=INPUT,O={};
const keep={mode,raceLaps,distance,lapTimes,ghostSaved,champ,resultRows,bots,split,state,raceMode,raceDone,raceFinishTime,playerOut,elimPos,raceBestLap,
  lapStart,raceTime,clock,checkpoints,timeLeft,elimDone,nextCp,lapRecordSet,raceContacts,
  settings:JSON.stringify(settings),garage:JSON.stringify(garage),env:JSON.stringify(env),pl:JSON.stringify({lap:player.lap,s:player.s})};
const r6=v=>Math.round(v*1e6)/1e6;
/* credits */
O.credits=I.credits.map(c=>{mode=c.mode;settings.diff=c.diff;raceLaps=c.laps;distance=c.dist||0;lapTimes=Array(c.nl||0).fill(60);ghostSaved=!!c.gs;
  champ=c.cdiff?{diff:c.cdiff}:null;garage.credits=0;return awardCredits(c.pos);});
/* championship */
{champ={nRounds:6,active:true,car:'gt',color:'#ffffff',cls:'A',diff:'normal',round:0,bots:I.champ.bots,pts:{Jij:0},history:[]};I.champ.bots.forEach(d=>champ.pts[d.name]=0);
 O.champ=I.champ.orders.map(o=>{resultRows=o.map(n=>n==='Jij'?{me:true,name:'Jij'}:{name:n});champRecordRace();
   return {round:champ.round,st:champStandings().map(r=>[r.name,r.pts,r.car,r.me])};});
 O.champHist=champ.history;store.set('polderrace3d-champ','null');}
/* career */
{garage.career={cups:{},bonus:{}};garage.ach={};garage.credits=0;garage.owned={hatch:true};store.set('polderrace3d-career-run','null');
 O.career=I.career.map(([id,pos])=>{const ev=CAREER_EVS.find(e=>e.id===id),res=careerEventDone(ev,pos),nx=careerNext();
   return {res,credits:garage.credits,next:nx?nx.id:null,open:CAREER_EVS.filter(evUnlocked).map(e=>e.id),chs:CHAPTERS.filter(chUnlocked).map(c=>c.id)};});
 O.careerCups=garage.career.cups;O.careerBonus=garage.career.bonus;O.careerAch=Object.keys(garage.ach).sort();
 O.evSub=CAREER_EVS.map(e=>[e.id,evSub(e),goalText(e.goal)]);}
O.owned=I.owned.map(([own,lb,id])=>{garage.owned=own;settings.lastByClass=lb;return ownedCar(id);});
O.defs=I.defs.map(([id,col])=>{settings.color=col;settings.car='gt';return careerDefs(CAREER_EVS.find(e=>e.id===id)).map(d=>[d.name,d.color,!!d.rival,d.rival?d.type:'']);});
{settings.car='evo';O.botDefs=[0,1,2].map(k=>{settings.color=COLORS[k*2];return makeBotDefs(7).map(d=>[d.name,d.color,CARS[d.type].cls]);});}
/* achievements */
O.ach=I.ach.map(a=>{garage.ach={};garage.wins={};if(a.wins==='others')for(const t in TRACKS)if(t!==TRACK_ID)garage.wins[t]=true;
  mode=a.mode;env.time=a.time;env.weather=a.weather;raceContacts=a.contacts;settings.grid=a.grid;bots=Array(a.bots).fill({});achRaceEnd(a.pos);
  return {ach:Object.keys(garage.ach).sort(),wins:Object.keys(garage.wins).sort()};});
/* rival tuning */
O.rival=I.rival.map(c=>{garage.cars=JSON.parse(JSON.stringify(c.cars));settings.car=c.car;settings.p2car=c.p2car;split=c.split;const r=rivalBoost();
  return [r6(r.vmax),r6(r.acc),r6(r.grip),r6(r.brake)];});
split=false;
/* result order and position */
O.order=I.order.map(c=>{mode=c.mode;raceLaps=c.laps;bots=c.bots.map(b=>Object.assign({},b));player.lap=c.pl.lap;player.s=c.pl.s;raceDone=c.pl.done;playerOut=c.pl.out;
  raceFinishTime=c.pl.ft;elimPos=c.pl.ep;raceBestLap=c.pl.best;return {rows:resultOrder().map(r=>[r.name,r.car,!!r.finished,!!r.out]),pos:playerPosition()};});
/* elimination */
O.elim=I.elim.map(c=>{mode='elim';state='racing';raceDone=false;playerOut=false;elimDone=0;elimPos=0;raceTime=77;bots=c.bots.map(b=>Object.assign({},b));
  player.lap=c.pl.lap;player.s=c.pl.s;$('msg').textContent='';elimCheck();
  return {bots:bots.map(b=>[b.name,!!b.out,b.elimPos||0,b.outAt||0]),playerOut,elimPos,raceDone,state,msg:$('msg').textContent,elimDone};});
/* laps and checkpoints */
bots=[];
O.laps=I.laps.map(c=>{settings.car=c.car;mode=c.mode;raceMode=mode!=='time';state='racing';raceDone=false;playerOut=false;raceLaps=c.laps||3;player.lap=0;lapStart=0;lapTimes=[];
  raceBestLap=0;lapRecordSet=false;checkpoints=0;timeLeft=10;ghostSaved=false;
  for(const k of [lapKey(TRACK_ID),lapKey(TRACK_ID)+'-car',lapCarKey(TRACK_ID)])store.set(k,'0');
  const msgs=[];const n=(c.times||c.cps).length;
  for(let i=0;i<n;i++){if(c.times)raceTime=c.times[i];else clock=c.clock[i];$('msg').textContent='';hitCheckpoint(c.times?0:c.cps[i]);msgs.push([$('msg').textContent,state,player.lap,r6(timeLeft)]);}
  return {msgs,lapTimes:lapTimes.map(r6),best:r6(raceBestLap),rec:lapRecordSet,cps:checkpoints,store:[lapKey(TRACK_ID),lapCarKey(TRACK_ID)].map(k=>[k,store.get(k,'?'),store.get(k+'-car','?')])};});
/* save keys */
O.tv=I.keys.tracks.map(t=>[tv(t,'fwd'),tv(t,'rev')]);
O.keys=I.keys.ids.map(([id,dir,c])=>{settings.dir=dir;settings.car=c;return [bestKey(id),lapKey(id),lapCarKey(id),ghostKey(id),bestKey(id,'S'),lapCarKey(id,'mini')];});
/* formats and prices */
O.fmt={lap:I.fmt.lap.map(fmtLap),km:I.fmt.km.map(fmtKm),cr:I.fmt.cr.map(fmtCr),d:I.fmt.d.map(fmtD)};
O.upCost=Object.keys(CARS).filter((id,k)=>k%3===0).map(id=>[id,UPG.map(u=>[0,1,2].map(l=>upCost(id,u,l)))]);
O.effStats=(()=>{garage.cars={gt:{eng:3,turbo:2,tyre:1,brake:3}};const e=effStats('gt');return [r6(e.vmax),r6(e.acc),r6(e.grip),r6(e.brake)];})();
/* put the game back */
mode=keep.mode;raceLaps=keep.raceLaps;distance=keep.distance;lapTimes=keep.lapTimes;ghostSaved=keep.ghostSaved;champ=keep.champ;resultRows=keep.resultRows;bots=keep.bots;
split=keep.split;state=keep.state;raceMode=keep.raceMode;raceDone=keep.raceDone;raceFinishTime=keep.raceFinishTime;playerOut=keep.playerOut;elimPos=keep.elimPos;
raceBestLap=keep.raceBestLap;lapStart=keep.lapStart;raceTime=keep.raceTime;checkpoints=keep.checkpoints;timeLeft=keep.timeLeft;elimDone=keep.elimDone;
nextCp=keep.nextCp;lapRecordSet=keep.lapRecordSet;raceContacts=keep.raceContacts;Object.assign(settings,JSON.parse(keep.settings));garage=JSON.parse(keep.garage);
Object.assign(env,JSON.parse(keep.env));player.lap=JSON.parse(keep.pl).lap;player.s=JSON.parse(keep.pl).s;
return JSON.stringify(O);})()"""

with Session(DEFAULT, w=640, h=400) as s:
    s.ev("toMenu(-1);loadTrack('polder','fwd');0")
    out = json.loads(s.ev(JS.replace('INPUT', json.dumps(I))))
    if s.errs:
        print('\n'.join(s.errs[:10]))
(ROOT / 'godot/tests/golden/rules.json').write_text(json.dumps({'in': I, 'out': out}, ensure_ascii=False, indent=0))
print('ok', ', '.join(f'{k}: {len(v) if isinstance(v, list) else 1}' for k, v in out.items()))
