import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/l10n/l10n.dart';
import 'package:miji/l10n/locale_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Fade animation for cards
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Scale animation for cards
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Slide animation for ListTile
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Start the animation when the page loads
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Dynamic highlight color based on theme
    final highlightColor = theme.brightness == Brightness.dark
        ? AppColors.primaryColor.withValues(alpha:0.1)
        : Colors.grey[200]!.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.darkBackgroundColor
          : AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0,
            vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme Settings Card with Ripple Effect
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Material(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        splashColor: AppColors.primaryColor.withValues(
                        alpha: 0.3),
                        highlightColor: highlightColor,
                        onTap: () {}, // Empty onTap to allow ripple effect
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _AnimatedListTile(
                              leading: Icon(
                                Icons.brightness_4,
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.darkTextColor.withValues(
                                    alpha: 0.7)
                                    : Colors.black54,
                              ),
                              title: Text(
                                l10n.toggleTheme,
                                style: AppColors.bodyText.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: theme.brightness == Brightness.dark
                                      ? AppColors.darkTextColor
                                      : AppColors.textColor,
                                ),
                              ),
                              trailing: Switch(
                                value: theme.brightness == Brightness.dark,
                                onChanged: (value) {
                                  context.read<ThemeBloc>().add(ToggleTheme());
                                },
                                activeColor: AppColors.primaryColor,
                                inactiveThumbColor: Colors.grey,
                              ),
                              onTap: () {
                                context.read<ThemeBloc>().add(ToggleTheme());
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Language Settings Card with Ripple Effect
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Material(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        splashColor: AppColors.primaryColor.withValues(
                        alpha: 0.3),
                        highlightColor: highlightColor,
                        onTap: () {}, // Empty onTap to allow ripple effect
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: BlocBuilder<LocaleBloc, LocaleState>(
                            builder: (context, state) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.grey[900]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Locale>(
                                    isExpanded: true,
                                    value: state.locale,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.primaryColor,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: Locale('en', ''),
                                        child: _AnimatedDropdownItem(
                                          text: 'English',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: Locale('zh', ''),
                                        child: _AnimatedDropdownItem(
                                          text: '简体中文',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: Locale('es', ''),
                                        child: _AnimatedDropdownItem(
                                          text: 'Español',
                                        ),
                                      ),
                                    ],
                                    onChanged: (locale) {
                                      if (locale != null) {
                                        context
                                            .read<LocaleBloc>()
                                            .add(ChangeLocale(locale));
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Animated ListTile with Scale on Tap
class _AnimatedListTile extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget trailing;
  final VoidCallback onTap;

  const _AnimatedListTile({
    required this.leading,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  @override
  _AnimatedListTileState createState() => _AnimatedListTileState();
}

class _AnimatedListTileState extends State<_AnimatedListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) => _tapController.reverse(),
      onTapCancel: () => _tapController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: widget.leading,
            title: widget.title,
            trailing: widget.trailing,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Dropdown Item with Fade and Slide
class _AnimatedDropdownItem extends StatelessWidget {
  final String text;

  const _AnimatedDropdownItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0), // Slide from right
            child: child,
          ),
        );
      },
      child: Text(
        text,
        style: AppColors.bodyText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextColor
              : AppColors.textColor,
        ),
      ),
    );
  }
}