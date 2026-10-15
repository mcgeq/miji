"""第二版主题装配 —— 参照 iCost / 钱迹 / 木木记账重做。

## 第一版为什么不好看

1. **中性面是米灰**（#F2EDE6），浅色四级表面只差 4% 明度。去掉描边和阴影后
   层级就没了，整体像蒙了层灰。竞品走的是另一条路：**灰底 + 纯白卡**，层级
   靠「白卡浮在灰底上」+ 阴影，一眼就干净。
2. **主色彩度只有 0.108–0.140**，发闷。钱迹 #048CFC 的彩度约 0.17，木木的橙
   更高。这一版主色统一提到 0.14–0.175。
3. **深色背景压到 #0E0F13**（近黑），硬。改成 #1B1E24 一级的深灰蓝。
4. **语义色按正文的 4.5:1 去卡**，解出来是 #0D5900 / #584800 这类暗浊色。
   金额是超大号粗体，WCAG 只要求 3:1，放宽后颜色才亮得起来。

## 这一版的结构

- 中性层：浅色 = 灰底 + 白卡（surface 与 raised 同色，层级靠阴影）；
  深色 = 越上层越亮（Material 式）。
- 主色分三个角色：`primary`（文字/图标，on 表面 ≥4.5）、`primarySolid`
  （实心按钮底）、`primaryContainer`（chip 浅底）。**`onPrimarySolid` 由
   token 给**，代码不要写死白/黑 —— 浅色配白字，深色配深字（iOS/Material
  双模式的标准做法，也是钱迹夜间模式的做法）。
- 语义色两套：vivid（大号金额、图表、图标，≥3:1）+ strong（小号文字，≥4.5:1）。
"""
import itertools
import json

from theme_solve import oklch_to_hex, contrast, cvd_delta_e

# ── 求解出来的语义层（三套共用，见 solve_semantic2.py） ─────────────
SEM_LIGHT = {
    "income": (146.2, 0.585, 0.1551),
    "expense": (20.6, 0.585, 0.1615),
    "transfer": (206.0, 0.5669, 0.1551),
    "credit": (315.0, 0.585, 0.1550),
    "warning": (83.0, 0.5608, 0.1550),
}
SEM_DARK = {
    "income": (151.8, 0.7900, 0.1299),
    "expense": (20.0, 0.7957, 0.1300),
    "transfer": (208.3, 0.7900, 0.1311),
    "credit": (317.7, 0.7902, 0.1300),
    "warning": (84.0, 0.7695, 0.1301),
}
SEM_KEYS = ["income", "expense", "transfer", "credit", "warning"]

# 小号文字用的「深版」：vivid 版压深这么多还能守住 4.5:1（浅色），
# 深色则反过来提亮。
STRONG_SHIFT = {"light": -0.145, "dark": +0.060}

# ── 图表 8 色：色相沿用语义色相 + 补两个，环形顺序另求 ────────────
CHART_HUES = [21, 83, 146, 264, 315, 206, 45, 180]
CHART_L_LIGHT, CHART_C_LIGHT, CHART_STEP_LIGHT = 0.620, 0.150, 0.050
CHART_L_DARK, CHART_C_DARK, CHART_STEP_DARK = 0.800, 0.132, 0.055

# ── 三个方向 ────────────────────────────────────────────────────
# ph/pc = 主色色相/彩度；nh/nc = 中性面色相/彩度
SCHEMES = {
    "A": dict(name="晴空 Azure", nh=250, nc=0.005, ph=248, pc=0.170,
              ref="钱迹 #048CFC 这一路",
              desc="鲜亮宝蓝 + 冷白灰底。最「像一款正经记账工具」，"
                   "中性面近乎无彩，画面让给分类色与金额。"),
    "B": dict(name="暖阳 Sunny", nh=68, nc=0.011, ph=52, pc=0.172,
              ref="木木记账的橙羽这一路",
              desc="暖橙 + 暖砂底。记账是每天都做的事，暖色最不冷冰冰；"
                   "代价是主色占了橙区，与「警告琥珀」要靠明度拉开。"),
    "C": dict(name="青竹 Mint", nh=180, nc=0.005, ph=182, pc=0.145,
              ref="iCost / 随手记的清新路子",
              desc="青绿 + 中性白灰。绿在理财语境 = 增长，最贴「越记越有钱」；"
                   "代价是主色与「收入绿」同区，靠彩度和明度拉开。"),
}


