"""米记主题配色求解 / 校验器。

只做三件事：
1. OKLCH -> sRGB hex（越界就降彩度，绝不靠裁剪产生色偏）
2. WCAG 对比度校验（正文 4.5、大字/控件 3.0、分隔线只求可见）
3. Viénot 色觉缺陷模拟下的 OKLab ΔE（语义色/图表色两两可分辨）

输出给 docs/specs/theme-redesign-mockup.html 用。
"""
import math
import itertools

# ─────────────────────────── 色彩空间 ───────────────────────────


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    if c <= 0.0031308:
        return 12.92 * c
    return 1.055 * (c ** (1 / 2.4)) - 0.055


def _oklab_to_lrgb(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def _lrgb_to_oklab(r, g, b):
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    return (
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    )


def oklch_to_hex(L, C, H):
    """越界时二分降彩度（保色相与明度），而不是裁剪 RGB。"""
    def attempt(chroma):
        a = chroma * math.cos(math.radians(H))
        b = chroma * math.sin(math.radians(H))
        return _oklab_to_lrgb(L, a, b)

    rgb = attempt(C)
    if all(-0.0005 <= v <= 1.0005 for v in rgb):
        channels = rgb
    else:
        lo, hi = 0.0, C
        for _ in range(40):
            mid = (lo + hi) / 2
            if all(-0.0005 <= v <= 1.0005 for v in attempt(mid)):
                lo = mid
            else:
                hi = mid
        channels = attempt(lo)
    vals = [max(0.0, min(1.0, v)) for v in channels]
    return "#%02X%02X%02X" % tuple(round(linear_to_srgb(v) * 255) for v in vals)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hex_to_oklab(h):
    r, g, b = hex_to_rgb(h)
    return _lrgb_to_oklab(srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b))


def rel_lum(h):
    r, g, b = hex_to_rgb(h)
    return (0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g)
            + 0.0722 * srgb_to_linear(b))


def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


CVD = {
    "protan": ((0.567, 0.433, 0.0), (0.558, 0.442, 0.0), (0.0, 0.242, 0.758)),
    "deutan": ((0.625, 0.375, 0.0), (0.700, 0.300, 0.0), (0.0, 0.300, 0.700)),
    "tritan": ((0.950, 0.050, 0.0), (0.0, 0.433, 0.567), (0.0, 0.475, 0.525)),
}


def simulate(h, kind):
    r, g, b = (srgb_to_linear(v) for v in hex_to_rgb(h))
    m = CVD[kind]
    out = tuple(sum(m[i][j] * (r, g, b)[j] for j in range(3)) for i in range(3))
    out = tuple(max(0.0, min(1.0, v)) for v in out)
    return "#%02X%02X%02X" % tuple(round(linear_to_srgb(v) * 255) for v in out)


def delta_e(h1, h2):
    a, b = hex_to_oklab(h1), hex_to_oklab(h2)
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def cvd_delta_e(h1, h2):
    """三种色觉缺陷下最差的可分辨度。"""
    return min(delta_e(simulate(h1, k), simulate(h2, k)) for k in CVD)
