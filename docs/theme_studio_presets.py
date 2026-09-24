"""全新主题体系（v3）：不复用现有主题的任何颜色/结构，从零定义四套方向。

设计方法（每套方向都按同样的分层构造，但气质由参数决定）：
  Layer 1 中性层：7 级明度阶梯（bg / surface / raised / sunken / border / text / text2），
                 色相与彩度决定「暖 or 冷」，明度决定层次 —— 暖感来自中性层，不来自品牌色
  Layer 2 强调层：accent 分「填充版（鲜亮、配深色前景）」与「文字版（压暗过 AA）」两个角色
  Layer 3 语义层：支出/收入/转账/信用/警示，色相固定、明度用「色盲可辨」梯度求解
  Layer 4 数据层：8 色图表板，由强调色相推导、等明度、相邻 135°
  Layer 5 品牌时刻：Hero 渐变（色相弧 + 明度梯度），净资产渐变单独定色系

输出：docs/_studio_presets.json（四套方向 × 浅/深 × 全量 token + 校验）
运行：python3 docs/theme_studio_presets.py
"""
import itertools
import json
import math

from theme_verify import (apca, contrast, dE, oklch, rgb_to_hex, simulate, srgb_to_lin, lin_to_srgb)
from theme_solve_ladder import HUES as BASE_HUES, max_chroma, srgb_ok

AMBER = '#FFE6BC'


# ── 四个方向：气质由这四个参数决定 ─────────────────────────────
DIRECTIONS = {
    'ink_cyan': dict(
        label='D1 墨黑 · 电光青', tag='暗色优先 · 工具感',
        accent=(188, 0.155),            # 电光青
        neutral=(248, 0.004),           # 真中性灰
        dark_base=0.145, light_base=0.982,
        semantic=dict(expense=32, income=152, transfer=268, credit=325, warning=72),
        note='数据优先、对比强。深色是主场景（OLED 上省电），浅色作为白天版本。',
    ),
    'paper_indigo': dict(
        label='D2 暖纸 · 靛蓝', tag='浅色优先 · 账本感',
        accent=(266, 0.170),            # 靛蓝
        neutral=(72, 0.010),            # 暖纸
        dark_base=0.175, light_base=0.975,
        semantic=dict(expense=28, income=150, transfer=222, credit=318, warning=100),
        note='像一本好纸账本：中性层温暖、强调色冷静，长时间看不累。',
    ),
    'obsidian_gold': dict(
        label='D3 曜石 · 赤金', tag='暗色优先 · 质感',
        accent=(78, 0.150),             # 赤金
        neutral=(60, 0.006),            # 微暖黑
        dark_base=0.115, light_base=0.980,
        semantic=dict(expense=22, income=158, transfer=248, credit=300, warning=45),
        note='黑金质感：表面更暗、强调色更暖，语义色整体降彩度避免与金争抢。',
    ),
    'snow_berry': dict(
        label='D4 雪白 · 莓红', tag='浅色优先 · 鲜明',
        accent=(355, 0.185),            # 莓红
        neutral=(255, 0.005),           # 冷雪白
        dark_base=0.170, light_base=0.988,
        semantic=dict(expense=42, income=145, transfer=232, credit=290, warning=85),
        note='鲜亮、年轻、消费感。莓红与支出红靠色相 + 明度双重区分，不冲突。',
    ),
}

# 中性层明度阶梯（浅色从上到下变暗；深色反过来）
RAMPS = dict(
    light=dict(sunken=0.955, bg=0.972, surface=1.0, raised=0.985, border=0.90,
               text2=0.505, text=0.235),
    dark=dict(sunken=0.105, bg=0.145, surface=0.195, raised=0.245, border=0.325,
              text2=0.685, text=0.935),
)


def neutral_hex(L, hue, chroma):
    return srgb_ok(L, min(chroma, max_chroma(L, hue)), hue) or '#808080'


