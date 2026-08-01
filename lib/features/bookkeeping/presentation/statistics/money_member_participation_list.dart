import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_legend_item.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyMemberParticipationList extends StatelessWidget {
  const MoneyMemberParticipationList({
    super.key,
    required this.slices,
    required this.currencyCode,
  });

  final List<MoneyStatisticsMemberSlice> slices;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const AppEmptyState(title: '暂无成员参与数据');
    }

    return Column(
      children: [
        for (var index = 0; index < slices.length; index += 1)
          _MemberRow(
            rank: index + 1,
            slice: slices[index],
            currencyCode: currencyCode,
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.rank,
    required this.slice,
    required this.currencyCode,
  });

  final int rank;
  final MoneyStatisticsMemberSlice slice;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roleLabel = _roleLabel(slice.role);
    final netMinor = slice.netAmountMinor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AppLegendItem(
        color: colorScheme.primary,
        label: '$rank. ${slice.memberName} · $roleLabel',
        subtitle:
            '已付 ${slice.paidRecordCount} 笔 · 参与 ${slice.participationCount} 笔',
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoneyMinor(slice.paidAmountMinor, currencyCode),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '净额 ${formatMoneyMinor(netMinor, currencyCode)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: netMinor >= 0 ? colorScheme.primary : colorScheme.error,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role.trim().toLowerCase()) {
      'owner' => '拥有者',
      'admin' || 'manager' => '管理员',
      'participant' || 'member' || 'viewer' => '成员',
      _ => role,
    };
  }
}