def solve_chart_order():
    """在 8! 种环形排列里挑一个：深浅两模式**共用**同一顺序。

    共用的理由很实在：同一个分类在切主题后不该换颜色，否则用户刚建立起来的
    「绿色 = 餐饮」的记忆就作废了。
    """
    best = None
    for perm in itertools.permutations(range(1, 8)):
        order = (0,) + perm
        cl = [oklch_to_hex(CHART_L_LIGHT - (CHART_STEP_LIGHT if i % 2 else 0),
                           CHART_C_LIGHT, CHART_HUES[h]) for i, h in enumerate(order)]
        cd = [oklch_to_hex(CHART_L_DARK - (CHART_STEP_DARK if i % 2 else 0),
                           CHART_C_DARK, CHART_HUES[h]) for i, h in enumerate(order)]
        if min(contrast(c, "#FFFFFF") for c in cl) < 3.0:
            continue
        if min(contrast(c, "#252932") for c in cd) < 3.0:
            continue
        wl = min(cvd_delta_e(cl[i], cl[(i + 1) % 8]) for i in range(8))
        wd = min(cvd_delta_e(cd[i], cd[(i + 1) % 8]) for i in range(8))
        score = min(wl, wd)
        if best is None or score > best[0]:
            best = (score, [CHART_HUES[h] for h in order], cl, cd, wl, wd)
    return best


def hero_stops(ph, pc, nh, dark):
    """三张 Hero 卡的渐变：**按用途定死，不做搜索**。

    上一版让求解器自由排列色相，它为了把两两 ΔE 拉大，把净资产推成了紫色
    #4F27A6、品牌推成了墨绿 #004E42 —— 数据好看，语义全错。这一版直接按用途给：

    - `netWorth` 主色渐变：这是门面卡，就该是品牌色；
    - `brand` 石墨渐变：低彩度深灰，黑卡配白字是高端卡的标准做法，
      也天然与主色、红色拉开距离；
    - `danger` 红：语义色，写死，不跟品牌走 —— 用户换主题不该重新学一遍
      「超支是什么颜色」。
    """
    shift = 0.02 if dark else 0.0
    def grad(hues, chromas, ls):
        return [oklch_to_hex(ls[i] + shift, chromas[i], hues[i]) for i in range(3)]

    # 明度不能停在中间地带（0.48–0.58）：那个区间白字和深字都够不着 4.5，
    # 上一版就是卡在这里。三张卡各自站到一端：
    #   净资产 = 亮主色渐变 + 深字（品牌门面，就该鲜亮）
    #   品牌   = 石墨渐变 + 白字（黑卡是高端卡的标准做法，也天然拉开距离）
    #   超支   = 深红渐变 + 白字（警示需要重量感，亮红反而轻飘）
    net = grad([ph + 2, ph + 24, ph + 48],
               [pc * 1.02, pc * 1.08, pc * 0.95], [0.64, 0.72, 0.68])
    graphite = grad([nh, nh + 6, nh + 12], [0.020, 0.016, 0.014],
                    [0.26, 0.33, 0.29])
    danger = grad([352, 8, 24], [0.155, 0.172, 0.155], [0.40, 0.46, 0.43])
    out = {"netWorth": net, "brand": graphite, "danger": danger}
    for g, hues in (("netWorth", [ph + 2, ph + 24, ph + 48]),
                    ("brand", [nh, nh + 6, nh + 12]),
                    ("danger", [352, 8, 24])):
        mid = out[g][1]
        if contrast("#FFFFFF", mid) >= 4.5:
            out["on" + g[0].upper() + g[1:]] = "#FFFFFF"
        else:
            out["on" + g[0].upper() + g[1:]] = oklch_to_hex(0.205, 0.045, hues[1])
    return out


CHART = solve_chart_order()


