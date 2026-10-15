"""三套候选方向的色板定义 + 校验报告。

色相预算（记账 App 的铁律）：绿归收入、红归支出、琥珀归警告、紫归信用、
青归转账/GTD —— 主色只能落在「蓝 240~265」或「赭 40~55」两个窗口里，
否则会和金额语义撞车。
"""
import sys
from theme_solve import (oklch_to_hex, contrast, cvd_delta_e, simulate,
                         hex_to_oklab)

# 语义色相（三套共用，保证语义跨方案一致）
H_EXPENSE, H_WARNING, H_INCOME = 27, 88, 150
H_FOCUS, H_TRANSFER, H_CREDIT = 178, 208, 315

# 语义色的明度梯度：色相在色盲模拟下会被压到一起，靠明度把它们重新分开
# （全色盲下只剩明度一个通道，这层梯度是唯一的可分辨性来源）。
SEM_L_LIGHT = {"income": 0.470, "expense": 0.495, "transfer": 0.425,
               "credit": 0.478, "warning": 0.452}
SEM_L_DARK = {"income": 0.800, "expense": 0.795, "transfer": 0.762,
              "credit": 0.828, "warning": 0.700}


def build(neutral_h, neutral_c, warm, primary_h, primary_c, sem_c, chart_hues):
    """按「中性色相 + 主色色相 + 语义彩度」生成一套 light/dark。"""
    nh = neutral_h

    def n(L, c_scale=1.0, h=None):
        return oklch_to_hex(L, neutral_c * c_scale, h if h is not None else nh)

    light = {
        "surface": n(0.995, 0.35),
        "raised": n(0.968, 0.55),
        "background": n(0.940, 0.85),
        "sunken": n(0.898, 1.3),
        "outline": n(0.585, 3.2),
        "outlineVariant": n(0.872, 1.1),
        "text": n(0.225, 1.2),
        "textSecondary": n(0.455, 1.2),
        "primary": oklch_to_hex(0.450, primary_c, primary_h),
        "primaryFill": oklch_to_hex(0.470, primary_c * 1.22, primary_h),
        "onPrimaryFill": n(0.995, 0.35),
        "primaryContainer": oklch_to_hex(0.930, primary_c * 0.42, primary_h),
        "onPrimaryContainer": oklch_to_hex(0.400, primary_c * 0.85, primary_h),
        "secondary": oklch_to_hex(0.520, primary_c * 0.28, primary_h),
        "tertiary": oklch_to_hex(0.560, 0.055, primary_h - 60),
        "focus": oklch_to_hex(0.430, sem_c * 0.82, H_FOCUS),
        "focusContainer": oklch_to_hex(0.930, sem_c * 0.30, H_FOCUS),
        "income": oklch_to_hex(SEM_L_LIGHT["income"], sem_c, H_INCOME),
        "expense": oklch_to_hex(SEM_L_LIGHT["expense"], sem_c * 1.15, H_EXPENSE),
        "transfer": oklch_to_hex(SEM_L_LIGHT["transfer"], sem_c * 0.95, H_TRANSFER),
        "credit": oklch_to_hex(SEM_L_LIGHT["credit"], sem_c * 0.95, H_CREDIT),
        "warning": oklch_to_hex(SEM_L_LIGHT["warning"], sem_c * 1.10, H_WARNING),
        "success": oklch_to_hex(SEM_L_LIGHT["income"], sem_c, H_INCOME),
    }

    dark = {
        "surface": n(0.252, 1.0),
        "raised": n(0.302, 1.1),
        "background": n(0.208, 0.95),
        "sunken": n(0.163, 0.8),
        "outline": n(0.615, 2.6),
        "outlineVariant": n(0.395, 1.4),
        "text": n(0.930, 0.5),
        "textSecondary": n(0.742, 1.0),
        "primary": oklch_to_hex(0.785, primary_c * 0.92, primary_h),
        "primaryFill": oklch_to_hex(0.700, primary_c * 0.85, primary_h),
        "onPrimaryFill": n(0.150, 1.0),
        "primaryContainer": oklch_to_hex(0.330, primary_c * 0.55, primary_h),
        "onPrimaryContainer": oklch_to_hex(0.870, primary_c * 0.62, primary_h),
        "secondary": oklch_to_hex(0.760, primary_c * 0.30, primary_h),
        "tertiary": oklch_to_hex(0.800, 0.070, primary_h - 60),
        "focus": oklch_to_hex(0.760, sem_c * 0.72, H_FOCUS),
        "focusContainer": oklch_to_hex(0.330, sem_c * 0.42, H_FOCUS),
        "income": oklch_to_hex(SEM_L_DARK["income"], sem_c * 0.80, H_INCOME),
        "expense": oklch_to_hex(SEM_L_DARK["expense"], sem_c * 0.85, H_EXPENSE),
        "transfer": oklch_to_hex(SEM_L_DARK["transfer"], sem_c * 0.78, H_TRANSFER),
        "credit": oklch_to_hex(SEM_L_DARK["credit"], sem_c * 0.70, H_CREDIT),
        "warning": oklch_to_hex(SEM_L_DARK["warning"], sem_c * 0.95, H_WARNING),
        "success": oklch_to_hex(SEM_L_DARK["income"], sem_c * 0.80, H_INCOME),
    }

    light["chart"] = order_chart(chart_hues, 0.600, 0.135, 0.055)
    dark["chart"] = order_chart(chart_hues, 0.780, 0.120, 0.060)
    return light, dark


