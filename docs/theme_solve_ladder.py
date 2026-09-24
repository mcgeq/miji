"""语义色明度梯度求解（v2）。

实测事实（docs/theme_verify.py 的色觉缺陷模拟 + OKLab ΔE）：
- 在**等明度**下，无论怎么选色相，红绿色盲下「支出红 ↔ 收入绿」的最小 ΔE 只有 0.01~0.05
  （正常视觉 0.24）—— 色相通道在色盲下会塌，只靠色相是不够的。
- 明度差能线性地换成可辨性：ΔL=0.11 → ΔE≈0.12，ΔL=0.16 → ΔE≈0.15。

因此按「Wong 2011 / Okabe-Ito 2008：用明度作冗余编码 + WCAG 1.4.1：颜色不能是唯一通道」
设计：给语义色定一个**最小明度梯度**（按“同时出现的可能性”分级），
在满足 WCAG 的前提下求解最短跨度（跨度越小，五个色的视觉权重越均衡）。

运行：python3 docs/theme_solve_ladder.py
输出：docs/_theme_ladder.json
"""
import itertools
import json
import math

from theme_verify import (apca, contrast, dE, oklch, rgb_to_hex, simulate,
                         srgb_to_lin, lin_to_srgb)

# 语义色色相（正常视觉的识别依据）
HUES = {'expense': 30, 'income': 160, 'transfer': 235, 'credit': 305, 'warning': 78}

# 最小明度差需求：按「同时出现在一屏并需要区分的概率」分级
REQUIRED_DL = {
    ('expense', 'income'): 0.11,     # 流水/统计里紧邻，都是「金额色」，最关键
    ('expense', 'warning'): 0.05,    # 超支时同屏（红金额 + 琥珀警示）
    ('income', 'transfer'): 0.06,
    ('transfer', 'credit'): 0.06,    # 转账/信用多为图标+文字，不总是并排
}
DEFAULT_DL = 0.03                    # 其余组合只要求「不要看起来一样」


def srgb_ok(L, C, H):
    a = C * math.cos(math.radians(H))
    b = C * math.sin(math.radians(H))
    l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
    g = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
    bb = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_
    if not all(-0.002 <= x <= 1.002 for x in (r, g, bb)):
        return None
    return rgb_to_hex(tuple(lin_to_srgb(max(0.0, min(1.0, x))) for x in (r, g, bb)))


def max_chroma(L, H, cap=0.30):
    lo, hi = 0.0, cap
    for _ in range(26):
        mid = (lo + hi) / 2
        if srgb_ok(L, mid, H) is None:
            hi = mid
        else:
            lo = mid
    return lo


CHROMA = 0.135          # 目标色度：够鲜亮、又不刺眼（HCT 里约等于 chroma 45 的观感）


def colour(L, name):
    return srgb_ok(L, min(CHROMA, max_chroma(L, HUES[name])), HUES[name])


def feasible_range(name, bg, target, lo, hi):
    """在 [lo,hi] 内所有满足对比度的 L（步长 0.01）。"""
    out = []
    L = lo
    while L <= hi + 1e-9:
        c = colour(round(L, 2), name)
        if c and contrast(c, bg) >= target:
            out.append(round(L, 2))
        L += 0.01
    return out


# 权重：同时出现在一屏且需要区分的概率越高，权重越大（正常视觉再乘 1.4）
PAIR_WEIGHT = {
    ('expense', 'income'): 1.6,
    ('expense', 'warning'): 1.2,
    ('income', 'transfer'): 1.1,
    ('transfer', 'credit'): 1.1,
}
NORMAL_WEIGHT = 1.4


def _pair_w(a, b):
    return PAIR_WEIGHT.get((a, b), PAIR_WEIGHT.get((b, a), 1.0))


def solve(light, bg, target, max_span=0.16, restarts=24, cvd_weight=True, target_min_dE=0.0):
    """约束直接下在「色盲模拟后的空间」里。

    早先的版本把约束写成「正常视觉的明度差」，结果被色盲模拟推翻：
    protan 对红色的敏感度低，**浅红会变暗**，明度序直接翻转
    （实测 ΔL=0.12 的一对，protan 下 ΔE 只有 0.018）。所以这里对每个候选
    预计算 4 种视觉（正常 + 三种色盲）下的颜色，再直接优化最小 ΔE。
    """
    names = list(HUES)
    ranges = {n: feasible_range(n, bg, target, 0.38 if light else 0.60,
                               0.70 if light else 0.94) for n in names}
    if any(not r for r in ranges.values()):
        raise SystemExit(f'无解：{ {n: len(r) for n, r in ranges.items()} }')
    # 预计算：候选色 + 各视觉下的模拟色
    table = {}
    for n in names:
        table[n] = []
        for L in ranges[n]:
            hexv = colour(L, n)
            if not hexv:
                continue
            table[n].append((L, hexv, {
                'normal': hexv,
                'protan': simulate(hexv, 'protan'),
                'deutan': simulate(hexv, 'deutan'),
                'tritan': simulate(hexv, 'tritan'),
            }))
    pairs = list(itertools.combinations(names, 2))

    def score(pick):
        span = max(pick[n][0] for n in names) - min(pick[n][0] for n in names)
        if span > max_span:
            return -1, span
        worst = 9.0
        for a, b in pairs:
            w = _pair_w(a, b)
            for vision in ('normal', 'protan', 'deutan', 'tritan'):
                dd = dE(pick[a][2][vision], pick[b][2][vision])
                if not cvd_weight and vision != 'normal':
                    continue                       # 均衡型：只优化正常视觉下的可辨识度
                eff = dd * w * (NORMAL_WEIGHT if vision == 'normal' else 1.0)
                worst = min(worst, eff)
        return worst, span

    import random
    random.seed(7)
    best = None
    for r in range(restarts):
        pick = {n: random.choice(table[n]) for n in names}
        improved = True
        while improved:
            improved = False
            for n in names:
                cur = pick[n]
                for cand in table[n]:
                    if cand is cur:
                        continue
                    trial = dict(pick)
                    trial[n] = cand
                    if score(trial)[0] > score(pick)[0]:
                        pick = trial
                        improved = True
                # 坐标上升：即使没提升也换到等分里更好的那个
        sc, span = score(pick)
        if best is None or sc > best[0]:
            best = (sc, span, dict(pick))
    return best, ranges