def build(mode):
    dark = mode == "dark"
    out = {}
    for key, cfg in SCHEMES.items():
        nh, nc, ph, pc = cfg["nh"], cfg["nc"], cfg["ph"], cfg["pc"]

        def n(L, cm=1.0):
            return oklch_to_hex(L, nc * cm, nh)

        if dark:
            P = dict(
                background=n(0.260), sunken=n(0.215),
                surface=n(0.315), raised=n(0.368),
                outline=n(0.630, 3.0), outlineVariant=n(0.420, 1.8),
                text=n(0.945, 0.5), textSecondary=n(0.752, 1.1),
                textTertiary=n(0.640, 1.2),
                # 深色下的主色要**提亮**才能压住深底
                primary=oklch_to_hex(0.805, pc * 0.80, ph),
                primarySolid=oklch_to_hex(0.775, pc * 0.98, ph),
                onPrimarySolid=oklch_to_hex(0.215, pc * 0.35, ph),
                primaryContainer=oklch_to_hex(0.300, pc * 0.42, ph),
                onPrimaryContainer=oklch_to_hex(0.865, pc * 0.62, ph),
                secondary=oklch_to_hex(0.800, pc * 0.28, ph),
                tertiary=oklch_to_hex(0.810, 0.085, ph - 58),
            )
            sem = {k: oklch_to_hex(v[1], v[2], v[0]) for k, v in SEM_DARK.items()}
            chart = CHART[3]
            cont_l, cont_c = 0.300, 0.055
        else:
            P = dict(
                # 浅色的层级 = 灰底 + 白卡。surface 与 raised **同色**，
                # 层级交给阴影和描边 —— 这正是 iOS / 竞品的做法，也是
                # 第一版「四级只差 4% 明度看不出层级」的正解。
                background=n(0.972), surface=n(1.0), raised=n(1.0),
                sunken=n(0.946),
                outline=n(0.635, 3.0), outlineVariant=n(0.895, 1.4),
                text=n(0.205, 1.1), textSecondary=n(0.470, 1.2),
                textTertiary=n(0.585, 1.2),
                primary=oklch_to_hex(0.512, pc, ph),
                # 亮版主色：按钮 / FAB / 渐变底。配深字（见 onPrimarySolid）。
                primarySolid=oklch_to_hex(0.630, pc * 1.02, ph),
                onPrimarySolid=oklch_to_hex(0.205, pc * 0.45, ph),
                primaryContainer=oklch_to_hex(0.945, pc * 0.34, ph),
                onPrimaryContainer=oklch_to_hex(0.410, pc * 0.85, ph),
                secondary=oklch_to_hex(0.560, pc * 0.30, ph),
                tertiary=oklch_to_hex(0.580, 0.070, ph - 58),
            )
            sem = {k: oklch_to_hex(v[1], v[2], v[0]) for k, v in SEM_LIGHT.items()}
            chart = CHART[2]
            cont_l, cont_c = 0.945, 0.055

        # 小号文字版（≥4.5:1）与语义容器层（chip / tag 的淡底）
        src = SEM_DARK if dark else SEM_LIGHT
        shift = STRONG_SHIFT[mode]
        for k in SEM_KEYS:
            h, L, C = src[k]
            P[k] = sem[k]
            P[k + "Strong"] = oklch_to_hex(
                min(0.95, max(0.10, L + shift)), C * (0.92 if dark else 1.0), h)
            P[k + "Container"] = oklch_to_hex(cont_l, cont_c, h)
        P["chart"] = chart
        P.update(hero_stops(ph, pc, nh, dark))
        out[key] = P
    return out


NOTES = set()


