import 'dart:math';

import 'package:flutter/material.dart';

class HomeDashboardGreeting extends StatefulWidget {
  const HomeDashboardGreeting({super.key, this.userDisplayName});

  final String? userDisplayName;

  @override
  State<HomeDashboardGreeting> createState() => _HomeDashboardGreetingState();
}

class _HomeDashboardGreetingState extends State<HomeDashboardGreeting> {
  late final int _tipIndex;

  static const _tips = [
    '时间就是金钱。',
    '你不理财，财不理你。',
    '由俭入奢易，由奢入俭难。',
    '不要把所有的鸡蛋放在同一个篮子里。',
    '省一分钱就是赚一分钱。',
    '一寸光阴一寸金，寸金难买寸光阴。',
    '不要为钱工作，让钱为你工作。',
    '积少成多，聚沙成塔。',
    '钱是个好仆人，却是个坏主人。',
    '早知三日事，富贵一千年。',
    '致富的秘诀：支出少于收入。',
    '理财就是理生活。',
    '财富是智慧的产物。',
    '区分需要和想要，减少冲动消费。',
    '机会成本才是真正的成本。',
    '记录每一笔收支，才能更好地规划未来。',
    '急用钱储备建议覆盖 3-6 个月开支。',
    '定期回顾账单，发现消费盲区。',
  ];

  static const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

  @override
  void initState() {
    super.initState();
    _tipIndex = Random().nextInt(_tips.length);
  }

  String _greeting(int hour) {
    if (hour >= 5 && hour < 12) return '早上好';
    if (hour >= 12 && hour < 18) return '下午好';
    return '晚上好';
  }

  String _dateString(DateTime now) {
    return '${now.year}年${now.month}月${now.day}日 ${_weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = _dateString(now);
    final greeting = _greeting(now.hour);
    final tip = _tips[_tipIndex];

    final name = widget.userDisplayName;
    final greetingText = name != null && name.trim().isNotEmpty
        ? '$greeting，$name'
        : greeting;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                dateStr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                greetingText,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              tip,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
