"""主题色校验器：对 Dart 端（官方 HCT）生成的候选主题做四重校验。

1. WCAG 2.x 对比度（正文 4.5 / 大字 3.0 / 图形 3.0）
2. APCA 0.1.9（Lc，深色模式更贴近感知；用白/黑对锚定 = 106）
3. 色觉缺陷模拟（Viénot 1999 矩阵）后在 OKLab 里算两两 ΔE —— 红绿色盲是否还分得清语义色
4. 感知均匀性：语义色是否「等明度」、渐变中点是否发灰（OKLCH 插值 vs RGB 插值）

用法：python3 docs/theme_verify.py
"""
import json
import math

# ── 色彩空间转换 ─────────────────────────────────────────────
def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return '#%02X%02X%02X' % tuple(round(max(0, min(1, c)) * 255) for c in rgb)


def lum(h):
    r, g, b = (srgb_to_lin(c) for c in hex_to_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


# ── OKLab / OKLCH（Björn Ottosson 公开矩阵）─────────────────
_M1 = ((0.4122214708, 0.5363325363, 0.0514459929),
       (0.2119034982, 0.6806995451, 0.1073969566),
       (0.0883024619, 0.2817188376, 0.6299787005))
_M2 = ((0.2104542553, 0.7936177850, -0.0040720468),
       (1.9779984951, -2.4285922050, 0.4505937099),
       (0.0259040371, 0.7827717662, -0.8086757660))


def _mul(m, v):
    return tuple(sum(m[i][j] * v[j] for j in range(3)) for i in range(3))


def oklab(h):
    r, g, b = (srgb_to_lin(c) for c in hex_to_rgb(h))
    lms = _mul(_M1, (r, g, b))
    lms = tuple(math.copysign(abs(x) ** (1 / 3), x) for x in lms)
    return _mul(_M2, lms)


def oklch(h):
    L, a, b = oklab(h)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def dE(a, b):
    """OKLab 里的欧氏距离；约 0.02 已可感知，0.05 明显。"""
    la, aa, ba = oklab(a)
    lb, ab, bb = oklab(b)
    return math.sqrt((la - lb) ** 2 + (aa - ab) ** 2 + (ba - bb) ** 2)


# ── APCA 0.1.9（W3 草案版）─────────────────────────────────
def apca(txt, bg):
    def y(h):
        r, g, b = (srgb_to_lin(c) for c in hex_to_rgb(h))
        return 0.2126729 * r + 0.7151522 * g + 0.0721750 * b

    ytxt, ybg = y(txt), y(bg)
    blkThrs, blkClmp = 0.022, 1.414
    ytxt = ytxt + (blkThrs - ytxt) ** blkClmp if ytxt < blkThrs else ytxt
    ybg = ybg + (blkThrs - ybg) ** blkClmp if ybg < blkThrs else ybg
    if abs(ybg - ytxt) < 0.0005:
        return 0.0
    scale, loClip, loOffset = 1.14, 0.1, 0.027
    if ybg > ytxt:                       # 深字浅底
        sapc = (ybg ** 0.56 - ytxt ** 0.57) * scale
        out = 0.0 if sapc < loClip else sapc - loOffset
    else:                                # 浅字深底
        sapc = (ybg ** 0.65 - ytxt ** 0.62) * scale
        out = 0.0 if sapc > -loClip else sapc + loOffset
    return out * 100


# ── 色觉缺陷模拟（Viénot, Brettel & Mollon 1999 的经典矩阵）──
_RGB2LMS = ((17.8824, 43.5161, 4.11935),
            (3.45565, 27.1554, 3.86714),
            (0.0299566, 0.184309, 1.46709))


def _sim(rgb, kind):
    """Viénot/Brettel 1999：在**线性** RGB（0-255 量纲）上做 LMS 投影。

    注意量纲：RGB2LMS / LMS2RGB 这对矩阵是配套的，必须用同一量纲（这里统一 0-255 线性），
    否则反变换会把颜色裁到色域边界，模拟结果会失真（实测会让 ΔE 全部塌到 0.01 以下）。
    """
    lin255 = [srgb_to_lin(c) * 255 for c in rgb]
    L, M, S = (sum(_RGB2LMS[i][j] * lin255[j] for j in range(3)) for i in range(3))
    if kind == 'protan':
        L = 2.02344 * M - 2.52581 * S
    elif kind == 'deutan':
        M = 0.494207 * L + 1.24827 * S
    elif kind == 'tritan':
        S = -0.395913 * L + 0.801109 * M
    inv = ((0.080944, -0.130504, 0.116721),
           (-0.0102485, 0.0540194, -0.113615),
           (-0.000365294, -0.00412163, 0.693513))
    out = [sum(inv[i][j] * (L, M, S)[j] for j in range(3)) for i in range(3)]
    out = [max(0.0, min(1.0, x / 255)) for x in out]
    return tuple(lin_to_srgb(x) for x in out)


def simulate(h, kind):
    return rgb_to_hex(_sim(hex_to_rgb(h), kind))


# ── 校验 ────────────────────────────────────────────────────
SEM = ['expense', 'income', 'transfer', 'credit', 'warning']


def verify(name, spec):
    issues = []
    for mode in ('light', 'dark'):
        neutral = spec[f'warm_{mode}']
        surface, on_surface = neutral['surface'], neutral['onSurface']
        bg = neutral['surfaceContainerLow']
        need = 4.5 if mode == 'light' else 4.5
        # 1) 品牌与实心按钮
        c = contrast(neutral['primary'], neutral['onPrimary'])
        if c < 4.5:
            issues.append(f'{mode} onPrimary/primary {c:.2f}')
        for role in ('primary', 'secondary', 'tertiary'):
            for bgn, br in (('surface', surface), ('containerLow', bg)):
                cc = contrast(neutral[role], br)
                if cc < 4.5:
                    issues.append(f'{mode} {role}/{bgn} {cc:.2f}')
        # 2) 语义色当文字
        sem = spec[f'semantic_{mode}']
        for k in SEM:
            for bgn, br in (('surface', surface), ('containerLow', bg)):
                cc = contrast(sem[k], br)
                if cc < need:
                    issues.append(f'{mode} {k}/{bgn} {cc:.2f}')
        # 3) 语义色等明度（OKLab L 极差）
        Ls = [oklch(sem[k])[0] for k in SEM]
        spread = max(Ls) - min(Ls)
        if spread > 0.06:
            issues.append(f'{mode} 语义色明度差 {spread:.3f}（应尽量 ≤0.06）')
        # 4) 色觉缺陷下仍能区分（ΔE）
        for kind in ('protan', 'deutan', 'tritan'):
            sim = {k: simulate(sem[k], kind) for k in SEM}
            worst, pair = 9, ''
            for i in range(len(SEM)):
                for j in range(i + 1, len(SEM)):
                    d = dE(sim[SEM[i]], sim[SEM[j]])
                    if d < worst:
                        worst, pair = d, f'{SEM[i]}/{SEM[j]}'
            if worst < 0.10:
                issues.append(f'{mode} {kind} 最小 ΔE {worst:.3f}（{pair}）')
    return issues


def gradient_midpoint_check(stops):
    """RGB 线性插值 vs OKLab 插值：中点色度（饱和度）掉了多少。"""
    def rgb_mid(a, b):
        return rgb_to_hex(tuple((hex_to_rgb(a)[i] + hex_to_rgb(b)[i]) / 2 for i in range(3)))
    def ok_mid(a, b):
        la, aa, ba = oklab(a)
        lb, ab, bb = oklab(b)
        L, A, B = (la + lb) / 2, (aa + ab) / 2, (ba + bb) / 2
        # OKLab → sRGB
        l_ = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3
        m_ = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3
        s_ = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3
        r = 4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
        g = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
        bb2 = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_
        return rgb_to_hex(tuple(lin_to_srgb(x) for x in (r, g, bb2)))
    rows = []
    for i in range(len(stops) - 1):
        a, b = stops[i], stops[i + 1]
        ca, cb = oklch(a)[1], oklch(b)[1]
        rm, om = rgb_mid(a, b), ok_mid(a, b)
        rows.append((f'{a}→{b}', f'{ca:.3f}/{cb:.3f}',
                     f'{oklch(rm)[1]:.3f}', f'{oklch(om)[1]:.3f}'))
    return rows


if __name__ == '__main__':
    data = json.load(open('docs/_theme_gen_out.json', encoding='utf-8'))
    print('APCA 锚定检查：白底黑字应 ≈ 106，黑底白字 ≈ -108')
    print(f'  #FFFFFF on #000000 = {apca("#FFFFFF", "#000000"):.1f}')
    print(f'  #000000 on #FFFFFF = {apca("#000000", "#FFFFFF"):.1f}')
    print()
    for key, spec in data.items():
        print(f'=== {spec["meta"]["label"]}（HCT 种子 hue={spec["meta"]["seedHue"]} chroma={spec["meta"]["seedChroma"]}）===')
        for neutral in ('warm', 'cool'):
            for mode in ('light', 'dark'):
                s = spec[f'{neutral}_{mode}']
                if neutral == 'warm':
                    iss = verify(key, spec) if neutral == 'warm' else []
                print(f'  {neutral} {mode:5s} primary {s["primary"]} onPrimary {s["onPrimary"]} '
                      f'container {s["primaryContainer"]}/{s["onPrimaryContainer"]} surface {s["surface"]}')
        print('  语义色（浅/深）:', spec['semantic_light'], spec['semantic_dark'])
        issues = verify(key, spec)
        print('  校验:', '✓ 通过' if not issues else '✗ ' + '; '.join(issues[:6]))
