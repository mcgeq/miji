"""从 **Dart 源码**（而不是设计稿 tokens2.json）里读出晴空 A 的实际取值，
重新跑一遍不变量校验，并输出一张可直接看的核对页。

为什么值得单独做：`theme_math.TOK` 读的是设计稿，Dart 里手抄错一位它发现不了。
这里直接解析 lib/core/theme/*.dart，抄错就会在图上报红。
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from theme_math import REPO_ROOT, contrast  # noqa: E402

ROOT = REPO_ROOT
TOKENS_DART = ROOT / "lib/core/theme/app_theme_tokens.dart"
DESIGN_DART = ROOT / "lib/core/theme/app_design_tokens.dart"
THEME_DART = ROOT / "lib/core/theme/app_theme.dart"

COLOR_RE = re.compile(r"Color\(0x([0-9A-Fa-f]{8})\)")
CONST_RE = re.compile(r"static const (\w+) = Color\(0x([0-9A-Fa-f]{8})\);")


def hexs(match_group):
    return "#" + match_group[2:].upper()


def block(text, header):
    """截出 `header` 起、到下一个顶层 `);` 为止的片段。"""
    start = text.index(header)
    end = text.index("\n  );", start)
    return text[start:end]


tokens_src = TOKENS_DART.read_text(encoding="utf-8")
consts = {name: hexs(value) for name, value in CONST_RE.findall(tokens_src)}


def resolve(name):
    """把 `AppThemeTokens.lightOnNetWorth` 解析成 `#10152C`。"""
    key = name.strip().split(".")[-1]
    if key in consts:
        return consts[key]
    raise KeyError(f"解析不到 {name}")


def parse_money(text, header):
    body = block(text, header)
    return {k: hexs(v) for k, v in re.findall(r"(\w+): Color\(0x([0-9A-Fa-f]{8})\)", body)}


GRADIENT_RE = re.compile(
    r"(netWorth|brand|danger): AppHeroGradient\(\s*"
    r"colors: \[([^\]]*)\],\s*"
    r"onColor: ([^,\n]+),\s*\)",
    re.S,
)


def parse_gradients(text, header):
    body = block(text, header)
    out = {}
    for name, colors, on in GRADIENT_RE.findall(body):
        out[name] = {
            "colors": [hexs(c) for c in re.findall(r"0x([0-9A-Fa-f]{8})", colors)],
            "on": resolve(on),
        }
    amber = re.search(r"amber: ([^,\n]+),", body)
    out["amber"] = resolve(amber.group(1))
    return out


def parse_chart(text, header):
    return [hexs(c) for c in COLOR_RE.findall(block(text, header))]


design_src = DESIGN_DART.read_text(encoding="utf-8")
theme_src = THEME_DART.read_text(encoding="utf-8")

SETS = {
    "light": {
        "tokens": consts,
        "money": parse_money(design_src, "static const moneyColors = AppMoneyColors("),
        "hero": parse_gradients(design_src, "static const heroGradients = AppHeroGradients("),
        "chart": parse_chart(design_src, "static const chartPalette = AppChartPalette("),
        "surface": consts["lightSurface"],
        "sunken": consts["lightSurfaceSunken"],
        "background": consts["lightBackground"],
    },
    "dark": {
        "tokens": consts,
        "money": parse_money(theme_src, "static const darkMoneyColors = AppMoneyColors("),
        "hero": parse_gradients(theme_src, "static const darkHeroGradients = AppHeroGradients("),
        "chart": parse_chart(theme_src, "static const darkChartPalette = AppChartPalette("),
        "surface": consts["darkSurface"],
        "sunken": consts["darkSurfaceSunken"],
        "background": consts["darkBackground"],
    },
}

SEM = [("income", "收入"), ("expense", "支出"), ("transfer", "转账"),
       ("credit", "信用"), ("warning", "警告")]
HERO = [("netWorth", "净资产"), ("brand", "品牌"), ("danger", "超支")]

rows = {"light": [], "dark": []}
fails = []


def add(mode, group, label, fg, bg, want, note=""):
    r = contrast(fg, bg)
    ok = r >= want
    if not ok:
        fails.append(f"{mode} {group} {label}: {r:.2f} < {want}")
    rows[mode].append({
        "group": group, "label": label, "fg": fg, "bg": bg,
        "ratio": r, "want": want, "ok": ok, "note": note,
    })


for mode, s in SETS.items():
    t, money, hero = s["tokens"], s["money"], s["hero"]
    surf, sunken = s["surface"], s["sunken"]
    t3 = "3:1" if mode == "light" else "3:1"

    # 中性面
    add(mode, "中性面", "outline 描边", t[f"{mode}Outline"], surf, 3.0, "控件边界")
    add(mode, "中性面", "text", t[f"{mode}Text"], surf, 4.5)
    add(mode, "中性面", "textSecondary", t[f"{mode}TextSecondary"], surf, 4.5)
    add(mode, "中性面", "textSecondary / 凹槽", t[f"{mode}TextSecondary"], sunken, 4.5)
    add(mode, "中性面", "textTertiary 提示层", t[f"{mode}TextTertiary"], surf, 3.0, "只求可读")

    # 主色三角色
    add(mode, "主色", "primary 当文字", t[f"{mode}Primary"], surf, 4.5, "文字/图标角色")
    add(mode, "主色", "onPrimarySolid", t[f"{mode}OnPrimarySolid"], t[f"{mode}PrimarySolid"], 4.5, "实心按钮")
    add(mode, "主色", "onPrimaryContainer", t[f"{mode}OnPrimaryContainer"], t[f"{mode}PrimaryContainer"], 4.5, "chip 选中")
    add(mode, "主色", "onSecondaryContainer", t[f"{mode}SecondaryStrong"], t[f"{mode}SecondaryContainer"], 4.5)
    add(mode, "主色", "onTertiaryContainer", t[f"{mode}TertiaryStrong"], t[f"{mode}TertiaryContainer"], 4.5)

    # 语义色三档
    for key, name in SEM:
        add(mode, "语义色 · 金额", name, money[key], surf, 3.0, "大号粗体")
    for key, name in SEM:
        add(mode, "语义色 · 小字", f"{name}Strong", money[f"{key}Strong"], surf, 4.5)
    for key, name in SEM:
        add(mode, "语义色 · 容器", f"{name} 容器字", money[f"{key}Strong"],
            money[f"{key}Container"], 4.5)

    for i, c in enumerate(s["chart"]):
        add(mode, "图表 8 色", f"chart {i + 1}", c, surf, 3.0)

    for key, name in HERO:
        g = hero[key]
        for i, c in enumerate(g["colors"]):
            add(mode, "Hero 渐变", f"{name} 第 {i + 1} 档", g["on"], c, 4.5,
                "白字" if g["on"] == "#FFFFFF" else "深字")
    for key, name in (("brand", "品牌"), ("danger", "超支")):
        for c in hero[key]["colors"]:
            add(mode, "Hero 渐变", "琥珀告警字", hero["amber"], c, 4.5)

print(f"从 Dart 源码读到 {len(consts)} 个 token")
for mode in ("light", "dark"):
    print(f"\n{mode}: {len(rows[mode])} 项")
for f in fails:
    print("  ✗ " + f)
print(f"\n失败 {len(fails)} 项")
if fails:
    sys.exit(1)


# ─────────────────── 输出核对页 ───────────────────

def swatch(color, w=26):
    return (f'<i style="display:inline-block;width:{w}px;height:14px;'
            f'border-radius:3px;background:{color};'
            f'box-shadow:inset 0 0 0 1px rgba(0,0,0,.14);vertical-align:-2px"></i>')


def ticket(r):
    cls = "pass" if r["ok"] else "fail"
    return (f'<span class="r {cls}">{r["ratio"]:.2f}</span>')


def section(mode, group):
    items = [r for r in rows[mode] if r["group"] == group]
    if not items:
        return ""
    body = "".join(
        f'<div class="row">{swatch(r["fg"], 12)}<code>{r["fg"]}</code>'
        f'<span class="lbl">{r["label"]}</span>'
        f'<span class="on">on</span>{swatch(r["bg"], 12)}<code>{r["bg"]}</code>'
        f'<span class="want">≥{r["want"]:g}</span>{ticket(r)}'
        f'<span class="note">{r["note"]}</span></div>'
        for r in items
    )
    return f'<div class="box"><h4>{group}</h4>{body}</div>'


def mode_panel(mode, title):
    t = SETS[mode]["tokens"]
    money = SETS[mode]["money"]
    core = ["Background", "Surface", "SurfaceSunken", "Text", "TextSecondary",
            "Primary", "PrimarySolid", "PrimaryContainer", "Secondary",
            "Tertiary", "Outline"]
    strip = "".join(
        f'<div class="sw">{swatch(t[f"{mode}{k}"], 46)}'
        f'<span>{k[0].lower()}{k[1:]}</span><em>{t[f"{mode}{k}"]}</em></div>'
        for k in core
    )
    sem_strip = "".join(
        f'<div class="sw">{swatch(money[k], 30)}{swatch(money[k + "Strong"], 30)}'
        f'{swatch(money[k + "Container"], 30)}<span>{n}</span></div>'
        for k, n in SEM
    )
    groups = ["中性面", "主色", "语义色 · 金额", "语义色 · 小字",
              "语义色 · 容器", "图表 8 色", "Hero 渐变"]
    return f'''
    <section class="panel {mode}" style="--bg:{t[f"{mode}Background"]};
        --srf:{t[f"{mode}Surface"]};--ink:{t[f"{mode}Text"]}">
      <h3>{title}</h3>
      <div class="strip">{strip}</div>
      <div class="strip sem">{sem_strip}</div>
      <div class="grid">{"".join(section(mode, g) for g in groups)}</div>
    </section>'''


html = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>晴空 A · 落地核对</title>
<style>
  :root{{--line:#d9dde1;--ink:#15171a;--ink2:#585b5e;--page:#f3f6f9;--card:#fff;
        --pass:#00651d;--fail:#981729;}}
  *{{box-sizing:border-box}}
  body{{margin:0;padding:28px 22px 60px;background:var(--page);color:var(--ink);
       font:14px/1.55 -apple-system,"Microsoft YaHei UI","PingFang SC",sans-serif}}
  h1{{font-size:21px;margin:0 0 6px}}
  h2{{font-size:15px;margin:34px 0 12px;padding-bottom:7px;border-bottom:1px solid var(--line)}}
  .lead{{color:var(--ink2);max-width:900px}}
  .kpi{{display:flex;gap:10px;flex-wrap:wrap;margin:16px 0 4px}}
  .kpi div{{background:var(--card);border:1px solid var(--line);border-radius:10px;
            padding:10px 14px;min-width:130px}}
  .kpi b{{display:block;font-size:20px}}
  .kpi span{{color:var(--ink2);font-size:12px}}
  .panel{{margin:20px 0;border:1px solid var(--line);border-radius:14px;overflow:hidden;
          background:var(--srf);color:var(--ink)}}
  .panel h3{{margin:0;padding:13px 16px;font-size:14px;background:var(--bg);
             border-bottom:1px solid var(--line)}}
  .strip{{display:flex;gap:14px;flex-wrap:wrap;padding:14px 16px 4px}}
  .strip.sem{{padding-top:2px}}
  .sw{{display:flex;flex-direction:column;gap:4px;font-size:11px}}
  .sw span{{font-weight:700}}
  .sw em{{font-style:normal;color:var(--ink2);font-size:10.5px}}
  .strip.sem .sw span{{margin-top:-2px}}
  .grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(370px,1fr));
         gap:14px;padding:16px}}
  .box{{background:var(--bg);border:1px solid var(--line);border-radius:10px;padding:11px 12px}}
  .box h4{{margin:0 0 8px;font-size:12.5px;color:var(--ink2);letter-spacing:.02em}}
  .row{{display:flex;align-items:center;gap:6px;padding:2.5px 0;font-size:11.5px;
        flex-wrap:wrap}}
  .row code{{font:11px ui-monospace,Consolas,monospace;color:var(--ink2)}}
  .row .lbl{{flex:1 1 auto;min-width:96px;font-weight:600}}
  .row .on{{color:var(--ink2);font-size:10px}}
  .row .want{{color:var(--ink2);font-size:10px;min-width:26px;text-align:right}}
  .r{{min-width:36px;text-align:right;font:700 11.5px ui-monospace,Consolas,monospace}}
  .pass{{color:var(--pass)}} .fail{{color:var(--fail)}}
  .note{{flex:0 0 100%;color:var(--ink2);font-size:10px;padding-left:2px}}
</style></head><body>
<h1>晴空 A（Azure）· 落地核对</h1>
<p class="lead">下面每个数字都是现场从 <code>lib/core/theme/*.dart</code> 里读出实际取值后重算的，
不是抄设计稿。<b>对比度分两档</b>：大号粗体金额与非文字图形按 <b>3:1</b>，
正文与 12px 以下的小字按 <b>4.5:1</b>。</p>
<div class="kpi"><div><b>{len(consts)}</b><span>Dart 里的 token</span></div>
<div><b>{len(rows["light"]) + len(rows["dark"])}</b><span>条断言</span></div>
<div><b>0</b><span>未达标</span></div></div>
{mode_panel("light", "浅色 · 灰底白卡 + 宝蓝")}
{mode_panel("dark", "深色 · 深灰蓝重定档")}
<h2>这套配色为什么长这样</h2>
<div class="box">
<p style="margin:0 0 8px"><b>1 · 中性面近乎无彩，层级靠白浮在灰上。</b>
旧体系四级只差 4% 明度，肉眼分不出来；现在背景灰 <code>{consts["lightBackground"]}</code>、
卡片纯白，<code>surface</code> 与 <code>raised</code> 刻意同色，靠阴影与描边分层。</p>
<p style="margin:0 0 8px"><b>2 · 主色拆三个角色。</b>
<code>primary</code> <code>{consts["lightPrimary"]}</code> 只做文字/图标（全库 230 处在用，必须过 4.5）；
<code>primarySolid</code> <code>{consts["lightPrimarySolid"]}</code> 做按钮/FAB 底，配
<code>onPrimarySolid</code> <code>{consts["lightOnPrimarySolid"]}</code> 这个<b>深字</b>；
<code>primaryContainer</code> 做 chip 浅底。旧体系把「文字色」和「填充色」塞进同一槽位，必然打架。</p>
<p style="margin:0 0 8px"><b>3 · 语义色拆两档。</b>
金额是超大号粗体，WCAG 只要 3:1，所以拿到 <code>{SETS["light"]["money"]["income"]}</code>
这种正绿；小号文字另配 <code>*Strong</code> 深版守 4.5。旧体系按 4.5 卡全套，
只能退成 <code>#0D5900</code> 墨绿，一屏金额看着像蒙了灰。</p>
<p style="margin:0"><b>4 · Hero 三张卡按用途定死，正文色由 token 给。</b>
净资产卡是亮蓝渐变，白字只有 2~3:1 → 配深字 <code>{consts["lightOnNetWorth"]}</code>；
品牌石墨卡、超支深红卡才配白字。代码里不再写死 <code>Colors.white</code>。</p>
</div>
</body></html>
'''

out = ROOT / "docs/specs/theme-azure-applied.html"
out.write_text(html, encoding="utf-8")
print(f"\n已写出 {out.relative_to(ROOT)}")
