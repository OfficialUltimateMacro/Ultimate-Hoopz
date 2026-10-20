"""Run the benchmark suite: builds x profiles x seeds, aggregate per build/profile."""
import json, sys, os, pathlib, multiprocessing as mp
here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
import bench
SEEDS = list(range(1, int(os.environ.get('SEEDS', '8')) + 1))
POSS = int(os.environ.get('POSS', '20'))
def one(args):
    build, profile, seed = args
    try: return (build, profile, seed, bench.game(build, profile, seed, POSS))
    except Exception as ex: return (build, profile, seed, {'error': str(ex)[:300]})
def agg(games):
    keys = ['poss','pts','jA','jRel','jMade','stripped','dA','dMade','dBlocked','stolen','clock','oreb','dreb']
    t = {side: {k: sum(g[side].get(k, 0) for g in games) for k in keys} for side in ('us', 'them')}
    return t
def summary(build, profile, games):
    ok = [g for g in games if 'error' not in g]
    t = agg(ok); u, h = t['us'], t['them']
    pp = lambda x: x['pts'] / max(1, x['poss'])
    wins = sum(1 for g in ok if g['us']['pts'] > g['them']['pts'])
    return dict(build=build, profile=profile, games=len(ok), errors=len(games) - len(ok), wins=wins,
        ppp_us=round(pp(u), 3), ppp_them=round(pp(h), 3), margin=round(pp(u) - pp(h), 3),
        us_jumpers=f"{u['jMade']}/{u['jRel']} rel of {u['jA']}", us_stripped=u['stripped'],
        us_dunks=f"{u['dMade']}/{u['dA']}", us_stolen=u['stolen'], us_clock=u['clock'],
        them_dunks=f"{h['dMade']}/{h['dA']}", them_jumpers=f"{h['jMade']}/{h['jRel']}",
        reb_us=f"{u['oreb']} off / {u['dreb']} def", reb_them=f"{h['oreb']} off / {h['dreb']} def",
        detect=[g['level'] for g in ok], notices=sum(g['notices'] for g in ok), rimOnly=sum(1 for g in ok if g['rimOnly']))
if __name__ == '__main__':
    builds = sys.argv[1].split(',')
    profiles = sys.argv[2].split(',') if len(sys.argv) > 2 else list(bench.PROFILES)
    jobs = [(b, p, s) for b in builds for p in profiles for s in SEEDS]
    with mp.Pool(int(os.environ.get('JOBS', os.cpu_count()))) as pool:
        res = pool.map(one, jobs)
    out = []
    for b in builds:
        for p in profiles:
            out.append(summary(b, p, [r[3] for r in res if r[0] == b and r[1] == p]))
    print(json.dumps(out, indent=1))
    pathlib.Path(os.environ.get('OUT', 'suite.json')).write_text(json.dumps({'summary': out, 'games': [list(r) for r in res]}))
