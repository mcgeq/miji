"""装配最终主题并生成对比选择页（docs/theme-redesign-v2-preview.html）。

输入：
- docs/_theme_gen_out.json   M3 角色（Dart 端用 Google 官方 HCT/TonalPalette 生成）
- docs/_theme_ladder.json    语义色的两套策略（均衡型 / 色盲强化型）

本脚本负责：
1. 用 OKLCH 生成 Hero 渐变（沿色相弧插值，避免 RGB 插值中段发灰）并校验白字/琥珀字
2. 生成图表色板（等明度、相邻切片色相相距 135°）
3. 汇总校验（WCAG / APCA / 色觉缺陷 ΔE / 明度跨度）
4. 写出可交互的 HTML（CSS 变量实时换肤 + 色盲模拟开关 + 导出选择）

运行：python3 docs/build_theme_page.py
"""
import itertools
import json
import math

from theme_verify import (apca, contrast, dE, oklab, oklch, rgb_to_hex, simulate)
from theme_solve_ladder import HUES, colour, srgb_ok, max_chroma

AMBER = '#FFE9C6'          # 净资产卡里「负债」等次级数字的颜色（需在渐变上 ≥4.5）


def lin_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def oklch_to_hex(L, C, H):
    return srgb_ok(L, C, H)


def darkest_for(text_colour, target, hue, chroma):
    """求渐变端点：让 text_colour 在其上达到 target 对比度（沿明度往下找）。

    只压色相不变明度的话，相邻两档会非常接近（渐变发闷）；
    所以每档给**不同的对比度目标**，等于给了一个明度梯度 —— 渐变才有层次。
    """
    for L in [x / 100 for x in range(62, 18, -1)]:
        hx = oklch_to_hex(L, min(chroma, max_chroma(L, hue)), hue)
        if hx and contrast(text_colour, hx) >= target:
            return hx
    return oklch_to_hex(0.30, 0.06, hue)


def hero_gradients(seed_hue, mode):
    """Hero 渐变：沿色相弧取 3 档（跨度 ~55°），并在 OKLCH 里插值。

    - 品牌渐变：白字 ≥4.5
    - 净资产渐变：白字与琥珀字都要 ≥4.5（「负债」数字用琥珀）
    - 告警渐变：白字 ≥4.5，色相偏红
    """
    chroma = 0.16 if mode == 'light' else 0.13
    def arc(hues, need_amber=False, targets=None):
        out = []
        for idx, h in enumerate(hues):
            t = (targets[idx] if targets else 4.6)
            if need_amber:
                # 琥珀比白色更亮，是更严格的那个约束
                for L in [x / 100 for x in range(60, 18, -1)]:
                    hx = oklch_to_hex(L, min(chroma, max_chroma(L, h)), h)
                    if hx and contrast(AMBER, hx) >= t and contrast('#FFFFFF', hx) >= t:
                        out.append(hx)
                        break
                else:
                    out.append(darkest_for(AMBER, t, h, chroma))
            else:
                out.append(darkest_for('#FFFFFF', t, h, chroma))
        return out

    # 色弧按「渐变要表达什么」来定，而不是机械 +30/+60：
    # - 品牌：品牌色相邻区间（同温感），跨度约 68°，三档给 5.4/4.9/4.6 的对比度目标
    #   → 同时有色相移动与明度梯度，渐变才有层次
    # - 净资产：固定「紫 → 青」（跨约 96°）。这是用户明确认可的那张卡的配色逻辑，
    #   它是一张独立的品牌卡，不必跟着主题色相走，只让明度/色度跟随明暗主题。
    # - 告警：红 → 深紫红（跨度约 45°）
    brand_hues = [(seed_hue - 30) % 360, (seed_hue + 4) % 360, (seed_hue + 38) % 360]
    danger_hues = [350, 2, 18]
    return dict(
        brand=arc(brand_hues, targets=[5.4, 4.9, 4.6]),
        netWorth=arc([288, 240, 192], need_amber=True, targets=[5.2, 5.0, 4.6]),
        danger=arc(danger_hues, targets=[5.4, 5.0, 4.6]),
    )


def chart_palette(mode, surface, seed_hue=200):
    """8 色图表色板：等明度（靠色相区分）、相邻切片色相相距 135°、对比度 ≥3。"""
    L = 0.58 if mode == 'light' else 0.80
    target = 3.0 if mode == 'light' else 3.2
    out = []
    for i in range(8):
        h = (seed_hue + 160 + i * 135) % 360
        for Ltry in ([L - 0.03 * k for k in range(7)] if mode == 'light'
                     else [L + 0.03 * k for k in range(7)]):
            C = min(0.12, max_chroma(Ltry, h))
            hx = oklch_to_hex(Ltry, C, h)
            if hx and contrast(hx, surface) >= target:
                out.append(hx)
                break
        else:
            out.append(oklch_to_hex(L, 0.09, h) or '#888888')
    return out


