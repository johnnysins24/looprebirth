"""Rough auto-battle simulator for tuning the starting numbers in docs/design.

Run:  python3 tools/balance_sim.py
It prints, for each stat build, how much HP a fight costs at a given lap and how often
the hero beats the lap-10 boss when arriving with 80% HP. Numbers here must match
docs/design/04-hero-combat.md; change both together.
"""
import random
import statistics
import sys

BOSS_HP = int(sys.argv[1]) if len(sys.argv) > 1 else 950
BOSS_ATK = float(sys.argv[2]) if len(sys.argv) > 2 else 16

# Hero base and per-point gains (see 04-hero-combat.md)
BASE = dict(hp=100, atk=8, aps=0.8, eva=0.05, mana=30, mregen=2.0)
STR_ATK, STR_HP = 1, 6
AGI_AS, AGI_EVA = 0.05, 0.012
INT_AP, INT_MANA, INT_MREGEN = 2, 4, 0.15
MANA_PER_HIT = 3
START_MANA = 0.3
EVA_CAP = 0.6
APS_CAP = 3.0
POINTS_PER_LEVEL = 3

# Enemy scaling per lap (see data/enemies.csv)
SCALE_HP, SCALE_ATK, SCALE_DEF = 0.25, 0.12, 0.10
ENEMIES = {
    "slime": dict(hp=18, atk=2, aps=0.8, df=0, eva=0.00, n=3),
    "wolf": dict(hp=26, atk=3, aps=1.4, df=0, eva=0.10, n=2),
    "skeleton": dict(hp=40, atk=4, aps=0.8, df=3, eva=0.00, n=2),
    "bandit": dict(hp=34, atk=5, aps=1.0, df=1, eva=0.05, n=2),
}
BOSS = dict(hp=BOSS_HP, atk=BOSS_ATK, aps=1.0, df=4, eva=0.05, n=1, slam=0.12)

# Skill cards (see data/skills.csv). Index 0..2 = skill card level 1..3.
COST = dict(fireball=30, cleave=25, heal=40, haste=35, shield=35)
FIREBALL = [(10, 1.2), (18, 1.5), (30, 1.9)]          # flat, x AP
CLEAVE = [(1.0, 0.5), (1.3, 0.7), (1.7, 1.0)]          # x ATK, x AP
HEAL = [(0.10, 2.0), (0.14, 2.5), (0.20, 3.0)]         # x max HP, x AP
HASTE = [(0.50, 4.0), (0.60, 5.0), (0.75, 6.0)]        # attack speed bonus, seconds
SHIELD = [(15, 1.0, 5.0), (25, 1.3, 6.0), (40, 1.7, 7.0)]  # flat, x AP, seconds
SHIELD_CAP = 10.0  # no cap for now; a 0.4 cap made pure INT lose the boss (12%)


def skill_levels(lap):
    """Expected levels of the two equipped skill cards by this lap."""
    if lap >= 8:
        return (3, 2)
    if lap >= 5:
        return (2, 1)
    return (1, 1)


def items(lap):
    """Average gear the hero is expected to wear by this lap."""
    return dict(watk=3 + 2 * lap, ahp=15 + 10 * lap, ap=2 + 2 * lap, crit=0.05, critd=1.5)


