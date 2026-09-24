"""生成 docs/theme-redesign-v2-preview.html（体系化主题设计对比页）。

页面内容：
1 设计依据（理论 → 落成的约束）+ 竞品结构观察
2 现状诊断（沿用上一轮实测，新增色盲实测）
3 三个方案（M3 角色 + 语义色双策略 + 渐变 + 图表色板 + 校验）
4 校验总表（WCAG / APCA / 色觉缺陷 ΔE）
5 色盲模拟 + 实时预览（CSS 变量换肤 + feColorMatrix 滤镜）
6 决策与导出
"""
import json

D = json.load(open('docs/_theme_final.json', encoding='utf-8'))
PALETTES, CHECKS = D['palettes'], D['checks']

# 现状（上一轮解析自源码）——用于「现状 vs 新方案」对照
CURRENT = {
    'light': dict(primary='#E45F4F', onPrimary='#FFFFFF', primaryContainer='#FCDFDA',
                  onPrimaryContainer='#7A2418', secondary='#21A78B', tertiary='#D85C93',
                  surface='#FFFFFF', surfaceContainerLow='#FFF0E5', outline='#EAD8CC',
                  semantic={'expense': '#CD323F', 'income': '#157F41', 'transfer': '#2270BF',
                            'credit': '#8757BE', 'warning': '#856C06'},
                  chart=['#E45F4F', '#D85C93', '#FB8C00', '#00897B', '#3F51B5', '#EC407A', '#00BCD4', '#8757BE'],
                  hero=dict(brand=['#C25144', '#C0515C', '#BE506A'],
                            netWorth=['#6C507B', '#2C8089'],
                            danger=['#9E001D', '#B00020', '#BD1D45']),
                  amber='#FFD9A0'),
    'dark': dict(primary='#FF9A88', onPrimary='#FFFFFF', primaryContainer='#7A2E22',
                 onPrimaryContainer='#FFDAD4', secondary='#7AE1C8', tertiary='#FFADD1',
                 surface='#241C19', surfaceContainerLow='#30231E', outline='#57433A',
                 semantic={'expense': '#FF9AAF', 'income': '#7ED8A6', 'transfer': '#A8BFFF',
                           'credit': '#FFC27A', 'warning': '#FFC66B'},
                 chart=['#FF9A88', '#FFADD1', '#FB8C00', '#00897B', '#3F51B5', '#EC407A', '#00BCD4', '#FFC27A'],
                 hero=dict(brand=['#8A5349', '#8B5A62', '#8C5F73'],
                           netWorth=['#74608B', '#4A7D85'],
                           danger=['#703741', '#8E4250', '#AA5463']),
                 amber='#FFD9A0'),
}
NAMES = {'ink': 'V1 墨蓝 · 暖白', 'jade': 'V2 青碧 · 中性', 'plum': 'V3 绛紫 · 暖白'}

THEORY = [
    ('对立过程理论（Hering 1878）',
     '人眼把颜色编码成红—绿、蓝—黄两对对立通道。红绿同属一个通道 → 红绿色盲（约 8% 男性）看不出红绿差别。',
     '① 支出/收入不能只靠红绿区分；② 必须叠加明度差或符号（App 里金额都带 +/−）。'),
    ('色觉缺陷设计（Okabe & Ito 2008；Wong, Nature Methods 2011）',
     '色盲友好不是"换一套色"，而是"不要只靠色相"：用明度差 + 形状/文字做冗余编码。',
     '语义色策略提供「色盲强化型」：明度跨度 0.15，色盲下最小 ΔE 从 0.015 提到 0.10+。'),
    ('感知均匀色彩空间（Ottosson 2020 OKLab；Google HCT）',
     'CIELAB/OKLab 里「相同 L」才等于「看起来一样亮」。sRGB/HSL 里黄色天生比蓝色亮得多，直接调不出均衡的色板。',
     '① 语义色与图表色板全部在 OKLCH 里按 L 定档；② M3 角色用官方 HCT/色调板生成。'),
    ('无障碍对比度（WCAG 2.2 SC 1.4.3/1.4.11；APCA W3 草案）',
     '正文 4.5:1、大字号 3:1、非文字图形 3:1。APCA 用感知对比（Lc）衡量，在深色模式下比 WCAG 2 的公式更贴近观感。',
     '每个关键配对都过 WCAG；再用 APCA 复核（页面给出 Lc 值，白/黑锚定 = 106）。'),
    ('Material 3 色彩角色（Google M3）',
     'primary 是「交互色」，secondary 是 primary 的弱化版，**不是第二个语义色**；onX/primaryContainer 是成对出现的。',
     '① 不再把 secondary 当「收入绿」；② 选中态改用 primaryContainer/onPrimaryContainer 配对（实测 8~13:1）。'),
    ('分类色编码（Ware《Information Visualization》；ColorBrewer, Brewer 2003）',
     '定性色板靠色相区分、明度保持接近；可用色相数量有限（6~8 个），再多的分类必须靠分组或标注。',
     '图表色板固定 8 色、等明度、相邻切片色相相距 135°、对比度 ≥3:1。'),
]

