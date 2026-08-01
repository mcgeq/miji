import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_initial_avatar.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/user/providers/user_providers.dart';
import 'package:miji/features/bookkeeping/presentation/ledgers/ledger_selector.dart';
import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_fab.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/shared/widgets/date_picker.dart';

const _mobileBottomBarHeight = 64.0;
const _mobileFabDockOffset = 14.0;

class AppShellPage extends ConsumerWidget {
  const AppShellPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedNavigationIndex(path);
    final mobileSelectedIndex = _selectedMobileNavigationIndex(path);

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AppResponsive.of(
          context,
          width: constraints.maxWidth,
        );
        final useRail = responsive.prefersRailNavigation;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: useRail
                ? Row(
                    children: [
                      _AppNavigationRail(selectedIndex: selectedIndex),
                      Expanded(child: child),
                    ],
                  )
                : Column(
                    children: [
                      _MobileShellTopBar(path: path),
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.62),
                      ),
                      Expanded(child: child),
                    ],
                  ),
          ),
          bottomNavigationBar: useRail
              ? null
              : _MobileShellBottomBar(
                  selectedIndex: mobileSelectedIndex,
                  onDestinationSelected: (index) {
                    context.go(_mobileNavigationItems[index].path);
                  },
                ),
          floatingActionButton: MoneyQuickActionFab(
            placement: useRail
                ? MoneyQuickActionFabPlacement.bottomRight
                : MoneyQuickActionFabPlacement.centerDocked,
          ),
          floatingActionButtonLocation: useRail
              ? FloatingActionButtonLocation.endFloat
              : const _MobileCenterDockedFabLocation(),
        );
      },
    );
  }
}

class _MobileShellTopBar extends ConsumerWidget {
  const _MobileShellTopBar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final colorScheme = Theme.of(context).colorScheme;
    final showHomeMonthSelector = _isHomePath(path);
    final showLedgerSelector = _isMoneyPath(path);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 14),
          const _AppMark(compact: true),
          if (showLedgerSelector) const SizedBox(width: 12),
          if (!showLedgerSelector) const Spacer(),
          if (showHomeMonthSelector) ...[
            const _MobileHomeMonthSelector(),
            const SizedBox(width: 6),
            const _MobileHomeTodayButton(),
            const SizedBox(width: 6),
          ],
          if (showLedgerSelector) ...[
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: showHomeMonthSelector ? 196 : 220,
                  ),
                  child: CurrentLedgerSelector.compact(),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _CurrentUserAvatarButton(colorScheme: colorScheme),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  bool _isHomePath(String path) {
    return path == AppRoutes.home || path.startsWith('${AppRoutes.home}/');
  }

  bool _isMoneyPath(String path) {
    return _isHomePath(path) ||
        path == AppRoutes.bookkeeping ||
        path.startsWith('${AppRoutes.bookkeeping}/');
  }
}

class _MobileHomeMonthSelector extends ConsumerWidget {
  const _MobileHomeMonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(homeMoneySelectedMonthProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: '选择月份',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            unawaited(_pickMonth(context, ref, selectedMonth));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _homeMonthLabel(selectedMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedMonth,
  ) async {
    final picked = await showAppMonthPicker(
      context: context,
      initialMonth: selectedMonth,
      firstMonth: DateTime(2000),
      lastMonth: DateTime(2100, 12),
    );
    if (picked == null) {
      return;
    }
    ref.read(homeMoneySelectedMonthProvider.notifier).set(picked);
  }

  String _homeMonthLabel(DateTime month) {
    return '${month.year}.${month.month}';
  }
}

class _MobileHomeTodayButton extends ConsumerWidget {
  const _MobileHomeTodayButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedMonth = ref.watch(homeMoneySelectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Tooltip(
      message: '回到本月',
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          fixedSize: const Size(28, 28),
          minimumSize: const Size(28, 28),
          padding: EdgeInsets.zero,
        ),
        onPressed: isCurrentMonth
            ? null
            : () {
                ref.read(homeMoneySelectedMonthProvider.notifier).set(now);
              },
        icon: Text(
          '今',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isCurrentMonth
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.42)
                : colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _CurrentUserAvatarButton extends ConsumerWidget {
  const _CurrentUserAvatarButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (user) => user, orElse: () => null);
    final label = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : user?.username.trim() ?? '用户';
    final initial = label.isEmpty
        ? '米'
        : String.fromCharCode(label.runes.first).toUpperCase();
    return Tooltip(
      message: '设置',
      child: Material(
        color: colorScheme.primaryContainer,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.settings),
          child: AppInitialAvatar(
            initial: initial,
            size: 32,
            color: colorScheme.primary,
            avatarUri: user?.avatarUri,
          ),
        ),
      ),
    );
  }
}

