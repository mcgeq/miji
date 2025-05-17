import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:miji/shared/widgets/clock/clock_bloc.dart';

class CustomClock extends StatelessWidget {
  final String format;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const CustomClock({
    super.key,
    this.format = 'yyyy年MM月dd日 HH:mm:ss',
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 16,
  });

  /// 根据时间段返回图标
  IconData _getIcon(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) {
      return Icons.wb_sunny; // Morning
    } else if (hour >= 11 && hour < 17) {
      return Icons.wb_cloudy; // Day
    } else if (hour >= 17 && hour < 20) {
      return Icons.wb_twilight; // Dusk
    } else {
      return Icons.nightlight_round; // Night
    }
  }

  /// 根据时间设置渐变背景
  List<Color> _getGradient(DateTime time, bool isDark) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) {
      return isDark
          ? [Colors.orange.shade800, Colors.deepOrange.shade400]
          : [Colors.orangeAccent.shade100, Colors.orange.shade300];
    } else if (hour >= 11 && hour < 17) {
      return isDark
          ? [Colors.blueGrey.shade700, Colors.teal.shade400]
          : [Colors.lightBlueAccent, Colors.blue.shade300];
    } else if (hour >= 17 && hour < 20) {
      return isDark
          ? [Colors.deepPurple.shade700, Colors.deepPurpleAccent]
          : [Colors.purpleAccent, Colors.deepPurple.shade300];
    } else {
      return isDark
          ? [Colors.grey.shade800, Colors.black]
          : [Colors.blueGrey.shade100, Colors.blueGrey.shade300];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ClockBloc, ClockState>(
      builder: (context, state) {
        final time = state.dateTime;
        final formattedTime = DateFormat(format).format(time);
        final gradient = _getGradient(time, isDark);
        final icon = _getIcon(time);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                formattedTime,
                style:
                    textStyle ??
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