def make_hero(build, level, lap):
    pts = POINTS_PER_LEVEL * (level - 1)
    s = dict(STR=0, AGI=0, INT=0)
    if build == "mix":
        s = dict(STR=pts // 3, AGI=pts // 3, INT=pts - 2 * (pts // 3))
    else:
        s[build] = pts
    it = items(lap)
    caster = build in ("INT", "mix")
    return dict(
        hp=BASE["hp"] + STR_HP * s["STR"] + it["ahp"],
        atk=BASE["atk"] + STR_ATK * s["STR"] + it["watk"],
        aps=min(APS_CAP, BASE["aps"] * (1 + AGI_AS * s["AGI"])),
        eva=min(EVA_CAP, BASE["eva"] + AGI_EVA * s["AGI"]),
        ap=INT_AP * s["INT"] + (it["ap"] if caster else 0),
        maxmana=BASE["mana"] + INT_MANA * s["INT"],
        mregen=BASE["mregen"] + INT_MREGEN * s["INT"],
        crit=it["crit"],
        critd=it["critd"],
        skills={"INT": ["shield", "fireball"], "mix": ["fireball", "cleave"]}.get(build, ["cleave", "haste"]),
        slvl=skill_levels(lap),
    )


def fight(h, etype, lap, elvl=1, boss=False, seed=0, hp_start=None, limit=120.0, dt=0.05):
    rng = random.Random(seed)
    e = BOSS if boss else ENEMIES[etype]
    kh = 1 if boss else 1 + SCALE_HP * (lap - 1)
    ka = 1 if boss else 1 + SCALE_ATK * (lap - 1)
    kd = 1 if boss else 1 + SCALE_DEF * (lap - 1)
    n = e["n"] + (elvl - 1)
    foes = [dict(hp=e["hp"] * kh, atk=e["atk"] * ka, aps=e["aps"], df=e["df"] * kd, eva=e["eva"],
                 t=rng.random() / e["aps"]) for _ in range(n)]
    hp = h["hp"] if hp_start is None else hp_start
    mana = START_MANA * h["maxmana"]
    t_att = haste = haste_bonus = shield = shield_t = tm = 0.0
    lv = dict(zip(h["skills"], h["slvl"]))
    while tm < limit:
        tm += dt
        alive = [f for f in foes if f["hp"] > 0]
        if not alive:
            return True, hp, tm
        mana = min(h["maxmana"], mana + h["mregen"] * dt)
        for sk in h["skills"]:
            if mana < COST[sk]:
                continue
            if sk == "heal" and hp > 0.5 * h["hp"]:
                continue
            if sk == "shield" and shield_t > 0:
                continue
            mana -= COST[sk]
            i = lv[sk] - 1
            if sk == "fireball":
                alive[0]["hp"] -= FIREBALL[i][0] + FIREBALL[i][1] * h["ap"]
            elif sk == "cleave":
                for f in alive:
                    f["hp"] -= max(1, CLEAVE[i][0] * h["atk"] - f["df"]) + CLEAVE[i][1] * h["ap"]
            elif sk == "heal":
                hp = min(h["hp"], hp + HEAL[i][0] * h["hp"] + HEAL[i][1] * h["ap"])
            elif sk == "haste":
                haste_bonus, haste = HASTE[i]
            elif sk == "shield":
                shield = min(SHIELD_CAP * h["hp"], SHIELD[i][0] + SHIELD[i][1] * h["ap"])
                shield_t = SHIELD[i][2]
            break
        haste = max(0.0, haste - dt)
        shield_t = max(0.0, shield_t - dt)
        if shield_t == 0:
            shield = 0.0
        aps = h["aps"] * (1 + haste_bonus if haste > 0 else 1)
        t_att += dt
        alive = [f for f in foes if f["hp"] > 0]
        if alive and t_att >= 1 / aps:
            t_att -= 1 / aps
            tgt = alive[0]
            if rng.random() >= tgt["eva"]:
                d = h["atk"] * (h["critd"] if rng.random() < h["crit"] else 1)
                tgt["hp"] -= max(1, d - tgt["df"])
            mana = min(h["maxmana"], mana + MANA_PER_HIT)
        for f in alive:
            f["t"] += dt
            if f["t"] >= 1 / f["aps"]:
                f["t"] -= 1 / f["aps"]
                if rng.random() >= h["eva"]:
                    dmg = f["atk"] * (2 if boss and rng.random() < e.get("slam", 0) else 1)
                    absorbed = min(shield, dmg)
                    shield -= absorbed
                    hp -= dmg - absorbed
        if hp <= 0:
            return False, 0.0, tm
    return False, hp, tm


BUILDS = ["STR", "AGI", "INT", "mix"]


def report(lap, level, elvl=1, runs=200):
    print(f"\nlap {lap}, hero L{level}, encounter L{elvl}: HP lost per fight")
    for b in BUILDS:
        h = make_hero(b, level, lap)
        cells = []
        for et in ENEMIES:
            res = [fight(h, et, lap, elvl, seed=s) for s in range(runs)]
            lost = statistics.mean(1 - r[1] / h["hp"] for r in res)
            cells.append(f"{et:8} {lost * 100:5.1f}%")
        print(f"  {b:4} | " + " | ".join(cells))


def boss_report(level, lap=10, runs=300):
    print(f"\nboss at lap {lap}, hero L{level}, arriving with 80% HP: win rate")
    for b in BUILDS:
        h = make_hero(b, level, lap)
        res = [fight(h, None, lap, boss=True, seed=s, hp_start=0.8 * h["hp"]) for s in range(runs)]
        print(f"  {b:4} | {sum(r[0] for r in res) / runs * 100:5.1f}%")


if __name__ == "__main__":
    for lap, lvl in [(1, 1), (5, 5), (10, 10)]:
        report(lap, lvl)
    report(10, 10, elvl=3)
    boss_report(10)