COMPETITORS = [
    ('品牌色几乎不占「红」这个语义槽位', '国内随手记/鲨鱼/钱迹、国外 YNAB/Monarch/Copilot/Money Manager 的主流做法是把品牌放在蓝、绿、紫或黑，红色留给「支出/超支」。', '我们的现状恰好相反：品牌 #E45F4F 与支出 #CD323F 只差 11.5° → 三个方案都把品牌移出红色区。'),
    ('语义红绿只用于金额，且一定叠加符号或文字', '几乎看不到只用颜色表示收支的地方，金额前都有 +/− 或「收入/支出」标签。', '本方案保留 +/− 冗余，并把这一点写进设计约束（色觉缺陷策略的替代方案）。'),
    ('中性面低饱和，品牌色是唯一的强调色', '主流 App 的底色要么暖白要么冷灰，饱和度都很低（明度分层而不是靠颜色分层）；一屏内强调色不超过 2 个。', '三个方案的中性面 chroma 都 ≤7（HCT），品牌色只在按钮/选中/图标上出现。'),
    ('深色主题是独立设计的明度阶梯，不是「浅色调暗」', '深色模式普遍重新定档：表面用 3~4 级明度分层（不做纯黑），语义色提亮并降饱和，避免暗底上的晕光。', '本方案用 M3 的 surfaceContainer 5 级阶梯 + 深色语义色单独求解（对比度门槛提到 7:1）。'),
]

DECISIONS = [
    ('D1', '品牌色走哪个方案', 'V1 墨蓝（最稳）/ V2 青碧（最中性）/ V3 绛紫（最接近 M3 默认审美）。三个方案的品牌色都满足：可当文字 ≥4.5、配 onPrimary 做实心按钮 ≥4.5、与支出红夹角 ≥90°。', '推荐 V1 墨蓝'),
    ('D2', '中性面用暖白还是冷灰', '暖白（chroma 7、色相 68°）让"暖米记"的气质保留；冷灰（chroma 4、色相 250°）更工具感。三个方案各自都可以切。', '推荐暖白'),
    ('D3', '语义色用「均衡型」还是「色盲强化型」', '均衡型：明度跨度 0.08，五色看起来一样重、最鲜亮；色盲下最小 ΔE 约 0.04~0.07，靠 +/− 与文字冗余（符合 WCAG 1.4.1）。色盲强化型：跨度 0.15，色盲最小 ΔE ≥0.10，不依赖颜色也能分辨；代价是明暗不齐。', '推荐色盲强化型'),
    ('D4', 'Hero 渐变的色系', '品牌渐变：品牌色相邻色相弧 + 三档明度梯度（5.4/4.9/4.6 对比度目标）。净资产渐变：固定「紫 → 青」（这是你认可的那张卡）；告警渐变：红 → 深紫红。', '推荐按方案默认'),
    ('D5', '图表色板是否 token 化', '新增 AppChartPalette（浅/深各 8 色，等明度、相邻色相 135°、≥3:1），四张图共用同一顺序，替掉现在的 4 套 Material 原色。', '推荐做'),
    ('D6', '分类自定义色是否改为「色相 + 主题求明度」', '现状 15 色色板在两套主题下都有不达标（浅 6 / 深 2）。改为用户选色相、明度由主题求解，可两套主题全部 ≥3:1。', '推荐做'),
    ('D7', '是否接回 themeSeedColor', '这个偏好字段有列、有默认值，但主题从未读取（死配置）。要么真的支持换主题色（用本页的求解器按色相生成），要么删列。', '推荐接回（色相可换）'),
    ('D8', '深色底亮度', '现状 #1B1412 很暗；M3 阶梯给的是 #19120A（暖）/ #121316（冷）。可整体提亮一档更利于长时间阅读，也可保持。', '推荐按 M3 阶梯'),
]

CVD_MATRICES = {
    'protan': '0.152286 1.052583 -0.204868 0 0  0.114503 0.786281 0.099216 0 0  -0.003882 -0.048116 1.051998 0 0  0 0 0 1 0',
    'deutan': '0.367322 0.860646 -0.227968 0 0  0.280085 0.672501 0.047413 0 0  -0.011820 0.042940 0.968881 0 0  0 0 0 1 0',
    'tritan': '1.255528 -0.076749 -0.178779 0 0  -0.078411 0.930809 0.147602 0 0  0.004733 0.691367 0.303900 0 0  0 0 0 1 0',
}