STRATEGIES = {
    # 均衡型：明度跨度小 → 五个语义色视觉权重接近、颜色鲜亮；
    #          色盲下靠符号/文字冗余（App 里金额都带 +/−、分类都有文字，符合 WCAG 1.4.1）
    'balanced': dict(max_span=0.08, cvd_weight=False),
    # 色盲强化型：明度跨度大 → 不依赖颜色也能分辨；代价是明暗不齐、部分色偏暗
    'cvd': dict(max_span=0.16, cvd_weight=True),
}


def report(mode, bg, target):
    (sc, span, pick), ranges = solve(mode == 'light', bg, target, **STRATEGIES['balanced'])
    sem = {n: pick[n][1] for n in HUES}
    order = sorted(HUES, key=lambda n: pick[n][0])
    print(f'  {mode}: 跨度 {span:.2f} · 最优评分 {sc:.3f}')
    print('    阶梯 ' + ' < '.join(f'{n} {pick[n][0]:.2f}' for n in order))
    print('    ' + '  '.join(f'{n} {sem[n]} 对比 {contrast(sem[n], bg):.2f}' for n in HUES))
    for kind in ('normal', 'protan', 'deutan', 'tritan'):
        sim = {n: (sem[n] if kind == 'normal' else simulate(sem[n], kind)) for n in HUES}
        vals = sorted((dE(sim[a], sim[b]), f'{a}/{b}') for a, b in itertools.combinations(HUES, 2))
        print(f'    {kind:7s} 最小 ΔE {vals[0][0]:.3f}（{vals[0][1]}）'
              f'  次小 {vals[1][0]:.3f}（{vals[1][1]}）')
    return sem, span


def measure(sem, bg):
    """输出一套语义色的全部体检指标。"""
    rows = {}
    for kind in ('normal', 'protan', 'deutan', 'tritan'):
        sim = {n: (sem[n] if kind == 'normal' else simulate(sem[n], kind)) for n in HUES}
        vals = sorted((dE(sim[a], sim[b]), f'{a}/{b}')
                      for a, b in itertools.combinations(HUES, 2))
        rows[kind] = dict(min=vals[0][0], pair=vals[0][1], second=vals[1][0],
                          secondPair=vals[1][1])
    Ls = [oklch(v)[0] for v in sem.values()]
    return dict(
        colors=sem,
        contrast={n: contrast(v, bg) for n, v in sem.items()},
        lightness={n: oklch(v)[0] for n, v in sem.items()},
        spread=max(Ls) - min(Ls),
        cvd=rows,
        apca={n: apca(v, bg) for n, v in sem.items()},
    )


def main():
    out = {}
    print('语义色求解：两套策略 × 浅色/深色（WCAG 门槛 + 色觉缺陷模拟 + APCA）')
    for key, bg, target in [
        ('light', '#FFF8F4', 4.6),      # 暖白底（取最亮的容器色）
        ('dark', '#19120A', 7.0),       # 深色底（要求更严，深色下对比感知更弱）
    ]:
        for strat, kwargs in STRATEGIES.items():
            (sc, span, pick), _ = solve(key == 'light', bg, target, **kwargs)
            sem = {n: pick[n][1] for n in HUES}
            m = measure(sem, bg)
            m['score'], m['strategy'] = sc, strat
            out[f'{key}_{strat}'] = m
            print(f'  {key} / {strat}: 跨度 {m["spread"]:.2f} · '
                  f'正常最小ΔE {m["cvd"]["normal"]["min"]:.3f} · '
                  f'protan {m["cvd"]["protan"]["min"]:.3f} · '
                  f'deutan {m["cvd"]["deutan"]["min"]:.3f} · '
                  f'tritan {m["cvd"]["tritan"]["min"]:.3f}')
            print('    ' + '  '.join(f'{n} {v}(L{m["lightness"][n]:.2f})' for n, v in sem.items()))
    json.dump(out, open('docs/_theme_ladder.json', 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print('\n→ docs/_theme_ladder.json')


if __name__ == '__main__':
    main()
