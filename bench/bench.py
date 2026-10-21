"""Ultimate 1v1 benchmark against a scripted AI opponent.

Mock physics only (sim_fixture.lua): movement at 16 studs/s, a shot wind-up
of ShotDelay+0.12 s, jumper make chance inside the calibrated 57-72 stud
range, contest/strip/steal hazards and rebounds. It measures decision
quality of the Auto-play logic against fixed AI behaviours; it does not
model real Hoopz physics, server acceptance or human opponents.

Usage: python bench.py BUILD.lua PROFILE SEED POSSESSIONS [RESPONSE]
"""
import json, sys, os, pathlib
here = pathlib.Path(__file__).resolve().parent
TESTS = here if (here / 'sim_fixture.lua').exists() else here.parent / 'tests'
sys.path.insert(0, str(here)); sys.path.insert(0, str(TESTS))
if (here / 'liblua55.so').exists(): os.environ.setdefault('LUA_DLL', str(here / 'liblua55.so'))
from lua_runtime import run

BASE = dict(speed=16, delay=0.25, spacing=3.5, stealReach=4.0, steal=0.5, stripReach=4.5, strip=1.2,
            pick=3, breakChance=0.3, lo=55, hi=74, make=0.6, shootGap=6, patience=9, driveBias=0.25)
PROFILES = {
    'honest':     dict(BASE),
    'lockdown':   dict(BASE, speed=17, delay=0.15, spacing=3.0, steal=0.8, strip=1.6, breakChance=0.15),
    'tosser':     dict(BASE, toss=0.35),
    'magger':     dict(BASE, spacing=13, pick=18, stripReach=18, strip=2.5, stealReach=18),
}

def lua_table(d):
    return '{' + ','.join(f'{k}={v}' for k, v in d.items()) + '}'

def game(build, profile, seed, poss, response=''):
    src = pathlib.Path(build).read_text(encoding='utf-8')
    fixture = (TESTS / 'sim_fixture.lua').read_text(encoding='utf-8')
    lua = (here / 'arena.lua').read_text(encoding='utf-8')
    lua = (lua.replace('FIXTURE', fixture).replace('PROFILE', lua_table(PROFILES[profile]))
              .replace('TUNE', os.environ.get('TUNE','{}')).replace('RIMOVERRIDE', 'true' if os.environ.get('RIM') else 'false').replace('SEED', str(seed)).replace('DEBUG', 'true' if os.environ.get('BDEBUG') else 'false').replace('POSS', str(poss))
              .replace("RESPONSE", repr(response)).replace('SOURCE', '[====[' + src + ']====]'))
    return json.loads(run(lua).decode())

if __name__ == '__main__':
    build, profile, seed, poss = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    print(json.dumps(game(build, profile, seed, poss, sys.argv[5] if len(sys.argv) > 5 else '')))
