"""装配最终 token 表：3 个方向 × 2 套模式，并做全量校验。

关键设计决定：**语义层与图表层三套共用**。
竞品里也是这样 —— 收入绿/支出红/警告琥珀几乎跨品牌一致，品牌个性只体现在
「中性面 + 主色」。反过来，如果连语义色都跟着方案变，用户换主题就要重新学习
一遍颜色含义。
"""
import json
from theme_solve import oklch_to_hex, contrast, cvd_delta_e

# ── 求解出来的语义层（三套共用） ──────────────────────────────
SEM_LIGHT = {  # H, L, C
    "income": (146.9, 0.443, 0.126),
    "expense": (31.4, 0.494, 0.113),
    "transfer": (216.5, 0.476, 0.133),
    "credit": (325.3, 0.470, 0.125),
    "warning": (85.2, 0.446, 0.100),
    "focus": (180.7, 0.466, 0.108),
}
SEM_DARK = {
    "income": (148.6, 0.765, 0.108),
    "expense": (25.9, 0.788, 0.126),
    "transfer": (213.0, 0.780, 0.114),
    "credit": (312.2, 0.806, 0.119),
    "warning": (85.7, 0.717, 0.128),
    "focus": (188.7, 0.766, 0.106),
}

# ── 图表层（三套共用）：环上相邻最优排列 + 明暗交替冗余编码 ────
CHART_HUES_LIGHT = [31, 180, 285, 147, 325, 205, 85, 250]
CHART_HUES_DARK = [31, 180, 285, 147, 325, 205, 85, 250]
CHART_L_LIGHT, CHART_C_LIGHT, CHART_STEP_LIGHT = 0.600, 0.130, 0.055
CHART_L_DARK, CHART_C_DARK, CHART_STEP_DARK = 0.780, 0.118, 0.062

# ── 三个方向：只有中性面与主色不同 ────────────────────────────
SCHEMES = {
    "A": dict(name="砚青 Graphite", nh=250, nc=0.006, ph=250, pc=0.128,
              desc="冷灰石面 + 钢蓝。中性面几乎无彩，把画面让给分类色与金额语义色。"),
    "B": dict(name="陶土 Terra", nh=68, nc=0.011, ph=45, pc=0.108,
              desc="暖砂纸面 + 赭陶。手账气质，长时间阅读最不刺眼。"),
    "C": dict(name="夜屿 Nocturne", nh=265, nc=0.008, ph=268, pc=0.140, deep=0.035,
              desc="近黑中性 + 蓝紫主色。深色优先，科技感与高端感最强。"),
}

SEM_KEYS = ["income", "expense", "transfer", "credit", "warning"]



def solve_hero(ph, pc):
    """为三张 Hero 卡（净资产 / 品牌 / 超支）搜索色相，使三者两两可分辨。

    超支色**写死成红**（352→8→24）：它是语义色，不能跟着品牌方案走 ——
    用户换主题不该重新学一遍「超支是什么颜色」。所以让另外两张卡去避让它。

    暖主色的方案（陶土）在这里最容易翻车：主色赭 45° 与红只差 20° 出头，
    按公式推导出的渐变会撞成一坨，所以候选里也放进「不跟随主色的固定冷色」。
    """
    net_options = [
        ([ph - 30, ph + 5, ph + 45], True), ([ph + 20, ph + 40, ph + 60], True),
        ([ph - 45, ph - 20, ph + 10], True), ([ph, ph + 25, ph + 50], True),
        ([ph + 60, ph + 85, ph + 110], True), ([ph - 70, ph - 50, ph - 30], True),
        ([200, 225, 250], False), ([230, 255, 280], False), ([168, 192, 216], False),
    ]
    brand_options = [
        ([ph + 8, ph - 6, ph - 18], True), ([ph - 50, ph - 35, ph - 20], True),
        ([ph + 45, ph + 60, ph + 75], True), ([ph + 85, ph + 70, ph + 55], True),
        ([ph - 85, ph - 70, ph - 55], True), ([ph + 15, ph + 30, ph + 45], True),
        ([ph, ph + 12, ph + 24], True),
        ([160, 180, 200], False), ([196, 216, 236], False),
    ]
    danger = [-8, 8, 24]
    best = None
    for nh_, nf in net_options:
        for bh, bf in brand_options:
            stops = {"netWorth": [0.40, 0.46, 0.44], "brand": [0.30, 0.38, 0.46],
                     "danger": [0.38, 0.42, 0.46]}
            chroma = {"netWorth": [pc * 1.05, pc * 1.15, 0.118],
                      "brand": [pc * 0.85, pc * 0.95, pc * 0.90],
                      "danger": [0.150, 0.165, 0.150]}
            hues = {"netWorth": nh_, "brand": bh, "danger": danger}
            mids, ok = {}, True
            for g in hues:
                cols = [oklch_to_hex(stops[g][i], chroma[g][i], hues[g][i])
                        for i in range(3)]
                for c in cols:
                    if contrast("#FFFFFF", c) < 4.5:
                        ok = False
                mids[g] = cols[1]
            if not ok:
                continue
            worst = min(cvd_delta_e(mids[a], mids[b]) for a, b in
                        __import__("itertools").combinations(mids, 2))
            obj = worst + (0.012 if nf else 0) + (0.012 if bf else 0)
            if best is None or obj > best[0]:
                best = (obj, {"netWorth": nh_, "brand": bh, "danger": danger})
    return best


