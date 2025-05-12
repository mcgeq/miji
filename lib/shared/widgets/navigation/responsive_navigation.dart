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
      begin: -120,
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
            return Opacity(
              opacity: _overlayOpacity.value, // 使用透明度动画
              child: Semantics(
                label: AppLocalizations.of(context)!.menu,
                button: true,
                onTap: () => _controller.reverse(),
                child: GestureDetector(
                  onTap: () => _controller.reverse(),
                  child: Container(
                    color: Colors.black, // 颜色直接使用 black，透明度由 Opacity 控制
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
                width: 120,
                child: Drawer(
                  elevation: 8,
                  backgroundColor: Colors.white,
                  child: ListView(
                    children: [
                      Semantics(
                        label: AppLocalizations.of(context)!.home,
                        selected: _currentIndex == 0,
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.home),
                          title: Text(AppLocalizations.of(context)!.home),
                          selected: _currentIndex == 0,
                          onTap: () {
                            _onDestinationSelected(0);
                            _controller.reverse();
                          },
                        ),
                      ),
                      Semantics(
                        label: AppLocalizations.of(context)!.profile,
                        selected: _currentIndex == 1,
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(AppLocalizations.of(context)!.profile),
                          selected: _currentIndex == 1,
                          onTap: () {
                            _onDestinationSelected(1);
                            _controller.reverse();
                          },
                        ),
                      ),
                      Semantics(
                        label: AppLocalizations.of(context)!.settings,
                        selected: _currentIndex == 2,
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.settings),
                          title: Text(AppLocalizations.of(context)!.settings),
                          selected: _currentIndex == 2,
                          onTap: () {
                            _onDestinationSelected(2);
                            _controller.reverse();
                          },
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
            label: AppLocalizations.of(context)!.menu,
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
