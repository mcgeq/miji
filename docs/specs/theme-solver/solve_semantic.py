"""语义色求解：在「保持语义色相含义」的区间内搜索色相 + 明度，
最大化三种色觉缺陷下两两最小的 OKLab ΔE，同时满足 WCAG。
"""
import random
from theme_solve import oklch_to_hex, contrast, cvd_delta_e

BOUNDS = {  # (色相下限, 上限) —— 守住语义含义，不让求解器把「收入」解成紫色
    "expense": (20, 36),
    "warning": (76, 96),
    "income": (140, 162),
    "transfer": (204, 226),
    "credit": (304, 326),
    "focus": (168, 192),
}
KEYS = ["expense", "warning", "income", "transfer", "credit"]

L_LIGHT = dict(surface="#FCFDFF", raised="#F3F5F7", bg="#E9EBEE", sunken="#DADEE2")
L_DARK = dict(surface="#202225", raised="#2C2F32", bg="#16181A", sunken="#0C0E10")


def evaluate(cfg, mode):
    surfaces = [cfg_surf for cfg_surf in (L_LIGHT if mode == "light" else L_DARK).values()]
    cols = {}
    for k in KEYS + ["focus"]:
        h, L, C = cfg[k]
        hexv = oklch_to_hex(L, C, h)
        for s in surfaces:
            if contrast(hexv, s) < 4.5:
                return None, None
        cols[k] = hexv
    worst, pair = 1.0, None
    for i in range(len(KEYS)):
        for j in range(i + 1, len(KEYS)):
            d = cvd_delta_e(cols[KEYS[i]], cols[KEYS[j]])
            if d < worst:
                worst, pair = d, (KEYS[i], KEYS[j])
    # focus 只要求「看得出不是上面任何一个」，阈值放低一档
    fworst = min(cvd_delta_e(cols["focus"], cols[k]) for k in KEYS)
    if fworst < 0.035:
        return None, None
    return worst, (pair, cols, fworst)


def search(mode, seed=7, iters=24000):
    """目标是「可分辨性尽量高，同时五六个颜色看起来像一家人」。

    纯最大化 ΔE 会把颜色推向极端（极暗、极高彩度），看着脏。所以减去一项
    对目标明度/彩度的偏离惩罚 —— 可分辨性够用就行（≥0.075），剩下的预算
    用来换「好看」。
    """
    rng = random.Random(seed)
    L0 = 0.470 if mode == "light" else 0.780
    C0 = 0.118 if mode == "light" else 0.108
    L_range = (L0 - 0.045, L0 + 0.040) if mode == "light" else (L0 - 0.075, L0 + 0.055)
    C_range = (C0 - 0.030, C0 + 0.030)
    best = None
    for _ in range(iters):
        cfg = {}
        dev = 0.0
        for k in KEYS + ["focus"]:
            lo, hi = BOUNDS[k]
            h = rng.uniform(lo, hi)
            L = rng.uniform(*L_range)
            C = rng.uniform(*C_range)
            dev += abs(L - L0) / 0.05 + abs(C - C0) / 0.035
            cfg[k] = (h, L, C)
        score, extra = evaluate(cfg, mode)
        if score is None or score < 0.075:
            continue
        dev /= len(KEYS) + 1
        obj = score - 0.045 * dev
        if best is None or obj > best[0]:
            best = (obj, (score, cfg, extra))
    return best[1]


if __name__ == "__main__":
    for mode in ("light", "dark"):
        score, cfg, (pair, cols, fworst) = search(mode)
        print(f"\n=== {mode} · 最差两两 ΔE = {score:.3f} ({pair[0]}↔{pair[1]}) "
              f"· focus 最差 {fworst:.3f}")
        for k in KEYS + ["focus"]:
            h, L, C = cfg[k]
            print(f"  {k:9s} H={h:6.1f} L={L:.3f} C={C:.3f}  {cols[k]}")