def hexof(v):
    return v


def sw(colors, labels=None):
    out = ['<div class="sw">']
    for i, c in enumerate(colors):
        t = labels[i] if labels and i < len(labels) else c
        out.append(f'<i style="background:{c}" title="{t}"></i>')
    out.append('</div>')
    return ''.join(out)


def variant_data(key, neutral, mode, strategy):
    v = PALETTES[key]['variants'][f'{neutral}_{mode}']
    roles = v['roles']
    sem = v['semantic_cvd'] if strategy == 'cvd' else v['semantic_balanced']
    return roles, sem, v


def scheme_card(key):
    meta = PALETTES[key]['meta']
    wl = PALETTES[key]['variants']['warm_light']
    wd = PALETTES[key]['variants']['warm_dark']
    ck = CHECKS[key]['warm_light']
    key_rows = ''.join(
        f'<tr><td>{n}</td><td>{c["value"]}</td><td>{c["need"]}</td>'
        f'<td>{"✓" if c["ok"] else "✗"}</td><td class="tiny">{c["detail"]}</td></tr>'
        for n, c in ck.items())
    return f'''<div class="card">
  <div style="display:flex;align-items:baseline;gap:8px"><b style="font-size:15px">{NAMES[key]}</b>
    <span class="chip good">HCT 种子 H{meta['seedHue']:.0f} C{meta['seedChroma']:.0f}</span></div>
  <div class="tiny" style="font-weight:700;margin-top:10px">M3 角色 · 浅色</div>
  {sw([wl['roles']['primary'], wl['roles']['onPrimary'], wl['roles']['primaryContainer'],
       wl['roles']['onPrimaryContainer'], wl['roles']['tertiary'], wl['roles']['surface'],
       wl['roles']['surfaceContainerLow'], wl['roles']['outline']])}
  <div class="tiny" style="font-weight:700;margin-top:10px">M3 角色 · 深色</div>
  {sw([wd['roles']['primary'], wd['roles']['onPrimary'], wd['roles']['primaryContainer'],
       wd['roles']['onPrimaryContainer'], wd['roles']['tertiary'], wd['roles']['surface'],
       wd['roles']['surfaceContainerLow'], wd['roles']['outline']])}
  <div class="tiny" style="font-weight:700;margin-top:10px">语义色 · 均衡型（浅 / 深）</div>
  {sw(list(wl['semantic_balanced'].values()))}{sw(list(wd['semantic_balanced'].values()))}
  <div class="tiny" style="font-weight:700;margin-top:10px">语义色 · 色盲强化型（浅 / 深）</div>
  {sw(list(wl['semantic_cvd'].values()))}{sw(list(wd['semantic_cvd'].values()))}
  <div class="tiny" style="font-weight:700;margin-top:10px">品牌渐变 / 净资产渐变 / 告警渐变（浅色）</div>
  <div class="grad" style="background:linear-gradient(135deg,{','.join(wl['hero']['brand'])})"></div>
  <div class="grad" style="background:linear-gradient(135deg,{','.join(wl['hero']['netWorth'])})"></div>
  <div class="grad" style="background:linear-gradient(135deg,{','.join(wl['hero']['danger'])})"></div>
  <div class="tiny" style="font-weight:700;margin-top:10px">图表色板（8 色 · 与品牌同族）</div>
  {sw(wl['chart'])}
  <table style="margin-top:12px"><thead><tr><th>校验（浅色）</th><th>实测</th><th>要求</th><th></th><th></th></tr></thead>
  <tbody>{key_rows}</tbody></table>
</div>'''


