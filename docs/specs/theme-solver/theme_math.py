"""晴空 A 校验脚本共用的色彩数学：WCAG 对比度 + OKLab ΔE。"""
import json
import math
import pathlib


def _repo_root():
    """从本文件往上找含 pubspec.yaml 的目录（脚本被放在 docs/ 深处，硬编码层数不牢靠）。"""
    here = pathlib.Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "pubspec.yaml").exists():
            return parent
    raise RuntimeError("找不到仓库根目录（没有 pubspec.yaml）")


_ROOT = _repo_root()
REPO_ROOT = _ROOT
TOK = json.loads(
    (_ROOT / "docs/specs/theme-solver/tokens2.json").read_text(encoding="utf-8")
)

SEM = [("income", "收入"), ("expense", "支出"), ("transfer", "转账"),
       ("credit", "信用"), ("warning", "警告")]
HERO = [("netWorth", "净资产"), ("brand", "品牌"), ("danger", "超支")]


def rgb(hexs):
    h = hexs.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def lum(hexs):
    r, g, b = rgb(hexs)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def blend(fg, bg, alpha):
    f, b = rgb(fg), rgb(bg)
    out = [f[i] * alpha + b[i] * (1 - alpha) for i in range(3)]
    return "#" + "".join(f"{round(max(0.0, min(1.0, c)) * 255):02X}" for c in out)


def srgb_to_oklab(hexs):
    r, g, b = rgb(hexs)

    def f(c):
        return c ** (1 / 3) if c > 0.04045 else c / 12.92

    l = 0.4122214708 * f(r) + 0.5363325363 * f(g) + 0.0514459929 * f(b)
    m = 0.2119034982 * f(r) + 0.6806995451 * f(g) + 0.1073969566 * f(b)
    s = 0.0883024619 * f(r) + 0.2817188376 * f(g) + 0.6299787005 * f(b)
    l_, m_, s_ = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    return (
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    )


def dE(a, b):
    A, B = srgb_to_oklab(a), srgb_to_oklab(b)
    return math.sqrt(sum((A[i] - B[i]) ** 2 for i in range(3)))
