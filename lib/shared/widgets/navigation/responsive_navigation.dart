import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/app/routes/pages/home_page.dart';
import 'package:miji/app/routes/pages/profile_page.dart';
import 'package:miji/app/routes/pages/settings_page.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/l10n/l10n.dart';

class ResponsiveNavigation extends StatefulWidget {
  final int selectedIndex;
  final List<Widget> pages;

  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.pages,
  });

  @override
  State<ResponsiveNavigation> createState() => _ResponsiveNavigationState();
}

class _ResponsiveNavigationState extends State<ResponsiveNavigation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drawerAnimation;
  late Animation<double> _overlayOpacity;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _drawerAnimation = Tween<double>(
      begin: -200,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _overlayOpacity = Tween<double>(
      begin: 0.0,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex == index) return; // 避免重复导航
    setState(() {
      _currentIndex = index;
    });
    // 使用路由导航
    final routes = [
      HomePage.routeName,
      ProfilePage.routeName,
      SettingsPage.routeName,
    ];
    debugPrint('Navigating to: ${routes[index]}');
    context.go(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
        return isDesktop
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => widget.pages[_currentIndex],
            );
          },
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_controller.value == 0) {
              return const SizedBox.shrink();
            }
            return Opacity(
              opacity: _overlayOpacity.value,
              child: Semantics(
                label: l10n.menu,
                button: true,
                onTap: () => _controller.reverse(),
                child: GestureDetector(
                  onTap: () => _controller.reverse(),
                  child: Container(
                    color: Colors.black,
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_drawerAnimation.value, 0),
              child: SizedBox(
                width: 200, // Increased width for better spacing
                child: Drawer(
                  elevation: 12,
                  backgroundColor: theme.brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drawer Header
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryColor,
                              AppColors.primaryColor.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Miji',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Navigation Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildNavItem(
                              context: context,
                              icon: Icons.home,
                              label: l10n.home,
                              index: 0,
                            ),
                            _buildNavItem(
                              context: context,
                              icon: Icons.person,
                              label: l10n.profile,
                              index: 1,
                            ),
                            _buildNavItem(
                              context: context,
                              icon: Icons.settings,
                              label: l10n.settings,
                              index: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Semantics(
            label: l10n.menu,
            button: true,
            child: FloatingActionButton(
              backgroundColor: AppColors.primaryColor,
              onPressed: () {
                if (_controller.isCompleted) {
                  _controller.reverse();
                } else {
                  _controller.forward();
                }
              },
              child: const Icon(Icons.menu),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            size: 28,
            color: isSelected
                ? AppColors.primaryColor
                : (theme.brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkTextColor
                  : AppColors.textColor,
            ),
          ),
          selected: isSelected,
          onTap: () {
            _onDestinationSelected(index);
            _controller.reverse();
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          hoverColor: AppColors.primaryColor.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => widget.pages[widget.selectedIndex],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.selectedIndex,
        onTap: _onDestinationSelected,
        selectedItemColor: AppColors.primaryColor,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: AppLocalizations.of(context)!.profile,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
      ),
    );
  }
}