CSS = """
*{box-sizing:border-box}
body{margin:0;background:#F5F3F0;color:#211F1D;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei UI","Microsoft YaHei",sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:1220px;margin:0 auto;padding:26px 20px 90px}
h1{font-size:26px;letter-spacing:-.02em;margin:0 0 8px}
h2{font-size:17px;margin:36px 0 6px}
h2 .n{display:inline-grid;place-items:center;width:22px;height:22px;border-radius:7px;background:#211F1D;color:#fff;font-size:12px;margin-right:8px;vertical-align:1px}
p.sub{margin:0 0 14px;color:#6B655F;font-size:13px;line-height:1.7}
.card{background:#fff;border:1px solid #E6E0D9;border-radius:16px;padding:18px;box-shadow:0 1px 2px rgba(60,40,30,.04)}
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
table{width:100%;border-collapse:collapse;font-size:12.5px}
th{text-align:left;font-size:10.5px;letter-spacing:.08em;text-transform:uppercase;color:#8A8178;padding:0 8px 8px;border-bottom:1px solid #E6E0D9}
td{padding:8px;border-bottom:1px solid #F2EEE9;vertical-align:top}
tr:last-child td{border-bottom:0}
code{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:11.5px;background:#F3EFEA;border:1px solid #E6E0D9;border-radius:5px;padding:1px 5px}
.chip{display:inline-block;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:700}
.bad{background:#FDE7EA;color:#B3203A}.warn{background:#FDF1DF;color:#8A5A12}.good{background:#E4F5EC;color:#14603A}
.sw{display:flex;gap:5px;flex-wrap:wrap;margin:6px 0 0}
.sw i{width:30px;height:30px;border-radius:8px;display:block;border:1px solid rgba(0,0,0,.07)}
.grad{height:24px;border-radius:8px;margin-top:6px}
.bar{position:sticky;top:0;z-index:9;background:rgba(245,243,240,.93);backdrop-filter:blur(8px);border-bottom:1px solid #E6E0D9;padding:11px 0}
.bar .row{max-width:1220px;margin:0 auto;padding:0 20px;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.seg{display:flex;gap:3px;padding:3px;background:#E9E3DC;border-radius:999px}
.seg button{border:0;background:transparent;padding:6px 12px;border-radius:999px;font-size:12.5px;font-weight:600;cursor:pointer;color:#6B655F}
.seg button.on{background:#fff;color:#211F1D;box-shadow:0 1px 3px rgba(0,0,0,.08)}
.btn{padding:8px 14px;border-radius:10px;border:0;background:#211F1D;color:#fff;font-size:12.5px;font-weight:700;cursor:pointer}
.tiny{font-size:11.5px;color:#8A8178}
.pv{border-radius:18px;padding:16px;background:var(--surface);color:var(--fg)}
.pvTitle{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:#8A8178;font-weight:800;margin:0 0 10px}
.mHero{border-radius:16px;padding:16px;color:#fff;background:linear-gradient(135deg,var(--hb0),var(--hb1) 55%,var(--hb2))}
.mHero .amt{font-size:30px;font-weight:800;letter-spacing:-.02em;margin:4px 0 8px}
.mHero .bd{font-size:11.5px;opacity:.95;display:grid;gap:3px}
.mHero .bd div{display:flex;justify-content:space-between}
.pbar{height:5px;border-radius:3px;background:rgba(255,255,255,.25);margin-top:9px;position:relative;overflow:hidden}
.pbar i{position:absolute;inset:0 62% 0 0;background:#fff;border-radius:3px;display:block}
.pbar.warn i{background:var(--amber);inset:0 18% 0 0}
.mNet{border-radius:16px;padding:16px;color:#fff;background:linear-gradient(135deg,var(--hn0),var(--hn1))}
.mNet .row{display:flex;gap:18px;margin-top:8px;font-size:11.5px}
.mNet .row b{display:block;font-size:15px;font-weight:800}
.mNet .amber{color:var(--amber)}
.mList{border:1px solid var(--line);border-radius:14px;overflow:hidden;margin-top:12px}
.mRow{display:flex;align-items:center;gap:10px;padding:11px 12px;border-bottom:1px solid var(--line);font-size:13px}
.mRow:last-child{border-bottom:0}
.mRow .ic{width:30px;height:30px;border-radius:9px;display:grid;place-items:center;font-size:14px}
.mRow .amt{margin-left:auto;font-weight:800;font-variant-numeric:tabular-nums}
.mForm{border:1px solid var(--line);border-radius:14px;padding:12px;display:grid;gap:10px;margin-top:12px}
.mSeg{display:flex;gap:3px;padding:3px;background:var(--chipbg);border-radius:999px;font-size:12px;font-weight:700}
.mSeg span{flex:1;text-align:center;padding:6px 0;border-radius:999px}
.mSeg .on{background:var(--primary);color:var(--onprimary)}
.mChip{border:1px solid var(--line);border-radius:10px;padding:7px 11px;font-size:12px;display:inline-block;background:var(--surface)}
.mChip .p{display:block;font-size:9.5px;color:var(--fg2)}
.mChip.on{border-color:var(--pc);background:var(--pc);color:var(--opc)}
.mChip.solid{background:var(--primary);color:var(--onprimary);border-color:var(--primary);font-weight:700}
.mChart{display:flex;gap:12px;align-items:flex-end;height:96px;border-bottom:1px solid var(--line);margin-top:14px}
.mChart .b{flex:1;border-radius:6px 6px 2px 2px}
.mPie{width:96px;height:96px;border-radius:50%;flex:none;background:conic-gradient(var(--c0) 0 22%,var(--c1) 0 40%,var(--c2) 0 56%,var(--c3) 0 70%,var(--c4) 0 86%,var(--c5) 0 100%)}
.mLegend{display:grid;gap:5px;font-size:11.5px;color:var(--fg2)}
.mLegend i{width:9px;height:9px;border-radius:3px;display:inline-block;margin-right:6px}
.mAlert{border-radius:12px;padding:10px 12px;font-size:12.5px;margin-top:8px}
.mAlert.fill{background:var(--warningfill);color:var(--fg)}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media(max-width:900px){.grid3,.pair{grid-template-columns:1fr}}
textarea{width:100%;min-height:200px;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:11.5px;border:1px solid #E6E0D9;border-radius:12px;padding:12px;background:#fff}
.dec{display:grid;gap:12px}
.dec label{display:grid;grid-template-columns:22px 1fr;gap:10px;align-items:start;font-size:13px;cursor:pointer}
.dec b{display:block;font-size:13.5px}
.dec em{font-style:normal;color:#6B655F;font-size:12.5px;line-height:1.65}
.dec .tag{font-size:10.5px;font-weight:800;padding:1px 7px;border-radius:999px;margin-left:6px}
"""