def hero_stops(H, pc, dark):
    stops = {"netWorth": [0.40, 0.46, 0.44], "brand": [0.30, 0.38, 0.46],
             "danger": [0.38, 0.42, 0.46]}
    chroma = {"netWorth": [pc * 1.05, pc * 1.15, 0.118],
              "brand": [pc * 0.85, pc * 0.95, pc * 0.90],
              "danger": [0.150, 0.165, 0.150]}
    shift = 0.02 if dark else 0.0
    out = {g: [oklch_to_hex(stops[g][i] + shift, chroma[g][i], H[g][i])
               for i in range(3)] for g in H}
    out["amber"] = oklch_to_hex(0.880, 0.110, 90)
    return out


def build(mode):
    dark = mode == "dark"
    out = {}
    for key, cfg in SCHEMES.items():
        nh, nc, ph, pc = cfg["nh"], cfg["nc"], cfg["ph"], cfg["pc"]

        def n(L, cs=1.0, h=None):
            return oklch_to_hex(L, nc * cs, nh if h is None else h)

        H = solve_hero(ph, pc)[1]
        if dark:
            deep = cfg.get("deep", 0.0)
            P = dict(
                sunken=n(0.155 - deep, 0.85), background=n(0.205 - deep, 1.0),
                surface=n(0.255 - deep, 1.05), raised=n(0.305 - deep, 1.15),
                outline=n(0.625, 2.8), outlineVariant=n(0.400, 1.5),
                text=n(0.930, 0.55), textSecondary=n(0.742, 1.05),
                primary=oklch_to_hex(0.790, pc * 0.95, ph),
                primaryFill=oklch_to_hex(0.700, pc * 0.85, ph),
                onPrimaryFill=n(0.150, 1.0),
                primaryContainer=oklch_to_hex(0.335, pc * 0.55, ph),
                onPrimaryContainer=oklch_to_hex(0.875, pc * 0.62, ph),
                secondary=oklch_to_hex(0.760, pc * 0.30, ph),
                tertiary=oklch_to_hex(0.800, 0.075, ph - 55),
            )
            sem = {k: oklch_to_hex(v[1], v[2], v[0]) for k, v in SEM_DARK.items()}
            chart = [oklch_to_hex(CHART_L_DARK - (CHART_STEP_DARK if i % 2 else 0),
                                  CHART_C_DARK, h)
                     for i, h in enumerate(CHART_HUES_DARK)]
            hero = hero_stops(H, pc, dark=True)
            cont_l, cont_c = 0.300, 0.055
        else:
            P = dict(
                sunken=n(0.896, 1.35), background=n(0.930, 0.90),
                surface=n(0.995, 0.35), raised=n(0.968, 0.55),
                outline=n(0.600, 3.2), outlineVariant=n(0.872, 1.1),
                text=n(0.225, 1.2), textSecondary=n(0.455, 1.25),
                primary=oklch_to_hex(0.452, pc, ph),
                primaryFill=oklch_to_hex(0.470, pc * 1.18, ph),
                onPrimaryFill=n(0.995, 0.35),
                primaryContainer=oklch_to_hex(0.930, pc * 0.42, ph),
                onPrimaryContainer=oklch_to_hex(0.400, pc * 0.88, ph),
                secondary=oklch_to_hex(0.520, pc * 0.28, ph),
                tertiary=oklch_to_hex(0.560, 0.058, ph - 55),
            )
            sem = {k: oklch_to_hex(v[1], v[2], v[0]) for k, v in SEM_LIGHT.items()}
            chart = [oklch_to_hex(CHART_L_LIGHT - (CHART_STEP_LIGHT if i % 2 else 0),
                                  CHART_C_LIGHT, h)
                     for i, h in enumerate(CHART_HUES_LIGHT)]
            hero = hero_stops(H, pc, dark=False)
            cont_l, cont_c = 0.935, 0.048

        # 语义容器层（chip / tag 的淡底）：现有体系缺这一层，导致 tag 只能用
        # 带透明度的语义色硬凑，深色模式下会发灰。
        containers = {}
        for k in SEM_KEYS + ["focus"]:
            h, _, _ = (SEM_DARK if dark else SEM_LIGHT)[k]
            containers[k] = oklch_to_hex(cont_l, cont_c, h)
        P.update(sem)
        P.update({f"{k}Container": v for k, v in containers.items()})
        P["chart"] = chart
        P.update(hero)
        out[key] = P
    return out


