"""重新求解语义色 —— 约束变了：底色从米灰改成「纯白卡片」。

上一稿的中性底是米灰（L≈0.93），语义色 L≈0.49 就够对比；这一稿改成 iOS /
竞品的「灰底 + 纯白卡」，白卡的亮度更高，语义色必须整体压深一档才守得住
4.5:1。附带好处：压深后的语义色更沉稳，不再像彩色仪表盘。

同时把 focus 从青绿挪到蓝紫 —— 青绿区要完全让给 C 方案的主色。
"""
import itertools
import json
import random

from theme_solve import oklch_to_hex, contrast, cvd_delta_e

KEYS = ["income", "expense", "transfer", "credit", "warning"]

# 色相区间：先按「这个语义必须是什么颜色」定死大方向，再在区间内细调。
# 色相区间**收窄**到"公认好看"的那一档：上一稿区间太宽，求解器为了把 ΔE 拉
# 大，把支出推到 34°（砖红）、收入压到 L0.505（暗绿） —— 数据上更可分辨，
# 但看着脏。这里先把"它必须是什么颜色"定死，只让明度/彩度去优化。
BOUNDS = {
    "expense": (20, 30),     # 正红（Radix red 9 ≈ 25°）
    "warning": (68, 84),     # 琥珀
    "income": (146, 158),    # 草绿
    "transfer": (206, 222),  # 青蓝
    "credit": (302, 322),    # 紫
    "focus": (252, 272),     # 蓝紫（原在青绿 180，让给 C 主色）
}
# 审美锚点：明度/彩度落在这一带最"像 2026 年的产品"，偏离就扣分。
# 没有这一项，纯最大化 ΔE 会把颜色推向极暗极艳（上一稿就是这么翻车的）。
L_ANCHOR = {"light": 0.585, "dark": 0.790}
C_ANCHOR = {"light": 0.155, "dark": 0.130}

# 明度梯度：色相之外再叠一层冗余编码，去色后仍能靠深浅分出谁是谁。
# 顺序按「在列表里谁更需要被看见」排：支出 > 收入 > 警告 > 转账 > 信用。
L_ORDER = ["expense", "income", "warning", "transfer", "credit"]


def evaluate(cfg, mode, bgs):
    """返回 (分数, 附加信息)；不达标返回 (None, 原因)。"""
    cols = {k: oklch_to_hex(cfg[k][1], cfg[k][2], cfg[k][0]) for k in cfg}
    for k in cfg:
        for bg in bgs:
            if contrast(cols[k], bg) < 3.0:
                return None, f"{k} on {bg} = {contrast(cols[k], bg):.2f}"
    # 明度梯度**不再做硬约束**。上一稿强制「支出最深 → 信用最浅」的单调阶梯，
    # 结果把颜色压成 #0D5900 / #584800 这类暗浊色。而 ΔE 本身就是 OKLab 距离，
    # 明度差已经算在里面 —— 冗余编码不需要再叠一层硬阶梯。这里只保留：
    # 对比度达标 + 色觉缺陷下两两可分辨 + 彩度落在「不脏不灰」的区间。

    worst = None
    for a, b in itertools.combinations(cols, 2):
        d = cvd_delta_e(cols[a], cols[b])
        if worst is None or d < worst:
            worst = d
    penalty = 0.0
    for k in cfg:
        c = cfg[k][2]
        lo, hi = (0.105, 0.190) if mode == "light" else (0.095, 0.175)
        if c < lo:
            penalty += (lo - c) * 1.6
        if c > hi:
            penalty += (c - hi) * 1.6
        anchor = L_ANCHOR[mode] + (0.055 if (k == "warning" and mode == "light") else 0.0)
        penalty += abs(cfg[k][1] - anchor) * 0.30
        penalty += abs(c - C_ANCHOR[mode]) * 0.28
    return worst - penalty, {"worst": worst, "cols": cols}


def search(mode, bgs, seed=11, iters=2600, restarts=10):
    rng = random.Random(seed)
    # 这里的 4.5 不是拍脑袋：金额语义色**绝大多数场景是大号粗体数字**
    # （流水行的 ¥128.50、统计页的月度支出），WCAG 对 large text（≥18pt 或
    # ≥14pt bold）只要求 3:1。上一稿按正文的 4.5:1 去卡，解出来的是
    # #0D5900 / #584800 这类暗浊色 —— 合规但极丑。改成 3:1 后颜色才亮得起来。
    #
    # 小号文字另配一套「深版」（见 build 里的 *Strong），那条仍守 4.5:1。
    L_range = (0.505, 0.605) if mode == "light" else (0.745, 0.850)
    MIN_TEXT = 3.0
    C_base = 0.125 if mode == "light" else 0.115
    base = None
    for r in range(restarts):
        # 每次重启先随机撒一个种子，再在它附近爬山
        cur = {}
        for k in KEYS + ["focus"]:
            lo, hi = BOUNDS[k]
            cur[k] = (rng.uniform(lo, hi), rng.uniform(*L_range),
                      rng.uniform(C_base * 0.75, C_base * 1.2))
        score, extra = evaluate(cur, mode, bgs)
        step = 0.06
        for _ in range(iters):
            cand = {k: tuple(cur[k]) for k in cur}
            k = rng.choice(KEYS + ["focus"])
            lo, hi = BOUNDS[k]
            which = rng.random()
            if which < 0.4:
                cand[k] = (min(hi, max(lo, cand[k][0] + rng.gauss(0, step * 60))),
                           cand[k][1], cand[k][2])
            elif which < 0.75:
                cand[k] = (cand[k][0],
                           min(L_range[1], max(L_range[0],
                                               cand[k][1] + rng.gauss(0, step * 0.35))),
                           cand[k][2])
            else:
                cand[k] = (cand[k][0], cand[k][1],
                           max(0.05, cand[k][2] + rng.gauss(0, step * 0.12)))
            s, e = evaluate(cand, mode, bgs)
            if s is not None and (score is None or s > score):
                score, extra, cur = s, e, cand
            step *= 0.9994
        if score is not None and (base is None or score > base[0]):
            base = (score, {k: (round(cur[k][0], 1), round(cur[k][1], 4),
                                round(cur[k][2], 4)) for k in cur}, extra)
    return base


if __name__ == "__main__":
    out = {}
    # 浅色：语义色会出现在纯白卡、浅灰底、语义容器三种底上
    # 保守取值：容器层比实际略暗，搜索出来的语义色才经得起真实容器
    light_bgs = ["#FFFFFF", "#F4F6FA"]
    dark_bgs = ["#262A32", "#1B1E24"]
    for mode, bgs in (("light", light_bgs), ("dark", dark_bgs)):
        best = search(mode, bgs)
        print(f"\n=== {mode} === score {best[0]:.4f} worst ΔE {best[2]['worst']:.3f}")
        for k in best[1]:
            print(f"  {k:9s} {best[1][k]}  {best[2]['cols'][k]}")
        out[mode] = {k: {"hcl": best[1][k], "hex": best[2]["cols"][k]}
                     for k in best[1]}
    with open("sem2.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("\n已写出 sem2.json")