def solve_L(hue, chroma, bg, target, up):
    """在给定色相/彩度下解明度，使与 bg 的对比度达到 target。up=True 往亮找。"""
    rng = range(72, 24, -1) if not up else range(28, 88)
    for L in [x / 100 for x in rng]:
        hx = srgb_ok(L, min(chroma, max_chroma(L, hue)), hue)
        if hx and contrast(hx, bg) >= target:
            return L, hx
    return (0.35, srgb_ok(0.35, min(chroma, max_chroma(0.35, hue)), hue) or '#808080')


def solve_accent_pair(hue, chroma, surface, mode):
    """联合求「填充色 + 其上的前景色」：填充 ≥3:1（能看出是控件）、前景对填充 ≥4.6。"""
    levels = ([x / 100 for x in range(28, 72)] if mode == 'light'
              else [x / 100 for x in range(38, 90)])
    order = list(reversed(levels))     # 两种模式都优先「更亮的填充」，深色下才够醒目
    for L in order:
        fill = srgb_ok(L, min(chroma, max_chroma(L, hue)), hue)
        if not fill or contrast(fill, surface) < 3.0:
            continue
        for L2 in [x / 100 for x in range(6, 42)]:
            on = srgb_ok(L2, min(chroma * 0.8, max_chroma(L2, hue)), hue)
            if on and contrast(fill, on) >= 4.6:
                return fill, on
    return (srgb_ok(0.45, min(chroma, 0.12), hue) or '#666666', '#FFFFFF')


def build(d):
    out = {}
    hue_n, chroma_n = d['neutral']
    hue_a, chroma_a = d['accent']
    for mode in ('light', 'dark'):
        base = d['light_base'] if mode == 'light' else d['dark_base']
        ramp = dict(RAMPS[mode])
        # 中性层：所有明度整体围绕 base 平移（保留阶梯形状）
        shift = base - ramp['surface']
        neutrals = {k: neutral_hex(min(0.995, max(0.06, v + shift)), hue_n, chroma_n)
                    for k, v in ramp.items()}
        # 描边分两档：borderStrong 用于输入框/可点击控件的边界（WCAG 1.4.11 要求 3:1）；
        # border 用于分隔线/装饰（无对比度要求，只要看得见）。
        _, border_strong = solve_L(hue_n, max(chroma_n, 0.012) * 2, neutrals['surface'],
                                   3.0, up=(mode == 'dark'))
        neutrals['borderStrong'] = border_strong
        surface, bg = neutrals['surface'], neutrals['bg']
        # 强调层：填充版（鲜亮 + 深前景）与文字版（过 AA）
        # 填充版：鲜亮（≥3:1）且能承载深色前景（≥4.6）—— 这两条必须联合求解：
        # 中间明度的颜色既不够亮也不够暗，任何前景都到不了 4.5（实测只有 1.7~2.0）。
        fill, onFill = solve_accent_pair(hue_a, chroma_a, surface, mode)
        # 文字版：压暗/提亮到可当正文（浅色 4.6、深色 7.0）
        text_L, accent_text = solve_L(hue_a, chroma_a, surface,
                                      4.6 if mode == 'light' else 7.0, up=(mode == 'dark'))
        # 语义层：复用「色盲可辨梯度」求解器，但色相按方向替换
        # 语义层两套策略：
        # balanced = 等明度（五色视觉权重一致、最鲜亮，靠 +/− 与文字冗余）
        # cvd      = 明度梯度（色盲下也能分辨，代价是明暗不齐）
        target = 4.6 if mode == 'light' else 7.0
        bg_sem = neutrals['sunken']
        sem_balanced = balanced_ladder(d['semantic'], bg_sem, target, mode)
        sem_cvd = cvd_ladder(d['semantic'], bg_sem, target, mode)
        # 数据层：8 色，等明度
        chart_L = 0.58 if mode == 'light' else 0.80
        chart = []
        for i in range(8):
            h = (hue_a + 165 + i * 135) % 360
            for Ltry in ([chart_L - 0.03 * k for k in range(7)] if mode == 'light'
                         else [chart_L + 0.03 * k for k in range(7)]):
                hx = srgb_ok(Ltry, min(0.12, max_chroma(Ltry, h)), h)
                if hx and contrast(hx, surface) >= 3.0:
                    chart.append(hx)
                    break
            else:
                chart.append(srgb_ok(chart_L, 0.09, h) or '#888888')
        out[mode] = dict(neutrals=neutrals, accent=dict(
            fill=fill, onFill=onFill, text=accent_text, hue=hue_a, chroma=chroma_a),
            semantic=sem_cvd, semantic_balanced=sem_balanced,
            chart=chart, amber=AMBER,
            hero=hero_gradients(hue_a, mode), direction=d['label'])
    return out


