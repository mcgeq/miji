import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_palette.dart';
import 'package:miji/core/theme/app_palette_providers.dart';

/// 单张配色卡的 key，测试按 id 定位，不用怕同名文案重复命中。
Key paletteTileKey(String paletteId) => ValueKey('palette-tile-$paletteId');

/// 配色选择：九套方案，点一下当场换。
///
/// 为什么是「九个小卡」而不是下拉框：配色是**看**出来的，不是读出来的。
/// 每张卡自带三色预览（品牌实心 / 页面底 / 支出红），选之前就知道长什么样；
/// 下拉框只能给名字，用户得靠想象力。
///
/// 卡片用的是「当前明暗档」的色值（深色模式下预览就是深色），
/// 所以选配色时看到的就是切过去以后的样子，不会选完被深色打回原形。
class AppPalettePicker extends ConsumerWidget {
  const AppPalettePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(themePaletteIdProvider);
    final selected = AppPalettes.byId(selectedId);
    final brightness = theme.brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.palette_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '配色',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              selected.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // 窄屏 3 列、宽屏 4 列：每格至少 96px 才放得下两字名字 + 三色预览。
            // 再窄（像被塞进对话框或超窄窗）退到 2 列，否则预览点画不下。
            const gap = 8.0;
            final columns = constraints.maxWidth >= 460
                ? 4
                : (constraints.maxWidth >= 300 ? 3 : 2);
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final palette in AppPalettes.all)
                  SizedBox(
                    // 卡片要有稳定 key：头部右侧也渲染了当前配色名，
                    // 靠 find.text 定位会同时命中标题和卡片（同名两次）。
                    key: paletteTileKey(palette.id),
                    width: width,
                    child: _PaletteTile(
                      palette: palette,
                      mode: palette.of(brightness),
                      selected: palette.id == selected.id,
                      onTap: () => ref
                          .read(themePaletteIdProvider.notifier)
                          .select(palette.id),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          selected.tagline,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final AppPaletteMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = mode.surfaceColors;

    return Semantics(
      button: true,
      selected: selected,
      label: '配色 ${palette.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: surfaces.background,
            borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : surfaces.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 三色点是定宽内容（约 39px），容器被压到极限时等比缩小，
              // 而不是让 Row 溢出画黄黑条。勾放在名字行（那边的文本能 eat 挤压）。
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PaletteSwatch(
                      color: mode.brandColors.primarySolid,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    _PaletteSwatch(color: mode.money.income, size: 9),
                    const SizedBox(width: 4),
                    _PaletteSwatch(color: mode.money.expense, size: 9),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      palette.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: mode.textColors.primary,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: mode.brandColors.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // 浅色块压在浅底上会看不见边界，描一层极淡的圈把它钉住。
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
    );
  }
}