def validate(all_p):
    bad = []
    for sk, P in all_p.items():
        for mode in ("light", "dark"):
            pass
    for sk, P in all_p.items():
        surfaces = ["background", "surface", "raised", "sunken"]
        fgs = ["text", "textSecondary", "primary"] + SEM_KEYS + ["focus"]
        for s in surfaces:
            for f in fgs:
                c = contrast(P[f], P[s])
                if c < 4.5:
                    bad.append(f"[{sk}] {f} on {s} = {c:.2f}")
        for f in SEM_KEYS + ["focus"]:
            c = contrast(P[f], P[f + "Container"])
            if c < 4.5:
                bad.append(f"[{sk}] {f} on {f}Container = {c:.2f}")
        if contrast(P["outline"], P["surface"]) < 3:
            bad.append(f"[{sk}] outline/surface = "
                       f"{contrast(P['outline'], P['surface']):.2f}")
        if contrast(P["primaryFill"], P["onPrimaryFill"]) < 4.5:
            bad.append(f"[{sk}] onPrimaryFill = "
                       f"{contrast(P['primaryFill'], P['onPrimaryFill']):.2f}")
        if contrast(P["primaryContainer"], P["onPrimaryContainer"]) < 4.5:
            bad.append(f"[{sk}] onPrimaryContainer = "
                       f"{contrast(P['primaryContainer'], P['onPrimaryContainer']):.2f}")
        for i, c in enumerate(P["chart"]):
            if contrast(c, P["surface"]) < 3:
                bad.append(f"[{sk}] chart[{i}] = {contrast(c, P['surface']):.2f}")
        for g in ("netWorth", "brand", "danger"):
            for i, c in enumerate(P[g]):
                if contrast("#FFFFFF", c) < 4.5:
                    bad.append(f"[{sk}] 白字 on {g}[{i}] = "
                               f"{contrast('#FFFFFF', c):.2f}")
        # Hero 三张卡之间要能一眼分出「正常 / 品牌 / 超支」
        for a, b in (("netWorth", "brand"), ("brand", "danger"),
                     ("netWorth", "danger")):
            d = cvd_delta_e(P[a][1], P[b][1])
            if d < 0.08:
                bad.append(f"[{sk}] hero {a}↔{b} ΔE = {d:.3f}")
    return bad


def report(all_p):
    for sk, P in all_p.items():
        print(f"\n── {sk} {SCHEMES[sk]['name']} ──")
        print("  中性:", " ".join(f"{k[:3]}={P[k]}" for k in
                                ["background", "surface", "raised", "sunken"]))
        print("  文字:", P["text"], P["textSecondary"],
              "| 描边", P["outline"], P["outlineVariant"])
        print("  品牌:", P["primary"], P["primaryFill"], P["primaryContainer"],
              P["onPrimaryContainer"])
        print("  语义:", " ".join(f"{k}={P[k]}" for k in SEM_KEYS))
        print("  容器:", " ".join(f"{k}={P[k+'Container']}" for k in SEM_KEYS))
        print("  图表:", " ".join(P["chart"]))
        print("  Hero: netWorth", P["netWorth"], "brand", P["brand"],
              "danger", P["danger"])
        print(f"  语义最差ΔE:",
              f"{min(cvd_delta_e(P[a], P[b]) for a, b in __import__('itertools').combinations(SEM_KEYS + ['focus'], 2)):.3f}",
              "| 图表相邻:",
              f"{min(cvd_delta_e(P['chart'][i], P['chart'][(i+1) % 8]) for i in range(8)):.3f}")


if __name__ == "__main__":
    data = {"light": build("light"), "dark": build("dark")}
    report(data["light"])
    report(data["dark"])
    bad = validate(data["light"])
    bad += validate(data["dark"])
    print("\n未达标:", len(bad))
    for b in bad:
        print("  -", b)
    with open("tokens.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("\n已写出 tokens.json")