def balanced_ladder(sem_hues, bg, target, mode):
    """均衡型：让五个语义色的感知明度尽量一致（同亮度带），保持鲜艳与视觉权重平衡。"""
    target_L = 0.50 if mode == 'light' else 0.80
    out = {}
    for name, hue in sem_hues.items():
        best = None
        for L in [x / 100 for x in range(34, 72)]:
            hx = srgb_ok(L, min(0.135, max_chroma(L, hue)), hue)
            if not hx or contrast(hx, bg) < target:
                continue
            if best is None or abs(L - target_L) < abs(best[0] - target_L):
                best = (L, hx)
        out[name] = best[1] if best else (srgb_ok(0.5, 0.12, hue) or '#888888')
    return out


def cvd_ladder(sem_hues, bg, target, mode):
    """在色盲模拟空间里拉开明度，让五色在任何色觉下都可区分（沿用上一轮的结论）。"""
    names = list(sem_hues)
    cands = {}
    levels = ([x / 100 for x in range(36, 68)] if mode == 'light'
              else [x / 100 for x in range(62, 94)])
    for n in names:
        cands[n] = []
        for L in levels:
            hx = srgb_ok(L, min(0.13, max_chroma(L, sem_hues[n])), sem_hues[n])
            if hx and contrast(hx, bg) >= target:
                cands[n].append((L, hx))
    if any(not c for c in cands.values()):
        return {n: (srgb_ok(0.5, 0.12, sem_hues[n]) or '#888') for n in names}
    best, best_score = None, -9
    for combo in itertools.product(*[cands[n][::max(1, len(cands[n]) // 8)] for n in names]):
        pick = dict(zip(names, combo))
        Ls = [pick[n][0] for n in names]
        if max(Ls) - min(Ls) > 0.17:
            continue
        worst = 9
        for kind in ('protan', 'deutan', 'tritan', 'normal'):
            sim = {n: (pick[n][1] if kind == 'normal' else simulate(pick[n][1], kind)) for n in names}
            for a, b in itertools.combinations(names, 2):
                w = 1.6 if {a, b} == {'expense', 'income'} else 1.0
                worst = min(worst, dE(sim[a], sim[b]) * w)
        if worst > best_score:
            best_score, best = worst, pick
    return {n: best[n][1] for n in names}


def hero_gradients(accent_hue, mode):
    """Hero 渐变：色相弧 + 明度梯度；净资产用固定的「紫→青」色系。"""
    def stop(h, target, need_amber=False):
        for L in [x / 100 for x in range(64, 22, -1)]:
            hx = srgb_ok(L, min(0.17, max_chroma(L, h)), h)
            if not hx:
                continue
            ok = contrast('#FFFFFF', hx) >= target
            if need_amber:
                ok = ok and contrast(AMBER, hx) >= 4.6
            if ok:
                return hx
        return srgb_ok(0.32, 0.10, h) or '#333333'
    return dict(
        brand=[stop(accent_hue - 26, 5.4), stop(accent_hue + 6, 4.9),
               stop(accent_hue + 40, 4.6)],
        netWorth=[stop(288, 5.2, True), stop(238, 5.0, True), stop(192, 4.6, True)],
        danger=[stop(350, 5.4), stop(2, 5.0), stop(18, 4.6)],
    )


def measure(v):
    """一套完整 token 的体检：关键配对对比度 + 色盲 ΔE + APCA。"""
    n, a, s = v['neutrals'], v['accent'], v['semantic']
    checks = {
        'accent 填充 + onFill': contrast(a['fill'], a['onFill']),
        'accent 文字 on surface': contrast(a['text'], n['surface']),
        '正文 on surface': contrast(n['text'], n['surface']),
        '次要文字 on surface': contrast(n['text2'], n['surface']),
        '控件描边 on surface（非文字）': contrast(n['borderStrong'], n['surface']),
        '分隔线 on surface（仅需可见）': contrast(n['border'], n['surface']),
        '语义色最差 on sunken': min(contrast(c, n['sunken']) for c in s.values()),
        '语义色最差 on surface': min(contrast(c, n['surface']) for c in s.values()),
        'Hero 白字最差': min(contrast('#FFFFFF', c) for g in v['hero'].values() for c in g),
        'Hero 琥珀字最差': min(contrast(AMBER, c) for c in v['hero']['netWorth']),
        '图表最差 on surface': min(contrast(c, n['surface']) for c in v['chart']),
    }
    cvd = {}
    for kind in ('normal', 'protan', 'deutan', 'tritan'):
        sim = {k: (c if kind == 'normal' else simulate(c, kind)) for k, c in s.items()}
        vals = sorted((dE(sim[x], sim[y]), f'{x}/{y}') for x, y in itertools.combinations(s, 2))
        cvd[kind] = dict(min=round(vals[0][0], 3), pair=vals[0][1], second=round(vals[1][0], 3))
    return dict(checks={k: round(x, 2) for k, x in checks.items()}, cvd=cvd,
                apca=dict(text=round(apca(n['text'], n['surface']), 1),
                          text2=round(apca(n['text2'], n['surface']), 1),
                          accent=round(apca(a['text'], n['surface']), 1)),
                spread=round(max(oklch(c)[0] for c in s.values()) -
                             min(oklch(c)[0] for c in s.values()), 3))


def main():
    out = {}
    fails = 0
    for key, d in DIRECTIONS.items():
        built = build(d)
        out[key] = dict(meta=dict(label=d['label'], tag=d['tag'], note=d['note'],
                                  accentHue=d['accent'][0], accentChroma=d['accent'][1],
                                  neutralHue=d['neutral'][0], neutralChroma=d['neutral'][1]),
                        light=built['light'], dark=built['dark'])
        for mode in ('light', 'dark'):
            mb = measure(dict(built[mode], semantic=built[mode]['semantic_balanced']))
            built[mode]['report_balanced'] = mb
            m = measure(built[mode])
            out[key][mode]['report'] = m
            for name, val in m['checks'].items():
                if '分隔线' in name:
                    need = 1.15
                elif '非文字' in name or '图表' in name:
                    need = 3.0
                else:
                    need = 4.5
                if name in ('语义色最差 on sunken', '语义色最差 on surface') and mode == 'dark':
                    need = 4.5
                if val < need:
                    fails += 1
                    print(f'✗ {key}/{mode} {name}: {val} < {need}')
        print(f'{d["label"]}: 浅色语义 ' + ' '.join(f'{k}={v}' for k, v in built['light']['semantic'].items()))
        print(f'{" " * len(d["label"])}  深色语义 ' + ' '.join(f'{k}={v}' for k, v in built['dark']['semantic'].items()))
        print(f'{" " * len(d["label"])}  浅色强调 fill={built["light"]["accent"]["fill"]} text={built["light"]["accent"]["text"]}'
              f' | 深色 fill={built["dark"]["accent"]["fill"]} text={built["dark"]["accent"]["text"]}')
    json.dump(out, open('docs/_studio_presets.json', 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print(f'\n校验失败 {fails} 项 → docs/_studio_presets.json')


if __name__ == '__main__':
    main()