class _AppNavigationRail extends ConsumerWidget {
  const _AppNavigationRail({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const _AppMark(compact: true),
              const SizedBox(height: 14),
              for (var index = 0; index < _navigationItems.length; index++) ...[
                _DesktopNavigationButton(
                  item: _navigationItems[index],
                  selected: selectedIndex == index,
                  onTap: () => context.go(_navigationItems[index].path),
                ),
                if (index != _navigationItems.length - 1)
                  const SizedBox(height: 6),
              ],
              const Spacer(),
              _RailActionButton(
                tooltip: '锁定',
                icon: Icons.lock_outline_rounded,
                onPressed: () {
                  ref.read(authSessionControllerProvider.notifier).lock();
                },
              ),
              const SizedBox(height: 7),
              _RailActionButton(
                tooltip: '退出',
                icon: Icons.logout_rounded,
                onPressed: () {
                  ref.read(authSessionControllerProvider.notifier).clear();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavigationButton extends StatelessWidget {
  const _DesktopNavigationButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 50,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailActionButton extends StatelessWidget {
  const _RailActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 19, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _MobileShellBottomBar extends StatelessWidget {
  const _MobileShellBottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int? selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.94),
          elevation: 6,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: BottomAppBar(
            color: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: const CircularNotchedRectangle(),
            notchMargin: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.34),
                ),
              ),
              child: SizedBox(
                height: _mobileBottomBarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MobileNavButton(
                          item: _mobileNavigationItems[0],
                          selected: selectedIndex == 0,
                          onTap: () => onDestinationSelected(0),
                        ),
                      ),
                      Expanded(
                        child: _MobileNavButton(
                          item: _mobileNavigationItems[1],
                          selected: selectedIndex == 1,
                          onTap: () => onDestinationSelected(1),
                        ),
                      ),
                      const SizedBox(width: 74),
                      Expanded(
                        child: _MobileNavButton(
                          item: _mobileNavigationItems[2],
                          selected: selectedIndex == 2,
                          onTap: () => onDestinationSelected(2),
                        ),
                      ),
                      Expanded(
                        child: _MobileNavButton(
                          item: _mobileNavigationItems[3],
                          selected: selectedIndex == 3,
                          onTap: () => onDestinationSelected(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileCenterDockedFabLocation extends FloatingActionButtonLocation {
  const _MobileCenterDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final navTop =
        scaffoldGeometry.scaffoldSize.height -
        _mobileBottomBarHeight -
        scaffoldGeometry.minViewPadding.bottom;
    final fabX = (scaffoldGeometry.scaffoldSize.width - fabSize.width) / 2;
    final fabY = navTop - (fabSize.height / 2) + _mobileFabDockOffset;
    return Offset(fabX, fabY);
  }
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Tooltip(
        message: item.label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.78)
                    : Colors.transparent,
                border: selected
                    ? Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.2,
                        ),
                      )
                    : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
                size: 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final logo = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '米',
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );

    if (compact) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Text(
          'Miji',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const _navigationItems = [
  _NavigationItem(
    label: '打卡',
    path: AppRoutes.gtd,
    icon: Icons.checklist_rounded,
    selectedIcon: Icons.task_alt_rounded,
  ),
  _NavigationItem(
    label: '记账',
    path: AppRoutes.bookkeeping,
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
  ),
  _NavigationItem(
    label: '首页',
    path: AppRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _NavigationItem(
    label: '健康',
    path: AppRoutes.health,
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
  ),
  _NavigationItem(
    label: '设置',
    path: AppRoutes.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];

const _mobileNavigationItems = [
  _NavigationItem(
    label: '打卡',
    path: AppRoutes.gtd,
    icon: Icons.checklist_rounded,
    selectedIcon: Icons.task_alt_rounded,
  ),
  _NavigationItem(
    label: '记账',
    path: AppRoutes.bookkeeping,
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
  ),
  _NavigationItem(
    label: '首页',
    path: AppRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _NavigationItem(
    label: '健康',
    path: AppRoutes.health,
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
  ),
];

int _selectedNavigationIndex(String path) {
  final index = _navigationItems.indexWhere(
    (item) => path == item.path || path.startsWith('${item.path}/'),
  );

  return index == -1 ? 2 : index;
}

int? _selectedMobileNavigationIndex(String path) {
  final index = _mobileNavigationItems.indexWhere(
    (item) => path == item.path || path.startsWith('${item.path}/'),
  );

  return index == -1 ? null : index;
}