def validate(all_p):
    bad = []
    for sk, P in all_p.items():
        surfaces = ["background", "surface", "raised", "sunken"]
        small = ["text", "textSecondary", "primary"] + \
                [k + "Strong" for k in SEM_KEYS]
        big = SEM_KEYS
        for s in surfaces:
            for f in small:
                c = contrast(P[f], P[s])
                if c < 4.5:
                    bad.append(f"[{sk}] 小字 {f} on {s} = {c:.2f}")
            for f in big:  # 大号粗体金额：3:1
                c = contrast(P[f], P[s])
                if c < 3.0:
                    bad.append(f"[{sk}] 金额 {f} on {s} = {c:.2f}")
        for f in SEM_KEYS:
            c = contrast(P[f + "Strong"], P[f + "Container"])
            if c < 4.5:
                bad.append(f"[{sk}] {f}Strong on 容器 = {c:.2f}")
        if contrast(P["outline"], P["surface"]) < 3:
            bad.append(f"[{sk}] outline/surface = "
                       f"{contrast(P['outline'], P['surface']):.2f}")
        if contrast(P["primarySolid"], P["onPrimarySolid"]) < 4.5:
            bad.append(f"[{sk}] onPrimarySolid = "
                       f"{contrast(P['primarySolid'], P['onPrimarySolid']):.2f}")
        if contrast(P["primaryContainer"], P["onPrimaryContainer"]) < 4.5:
            bad.append(f"[{sk}] onPrimaryContainer = "
                       f"{contrast(P['primaryContainer'], P['onPrimaryContainer']):.2f}")
        for i, c in enumerate(P["chart"]):
            if contrast(c, P["surface"]) < 3:
                bad.append(f"[{sk}] chart[{i}] = {contrast(c, P['surface']):.2f}")
        for g in ("netWorth", "brand", "danger"):
            on = P["on" + g[0].upper() + g[1:]]
            for i, c in enumerate(P[g]):
                if contrast(on, c) < 4.5:
                    bad.append(f"[{sk}] 卡片字 on {g}[{i}] = "
                               f"{contrast(on, c):.2f}")
        for a, b in itertools.combinations(("netWorth", "brand", "danger"), 2):
            d = cvd_delta_e(P[a][1], P[b][1])
            # Hero 三卡也不会同屏出现（净资产卡常态、超支卡只在超支时），
            # 且每张卡都有文字标签，阈值取 0.03 而不是语义色那一档的 0.05。
            if d < 0.030:
                bad.append(f"[{sk}] hero {a}↔{b} ΔE = {d:.3f}")
        # 主色 vs 语义色：5 个语义色几乎占满色环，主色放哪都会挨着某一个
        # （B 橙↔琥珀、C 青↔收入绿）。竞品的橙/绿主色同样如此，解法是
        # **场景隔离**：主色只出现在按钮/导航/图标，语义色只出现在金额/tag，
        # 二者从不并置需要判别。所以这里只记录，不当硬失败。
        for k in SEM_KEYS:
            d = cvd_delta_e(P["primary"], P[k])
            if d < 0.060:
                NOTES.add(f"[{sk}] primary↔{k} ΔE = {d:.3f}（靠场景隔离）")
    return bad


def report(all_p):
    for sk, P in all_p.items():
        print(f"\n── {sk} {SCHEMES[sk]['name']} ──")
        print("  中性:", " ".join(f"{k[:4]}={P[k]}" for k in
                                 ["background", "surface", "raised", "sunken"]))
        print("  文字:", P["text"], P["textSecondary"], "| 描边", P["outline"])
        print("  品牌:", P["primary"], P["primarySolid"], P["onPrimarySolid"],
              "| 容器", P["primaryContainer"])
        print("  语义:", " ".join(f"{k}={P[k]}" for k in SEM_KEYS))
        print("  小字:", " ".join(f"{k}={P[k+'Strong']}" for k in SEM_KEYS))
        print("  图表:", " ".join(P["chart"]))
        print("  Hero: netWorth", P["netWorth"][1], "brand", P["brand"][1],
              "danger", P["danger"][1])
        print("  语义最差ΔE:",
              f"{min(cvd_delta_e(P[a], P[b]) for a, b in itertools.combinations(SEM_KEYS, 2)):.3f}",
              "| 图表相邻:",
              f"{min(cvd_delta_e(P['chart'][i], P['chart'][(i+1) % 8]) for i in range(8)):.3f}",
              "| 主色↔语义:",
              f"{min(cvd_delta_e(P['primary'], P[k]) for k in SEM_KEYS):.3f}")


if __name__ == "__main__":
    print("图表顺序 ΔE: light %.3f / dark %.3f" % (CHART[4], CHART[5]))
    print("色相顺序:", CHART[1])
    data = {"light": build("light"), "dark": build("dark")}
    report(data["light"])
    report(data["dark"])
    bad = validate(data["light"]) + validate(data["dark"])
    print("\n未达标:", len(bad))
    for b in bad:
        print("  -", b)
    if NOTES:
        print("\n已知取舍（不是缺陷）:")
        for n in sorted(NOTES):
            print("  ·", n)
    with open("tokens2.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("\n已写出 tokens2.json")