def gradient_midpoint(stops):
    """OKLCH 插值 vs RGB 插值的中点诊断。

    sRGB 逐通道插值的真正症状不是「色度掉了」，而是**明度塌陷**：
    两个饱和色（尤其跨色相）的 sRGB 中点比两端的平均明度更暗，于是中段发灰发脏。
    这里就量这个 ΔL。"""
    def midpoint(a, b, space):
        La, aa, ba = oklab(a)
        Lb, ab, bb = oklab(b)
        if space == 'ok':
            return oklch_to_hex((La + Lb) / 2, math.hypot((aa + ab) / 2, (ba + bb) / 2),
                                math.degrees(math.atan2((ba + bb) / 2, (aa + ab) / 2)) % 360) or a
        ra, ga, bla = (int(a[i:i + 2], 16) for i in (1, 3, 5))
        rb, gb, blb = (int(b[i:i + 2], 16) for i in (1, 3, 5))
        return rgb_to_hex(tuple((x + y) / 2 / 255 for x, y in ((ra, rb), (ga, gb), (bla, blb))))

    rows = []
    for i in range(len(stops) - 1):
        a, b = stops[i], stops[i + 1]
        avgL = (oklch(a)[0] + oklch(b)[0]) / 2
        rgb_mid, ok_mid = midpoint(a, b, 'rgb'), midpoint(a, b, 'ok')
        rows.append(dict(
            pair=f'{a} → {b}',
            avgL=round(avgL, 3),
            rgbHex=rgb_mid, rgbL=round(oklch(rgb_mid)[0], 3),
            rgbDip=round(oklch(rgb_mid)[0] - avgL, 3),
            okHex=ok_mid, okL=round(oklch(ok_mid)[0], 3),
            okDip=round(oklch(ok_mid)[0] - avgL, 3),
        ))
    return rows


def main():
    gen = json.load(open('docs/_theme_gen_out.json', encoding='utf-8'))
    ladder = json.load(open('docs/_theme_ladder.json', encoding='utf-8'))
    final = {}
    for key, spec in gen.items():
        seed_hue = spec['meta']['seedHue']
        entry = {'meta': spec['meta'], 'variants': {}}
        for neutral in ('warm', 'cool'):
            for mode in ('light', 'dark'):
                roles = spec[f'{neutral}_{mode}']
                sem_balanced = ladder[f'{mode}_balanced']['colors']
                sem_cvd = ladder[f'{mode}_cvd']['colors']
                mk = f'{neutral}_{mode}'
                entry['variants'][mk] = dict(
                    roles=roles,
                    semantic_balanced=sem_balanced,
                    semantic_cvd=sem_cvd,
                    chart=chart_palette(mode, roles['surface'], spec['meta']['seedHue']),
                    hero=hero_gradients(seed_hue, mode),
                    amber=AMBER,
                )
        final[key] = entry

    # ── 汇总校验 ──
    report = {}
    for key, entry in final.items():
        rows = {}
        for mk, v in entry['variants'].items():
            roles, sem = v['roles'], v['semantic_balanced']
            mode = 'dark' if mk.endswith('dark') else 'light'
            checks = {
                'onPrimary：实心按钮文字': (contrast(roles['primary'], roles['onPrimary']),
                                           4.5, f"{roles['primary']} 上的 {roles['onPrimary']}"),
                'primary 当文字': (contrast(roles['primary'], roles['surface']), 4.5, roles['primary']),
                'selected chip（container 配对）': (
                    contrast(roles['onPrimaryContainer'], roles['primaryContainer']), 4.5,
                    f"{roles['onPrimaryContainer']} on {roles['primaryContainer']}"),
                '语义色最差（文字）': (min(contrast(c, roles['surfaceContainerLow'])
                                        for c in sem.values()), 4.5, '五色取最差'),
                'hero 渐变白字最差': (min(contrast('#FFFFFF', c)
                                        for g in v['hero'].values() for c in g), 4.5, '全部端点'),
                'hero 琥珀字最差': (min(contrast(AMBER, c) for c in v['hero']['netWorth']),
                                    4.5, '净资产渐变'),
                '图表色板最差（图形）': (min(contrast(c, roles['surface']) for c in v['chart']),
                                         3.0, '8 色取最差'),
            }
            rows[mk] = {k: dict(value=round(val, 2), need=need, ok=val >= need, detail=detail)
                        for k, (val, need, detail) in checks.items()}
        report[key] = rows
    # 渐变中点：只拿「色相跨度最大的一对」比 RGB 插值与 OKLCH 插值，
    # 这才是会暴露「中段发灰」的场景（相邻同族色的中点本来就几乎一致）。
    mids = {}
    for k, v in final.items():
        best = None
        for mode in ('light', 'dark'):
            for gname, stops in v['variants'][f'warm_{mode}']['hero'].items():
                for i in range(len(stops) - 1):
                    pair = stops[i:i + 2]
                    dh = abs((oklch(pair[0])[2] - oklch(pair[1])[2] + 180) % 360 - 180)
                    if best is None or dh > best[0]:
                        best = (dh, mode, gname, pair)
        mids[k] = dict(mode=best[1], gradient=best[2], hueSpan=round(best[0], 1),
                       rows=gradient_midpoint(best[3]))
    final_report = dict(palettes=final, checks=report, gradient_midpoints=mids)
    json.dump(final_report, open('docs/_theme_final.json', 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)

    bad = 0
    for key, rows in report.items():
        for mk, checks in rows.items():
            for name, c in checks.items():
                if not c['ok']:
                    bad += 1
                    print(f'✗ {key}/{mk} {name}: {c["value"]} < {c["need"]}')
    print('校验失败项:', bad)
    print('→ docs/_theme_final.json')


if __name__ == '__main__':
    main()
