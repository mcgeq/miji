import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/l10n/l10n.dart';

class ResponsiveNavigation extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final List<Widget> pages;

  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.pages,
  });

  @override
  State<ResponsiveNavigation> createState() => _ResponsiveNavigationState();
}

class _ResponsiveNavigationState extends State<ResponsiveNavigation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drawerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _drawerAnimation = Tween<double>(
      begin: -250,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        // 主界面全屏显示
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.pages[widget.selectedIndex],
        ),
        // 遮罩层：侧边栏打开时显示，点击关闭侧边栏
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return _controller.isCompleted
                ? Semantics(
                  label: AppLocalizations.of(context)!.menu,
                  button: true,
                  onTap: () => _controller.reverse(),
                  child: GestureDetector(
                    onTap: () => _controller.reverse(),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                )
                : const SizedBox.shrink();
          },
        ),
        // 侧边栏：浮动显示，带滑入滑出动画
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_drawerAnimation.value, 0),
              child: SizedBox(
                width: 250,
                child: Drawer(
                  elevation: 8,
                  backgroundColor: Colors.white,
                  child: ListView(
                    children: [
                      DrawerHeader(
                        decoration: const BoxDecoration(
                          color: AppColors.primaryColor,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.menu,
                          style: AppColors.headerText.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Semantics(
                        label: AppLocalizations.of(context)!.home,
                        selected: widget.selectedIndex == 0,
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.home),
                          title: Text(AppLocalizations.of(context)!.home),
                          selected: widget.selectedIndex == 0,
                          onTap: () {
                            widget.onDestinationSelected(0);
                            _controller.reverse();
                          },
                        ),
                      ),
                      Semantics(
                        label: AppLocalizations.of(context)!.profile,
                        selected: widget.selectedIndex == 1,
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(AppLocalizations.of(context)!.profile),
                          selected: widget.selectedIndex == 1,
                          onTap: () {
                            widget.onDestinationSelected(1);
                            _controller.reverse();
                          },
                        ),
                      ),
                      Semantics(
                        label: AppLocalizations.of(context)!.settings,
                        selected: widget.selectedIndex == 2,
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.settings),
                          title: Text(AppLocalizations.of(context)!.settings),
                          selected: widget.selectedIndex == 2,
                          onTap: () {
                            widget.onDestinationSelected(2);
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
        // 打开/关闭侧边栏的按钮
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: widget.pages[widget.selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.selectedIndex,
        onTap: widget.onDestinationSelected,
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