def order_chart(hues, L, C, l_step):
    """给 8 个色相找一个环形排列，使**相邻**两色在三种色觉缺陷下的最小 ΔE 最大。

    图表里只有相邻切片会被直接比较，所以优化目标是环上相邻对，不是全部 28 对。
    再叠一层明暗交替（±l_step）做冗余编码：全色盲下也能靠明度分开。
    """
    import itertools
    best = None
    perms = itertools.permutations(range(1, len(hues)))
    for perm in perms:
        order = (0,) + perm
        worst = min(cvd_delta_e(oklch_to_hex(L, C, hues[order[i]]),
                                oklch_to_hex(L, C, hues[order[(i + 1) % len(hues)]]))
                    for i in range(len(hues)))
        if best is None or worst > best[0]:
            best = (worst, order)
    order = best[1]
    return [oklch_to_hex(L - (l_step if i % 2 else 0.0), C, hues[h])
            for i, h in enumerate(order)]


SCHEMES = {
    # A 砚青：冷灰石面 + 钢蓝。数据/分类色是主角，品牌色退到背景。
    "A": dict(neutral_h=250, neutral_c=0.006, warm=False, primary_h=250,
              primary_c=0.125, sem_c=0.130,
              chart_hues=[25, 72, 135, 172, 205, 250, 300, 335]),
    # B 陶土：暖砂纸面 + 赭陶。手账气温度感，长时间阅读最不累。
    "B": dict(neutral_h=68, neutral_c=0.011, warm=True, primary_h=45,
              primary_c=0.105, sem_c=0.130,
              chart_hues=[25, 72, 135, 172, 205, 250, 300, 335]),
    # C 夜屿：近黑中性 + 蓝紫主色 + 薄荷高亮。深色优先，科技/高端感。
    "C": dict(neutral_h=265, neutral_c=0.007, warm=False, primary_h=268,
              primary_c=0.135, sem_c=0.135,
              chart_hues=[22, 70, 130, 168, 200, 265, 305, 340]),
}

SEMANTIC = ["income", "expense", "transfer", "credit", "warning"]


def report(name, mode, p):
    problems = []
    surfaces = ["background", "surface", "raised", "sunken"]
    for s in surfaces:
        for fg in ("text", "textSecondary", "primary", "income", "expense",
                   "transfer", "credit", "warning", "focus"):
            c = contrast(p[fg], p[s])
            if c < 4.5:
                problems.append(f"{fg} on {s} = {c:.2f} (<4.5)")
    if contrast(p["outline"], p["surface"]) < 3.0:
        problems.append("outline on surface = %.2f (<3)" %
                        contrast(p["outline"], p["surface"]))
    if contrast(p["primaryFill"], p["onPrimaryFill"]) < 4.5:
        problems.append("onPrimaryFill on primaryFill = %.2f" %
                        contrast(p["primaryFill"], p["onPrimaryFill"]))
    if contrast(p["primaryContainer"], p["onPrimaryContainer"]) < 4.5:
        problems.append("onPrimaryContainer on container = %.2f" %
                        contrast(p["primaryContainer"], p["onPrimaryContainer"]))
    for i, c in enumerate(p["chart"]):
        if contrast(c, p["surface"]) < 3.0:
            problems.append("chart[%d] on surface = %.2f (<3)" %
                            (i, contrast(c, p["surface"])))
    worst = None
    import itertools as _it
    for x, y in _it.combinations(SEMANTIC, 2):
        d = cvd_delta_e(p[x], p[y])
        if worst is None or d < worst[0]:
            worst = (d, x, y)
    chart_worst = min(
        (cvd_delta_e(p["chart"][i], p["chart"][(i + 1) % len(p["chart"])]),
         i, (i + 1) % len(p["chart"]))
        for i in range(len(p["chart"])))
    print(f"\n── {name} · {mode} ──")
    print("  neutral:", " ".join(f"{k}={p[k]}" for k in
                                 ["background", "surface", "raised", "sunken"]))
    print("  text   :", p["text"], p["textSecondary"],
          "| outline", p["outline"], p["outlineVariant"])
    print("  brand  :", p["primary"], p["primaryFill"], p["primaryContainer"],
          p["onPrimaryContainer"])
    print("  sem    :", " ".join(f"{k}={p[k]}" for k in SEMANTIC),
          "| focus", p["focus"])
    print("  chart  :", " ".join(p["chart"]))
    print(f"  语义最差色盲ΔE: {worst[0]:.3f} ({worst[1]}↔{worst[2]})")
    print(f"  图表相邻最差ΔE: {chart_worst[0]:.3f} ({chart_worst[1]}↔{chart_worst[2]})")
    if problems:
        print("  ✗ 未达标:")
        for x in problems:
            print("     -", x)
    else:
        print("  ✓ 全部达标")
    return problems


if __name__ == "__main__":
    total = 0
    for key, cfg in SCHEMES.items():
        light, dark = build(**cfg)
        total += len(report(key, "light", light))
        total += len(report(key, "dark", dark))
    print(f"\n合计未达标 {total} 项")
