import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/features/home/bloc/home_bloc.dart';
import 'package:miji/features/home/bloc/home_event.dart';
import 'package:miji/l10n/l10n.dart';
import 'package:miji/shared/widgets/clock/index.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _isSearchVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient:
            !isDarkMode
                ? LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.lightBackgroundColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                : null,
        color: isDarkMode ? AppColors.darkBackgroundColor : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _isSearchVisible
              ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color:
                            isDarkMode
                                ? AppColors.darkTextColor
                                : AppColors.lightTextColor,
                      ),
                      decoration: AppColors.inputDecoration.copyWith(
                        hintText: l10n.todoHint,
                        prefixIcon: const Icon(Icons.add_task),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        context.read<HomeBloc>().add(AddTodo(_controller.text));
                        _controller.clear();
                        setState(() => _isSearchVisible = false);
                      }
                    },
                    child: Text(l10n.addTodo),
                  ),
                ],
              )
              : Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color:
                          isDarkMode
                              ? AppColors.darkTextColor
                              : AppColors.primaryColor,
                    ),
                    onPressed: () {
                      setState(() => _isSearchVisible = true);
                      FocusScope.of(context).requestFocus(_focusNode);
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: CustomClock(
                        format: 'yyyy年MM月dd日 HH时mm分ss秒',
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        borderRadius: 20,
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}