def preview(mode, key, neutral, strategy):
    v = PALETTES[key]['variants'][f'{neutral}_{mode}']
    r, sem, _ = variant_data(key, neutral, mode, strategy)
    hero, net = v['hero']['brand'], v['hero']['netWorth']
    chart = v['chart']
    light = mode == 'light'
    styles = (f'--primary:{r["primary"]};--onprimary:{r["onPrimary"]};'
              f'--pc:{r["primaryContainer"]};--opc:{r["onPrimaryContainer"]};'
              f'--expense:{sem["expense"]};--income:{sem["income"]};--transfer:{sem["transfer"]};'
              f'--credit:{sem["credit"]};--warning:{sem["warning"]};--amber:{v["amber"]};'
              f'--warningfill:{"#F3E7CE" if light else "#3A2E14"};'
              f'--surface:{r["surface"]};--line:{r["outline"]};--chipbg:{r["surfaceContainerLow"]};'
              f'--fg:{"#221A12" if light else "#EDE7E1"};--fg2:{"#6B655F" if light else "#B0A79F"};'
              f'--hb0:{hero[0]};--hb1:{hero[1]};--hb2:{hero[2]};--hn0:{net[0]};--hn1:{net[1]};'
              + ''.join(f'--c{i}:{c};' for i, c in enumerate(chart[:6])))
    bars = ''.join(
        f'<div class="b" style="height:{h}%;background:{chart[i % len(chart)]}"></div>'
        for i, h in enumerate([46, 78, 58, 92, 40, 66]))
    legend = ''.join(
        f'<span><i style="background:{chart[i]}"></i>{n} {p}%</span>'
        for i, (n, p) in enumerate([('餐饮', 30), ('购物', 18), ('交通', 16), ('居住', 14), ('娱乐', 12), ('其他', 10)]))
    return f'''<div class="pv" style="{styles}">
  <p class="pvTitle">{'浅色 light' if light else '深色 dark'} · {'均衡型' if strategy=='balanced' else '色盲强化型'}</p>
  <div class="mHero">
    <div style="display:flex;justify-content:space-between;font-size:11px;opacity:.9"><span>● 节奏正常</span><span>10月</span></div>
    <div style="font-size:11px;opacity:.88;margin-top:10px">本月还可花</div>
    <div class="amt">¥2,860.00</div>
    <div class="bd"><div><span>预算</span><span>¥4,000.00</span></div>
      <div><span>已用</span><span>¥1,140.00</span></div>
      <div><span>日均可花</span><span>¥95.00</span></div></div>
    <div class="pbar"><i></i></div><div class="pbar warn"><i></i></div>
    <div style="font-size:10.5px;opacity:.86;margin-top:6px">分类预算：餐饮 68% · 购物 82%（进度条用琥珀）</div>
  </div>
  <div class="mNet" style="margin-top:12px">
    <div style="font-size:11px;opacity:.88">净资产</div>
    <div style="font-size:24px;font-weight:800;margin-top:2px">¥1,000.00</div>
    <div class="row"><span>总资产<b>¥2,000.00</b></span><span>负债<b class="amber">¥1,000.00</b></span></div>
  </div>
  <div class="mList">
    <div class="mRow"><span class="ic" style="background:color-mix(in srgb,var(--expense) 8%,transparent);color:var(--expense)">🍜</span>餐饮外卖<span class="amt" style="color:var(--expense)">-¥38.50</span></div>
    <div class="mRow"><span class="ic" style="background:color-mix(in srgb,var(--income) 8%,transparent);color:var(--income)">💰</span>工资<span class="amt" style="color:var(--income)">+¥12,000.00</span></div>
    <div class="mRow"><span class="ic" style="background:color-mix(in srgb,var(--transfer) 8%,transparent);color:var(--transfer)">🔁</span>转账到储蓄<span class="amt" style="color:var(--transfer)">¥2,000.00</span></div>
    <div class="mRow"><span class="ic" style="background:color-mix(in srgb,var(--credit) 8%,transparent);color:var(--credit)">💳</span>信用卡还款<span class="amt" style="color:var(--credit)">¥1,200.00</span></div>
  </div>
  <div class="mForm">
    <div class="mSeg"><span class="on">支出</span><span>收入</span><span>转账</span></div>
    <div style="display:flex;gap:8px;flex-wrap:wrap">
      <span class="mChip on">外卖<span class="p">餐饮</span></span>
      <span class="mChip">交通<span class="p">出行</span></span>
      <span class="mChip">购物<span class="p">日用</span></span>
      <span class="mChip solid">保存</span>
    </div>
  </div>
  <div class="mAlert fill">● 警示条（填充态）：预算已用 82%，注意节奏</div>
  <div class="mChart">{bars}</div>
  <div style="display:flex;gap:14px;align-items:center;margin-top:12px">
    <div class="mPie"></div><div class="mLegend">{legend}</div>
  </div>
</div>'''


def main():
    theory = ''.join(
        f'<tr><td><b>{t}</b></td><td>{why}</td><td>{constraint}</td></tr>'
        for t, why, constraint in THEORY)
    comp = ''.join(
        f'<tr><td><b>{t}</b></td><td>{obs}</td><td>{ours}</td></tr>'
        for t, obs, ours in COMPETITORS)
    cards = ''.join(scheme_card(k) for k in ('ink', 'jade', 'plum'))

    # 校验总表
    rows = []
    for key in ('ink', 'jade', 'plum'):
        for mk, checks in CHECKS[key].items():
            cells = ''.join(
                f'<td class="{"ok" if c["ok"] else "no"}">{c["value"]}</td>' for c in checks.values())
            rows.append(f'<tr><td>{NAMES[key]}</td><td>{mk}</td>{cells}</tr>')
    head = ''.join(f'<th>{n}</th>' for n in list(CHECKS['ink']['warm_light'].keys()))
    check_rows = ''.join(rows)

    # 色盲实测表
    ladder = json.load(open('docs/_theme_ladder.json', encoding='utf-8'))
    cvd_rows = ''
    for k, label in [('light_balanced', '浅色 · 均衡型'), ('light_cvd', '浅色 · 色盲强化型'),
                     ('dark_balanced', '深色 · 均衡型'), ('dark_cvd', '深色 · 色盲强化型')]:
        m = ladder[k]
        cvd_rows += (f'<tr><td>{label}</td><td>{m["spread"]:.2f}</td>'
                     + ''.join(f'<td>{m["cvd"][v]["min"]:.3f}<span class="tiny"> {m["cvd"][v]["pair"]}</span></td>'
                               for v in ('normal', 'protan', 'deutan', 'tritan'))
                     + f'<td>{min(m["apca"].values()):.0f}</td></tr>')

    initial = preview('light', 'ink', 'warm', 'cvd') + preview('dark', 'ink', 'warm', 'cvd')
    templates = ''.join(
        f'<template id="tpl-{key}-{neutral}-{mode}-{strat}">'
        f'{preview(mode, key, neutral, strat)}</template>'
        for key in ('ink', 'jade', 'plum')
        for neutral in ('warm', 'cool')
        for mode in ('light', 'dark')
        for strat in ('balanced', 'cvd'))

    filters = ''.join(
        f'<filter id="cvd-{k}" color-interpolation-filters="linearRGB">'
        f'<feColorMatrix type="matrix" values="{v}"/></filter>'
        for k, v in CVD_MATRICES.items())

    html = f'''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>主题色设计 v2 · 理论依据 + 三个体系化方案 · 米记</title>
<style>{CSS}</style></head>
<body>
<svg width="0" height="0" style="position:absolute">{filters}</svg>
<div class="bar"><div class="row">
  <b style="font-size:13px">主题色 v2</b>
  <div class="seg" id="schemeSeg">
    <button data-key="ink" class="on">V1 墨蓝</button>
    <button data-key="jade">V2 青碧</button>
    <button data-key="plum">V3 绛紫</button>
  </div>
  <div class="seg" id="neutralSeg">
    <button data-neutral="warm" class="on">暖白中性</button>
    <button data-neutral="cool">冷灰中性</button>
  </div>
  <div class="seg" id="stratSeg">
    <button data-strat="cvd" class="on">色盲强化语义</button>
    <button data-strat="balanced">均衡语义</button>
  </div>
  <div class="seg" id="cvdSeg">
    <button data-cvd="none" class="on">正常视觉</button>
    <button data-cvd="protan">红色盲</button>
    <button data-cvd="deutan">绿色盲</button>
    <button data-cvd="tritan">蓝黄色盲</button>
  </div>
  <button class="btn" id="exportBtn">导出我的选择</button>
</div></div>

<div class="wrap">
  <h1>主题色设计 v2 · 有依据的体系化配色</h1>
  <p class="sub">上一轮是「修对比度」；这一轮按<b>色彩理论 + 可访问性标准 + 竞品结构</b>重新设计两套主题。
  所有数字都是现场算的：WCAG 对比度、APCA（Lc）、OKLab ΔE、以及 Viénot/Brettel 色觉缺陷模拟。</p>

  <h2><span class="n">1</span>设计依据：理论 → 约束</h2>
  <p class="sub">每条理论都落到一个可检查的约束上，后面所有颜色都是这些约束求解出来的，不是手调的。</p>
  <div class="card"><table><thead><tr><th style="width:250px">理论 / 研究</th><th style="width:380px">说了什么</th><th>落成什么约束</th></tr></thead><tbody>{theory}</tbody></table></div>

  <h2><span class="n">2</span>竞品结构观察</h2>
  <p class="sub">说明：本环境无法联网核查，以下是从公开产品印象里提炼的<b>结构规律</b>（不是色值抄录）。真正落到设计里的是「结构」，色值由求解器算。</p>
  <div class="card"><table><thead><tr><th style="width:230px">规律</th><th style="width:420px">竞品普遍做法</th><th>我们的处理</th></tr></thead><tbody>{comp}</tbody></table></div>

  <h2><span class="n">3</span>现状诊断（实测）</h2>
  <div class="grid3">
    <div class="card"><b>实心按钮白字 <span class="chip bad">不达标</span></b>
      <p class="sub" style="margin:8px 0 0">浅色 3.47:1、深色 <b>2.05:1</b>（`app_icon_action_button.dart:48` 硬编码白字）。深色下几乎读不清。</p></div>
    <div class="card"><b>只靠色相区分收支 <span class="chip bad">不可靠</span></b>
      <p class="sub" style="margin:8px 0 0">实测：把五个语义色调到<b>等明度</b>后，绿色盲下「支出↔收入」的 ΔE 只有 <b>0.015</b>（正常视觉 0.13）—— 色相通道在色盲下会塌。</p></div>
    <div class="card"><b>选中态同色叠同色 <span class="chip bad">不达标</span></b>
      <p class="sub" style="margin:8px 0 0">primary 12% 底 + primary 文字 = 3.03:1。改用 primaryContainer/onPrimaryContainer 配对后 8~13:1。</p></div>
  </div>
  <div class="card" style="margin-top:14px"><table>
    <thead><tr><th>语义色策略</th><th>明度跨度</th><th>正常视觉最小ΔE</th><th>红色盲</th><th>绿色盲</th><th>蓝黄色盲</th><th>APCA 最差 Lc</th></tr></thead>
    <tbody>{cvd_rows}</tbody></table>
    <p class="tiny" style="margin-top:10px">ΔE 判读：≥0.10 是「明显可区分」（约等于 CIELAB ΔE*ab ≥ 10，ColorBrewer 的实用门槛）；≥0.05 是「并排能看出不同」。<br>
    均衡型与色盲强化型的差别就是<b>明度跨度</b>：跨度小 → 五个色视觉权重一致、更鲜亮，但要靠 +/− 和文字冗余；跨度大 → 不依赖颜色也能分辨。</p></div>

  <h2><span class="n">4</span>三个体系化方案</h2>
  <p class="sub">M3 角色用 Google 官方 HCT/色调板生成（<code>tool/theme_gen.dart</code>），语义色与图表色板用 OKLCH 求解器算（<code>docs/theme_solve_ladder.py</code>）。</p>
  <div class="grid3">{cards}</div>

  <h2><span class="n">5</span>校验总表</h2>
  <div class="card"><table><thead><tr><th>方案</th><th>变体</th>{head}</tr></thead><tbody>{check_rows}</tbody></table></div>

  <h2><span class="n">6</span>色觉缺陷模拟 + 实时预览</h2>
  <p class="sub">顶部可切方案 / 暖冷中性 / 语义策略 / 四种视觉。下面的 mockup 全部用候选 token 实时换肤（CSS 变量），色盲模式用 Machado 2009 的线性 RGB 矩阵（feColorMatrix）。<br>
  试着切到「绿色盲」：你会看到收支金额的颜色几乎一样 —— 这就是为什么方案里加了明度冗余。</p>
  <div id="preview" class="pair">{initial}</div>

  <h2><span class="n">7</span>逐项拍板</h2>
  <div class="card"><div class="dec">{''.join(f'<label><input type="checkbox" data-dec="{k}" checked><span><b>{k} · {t}<span class="tag warn">{rec}</span></b><em>{d}</em></span></label>' for k, t, d, rec in DECISIONS)}</div></div>

  <h2><span class="n">8</span>导出</h2>
  <div class="card"><textarea id="out" readonly placeholder="点右上角「导出我的选择」生成…"></textarea>
  <div style="margin-top:10px"><button class="btn" id="copyBtn">复制</button> <span class="tiny" id="copyHint"></span></div></div>
</div>
{templates}
<script>
var DATA = {json.dumps({'palettes': PALETTES, 'names': NAMES}, ensure_ascii=False)};
var state = {{key:'ink', neutral:'warm', strat:'cvd', cvd:'none', mode:'both'}};
try {{ var s = localStorage.getItem('miji-theme-v2'); if (s) state = Object.assign(state, JSON.parse(s)); }} catch(e) {{}}

function seg(id, attr, fn) {{
  document.querySelectorAll('#'+id+' button').forEach(function(b) {{
    b.onclick = function() {{
      document.querySelectorAll('#'+id+' button').forEach(function(x) {{ x.classList.remove('on'); }});
      b.classList.add('on');
      state[attr] = b.getAttribute('data-'+attr); fn(); save();
    }};
  }});
}}
function save() {{ try {{ localStorage.setItem('miji-theme-v2', JSON.stringify(state)); }} catch(e) {{}} }}

function render() {{
  ['schemeSeg:key','neutralSeg:neutral','stratSeg:strat','cvdSeg:cvd'].forEach(function(p) {{
    var parts = p.split(':');
    document.querySelectorAll('#'+parts[0]+' button').forEach(function(b) {{
      b.classList.toggle('on', b.getAttribute('data-'+parts[1]) === state[parts[1]]);
    }});
  }});
  var box = document.getElementById('preview');
  box.innerHTML = '';
  ['light','dark'].forEach(function(mode) {{
    var tpl = document.getElementById('tpl-'+state.key+'-'+state.neutral+'-'+mode+'-'+state.strat);
    var el = tpl.content.firstElementChild.cloneNode(true);
    if (state.cvd !== 'none') el.style.filter = 'url(#cvd-'+state.cvd+')';
    box.appendChild(el);
  }});
  save();
}}

document.getElementById('exportBtn').onclick = function() {{
  var p = DATA.palettes[state.key], v = p.variants[state.neutral+'_light'];
  var vd = p.variants[state.neutral+'_dark'];
  var decs = [];
  document.querySelectorAll('[data-dec]').forEach(function(c) {{
    decs.push(c.getAttribute('data-dec') + '=' + (c.checked ? '采纳' : '不采纳'));
  }});
  var lines = [];
  lines.push('【方案】' + DATA.names[state.key] + ' · 中性=' + state.neutral +
             ' · 语义策略=' + state.strat);
  lines.push('【决策】' + decs.join('  '));
  lines.push('');
  ['light','dark'].forEach(function(mode) {{
    var vv = p.variants[state.neutral+'_'+mode], r = vv.roles;
    var sem = state.strat === 'cvd' ? vv.semantic_cvd : vv.semantic_balanced;
    lines.push('--- ' + (mode === 'light' ? '浅色 light' : '深色 dark') + ' ---');
    lines.push('primary ' + r.primary + '  onPrimary ' + r.onPrimary +
               '  container ' + r.primaryContainer + ' / ' + r.onPrimaryContainer);
    lines.push('secondary ' + r.secondary + '  tertiary ' + r.tertiary);
    lines.push('surface ' + r.surface + '  containerLow ' + r.surfaceContainerLow +
               '  outline ' + r.outline);
    lines.push('semantic ' + Object.keys(sem).map(function(k) {{ return k + ' ' + sem[k]; }}).join('  '));
    lines.push('chart ' + vv.chart.join(' '));
    lines.push('hero.brand ' + vv.hero.brand.join(' → '));
    lines.push('hero.netWorth ' + vv.hero.netWorth.join(' → '));
    lines.push('hero.danger ' + vv.hero.danger.join(' → '));
    lines.push('');
  }});
  document.getElementById('out').value = lines.join('\\n');
}};
document.getElementById('copyBtn').onclick = function() {{
  var el = document.getElementById('out'); el.select();
  try {{ document.execCommand('copy'); document.getElementById('copyHint').textContent = '已复制'; }} catch(e) {{}}
}};
document.querySelectorAll('[data-dec]').forEach(function(c) {{ c.onchange = save; }});
seg('schemeSeg','key',render); seg('neutralSeg','neutral',render);
seg('stratSeg','strat',render); seg('cvdSeg','cvd',render);
render();
</script>
</body></html>
'''
    open('docs/theme-redesign-v2-preview.html', 'w', encoding='utf-8').write(html)
    print('written docs/theme-redesign-v2-preview.html', len(html))


if __name__ == '__main__':
    main()
