import 'package:flutter/material.dart';

import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

const visibleMoneyAccountTypes = <MoneyAccountType>[
  MoneyAccountType.cash,
  MoneyAccountType.bank,
  MoneyAccountType.creditCard,
  MoneyAccountType.huabei,
  MoneyAccountType.baitiao,
  MoneyAccountType.meituanCredit,
  MoneyAccountType.otherCredit,
  MoneyAccountType.saving,
  MoneyAccountType.investment,
  MoneyAccountType.alipay,
  MoneyAccountType.wechat,
  MoneyAccountType.cloudQuickPass,
  MoneyAccountType.prepaidCard,
  MoneyAccountType.other,
];

String defaultAccountColorForType(MoneyAccountType type) {
  return switch (type) {
    MoneyAccountType.cash => '#F97316',
    MoneyAccountType.bank => '#0EA5E9',
    MoneyAccountType.creditCard => '#EC4899',
    MoneyAccountType.huabei => '#1677FF',
    MoneyAccountType.baitiao => '#DC2626',
    MoneyAccountType.meituanCredit => '#FACC15',
    MoneyAccountType.otherCredit => '#A855F7',
    MoneyAccountType.saving => '#22C55E',
    MoneyAccountType.investment => '#8B5CF6',
    MoneyAccountType.loan => '#EF4444',
    MoneyAccountType.alipay => '#1677FF',
    MoneyAccountType.wechat => '#07C160',
    MoneyAccountType.cloudQuickPass => '#E11D48',
    MoneyAccountType.prepaidCard => '#14B8A6',
    MoneyAccountType.other => '#64748B',
    MoneyAccountType.internal => '#94A3B8',
  };
}

String defaultAccountIconForType(MoneyAccountType type) {
  return switch (type) {
    MoneyAccountType.cash => 'payments',
    MoneyAccountType.bank => 'account_balance',
    MoneyAccountType.creditCard => 'credit_card',
    MoneyAccountType.huabei => 'credit_card',
    MoneyAccountType.baitiao => 'credit_card',
    MoneyAccountType.meituanCredit => 'credit_score',
    MoneyAccountType.otherCredit => 'credit_score',
    MoneyAccountType.saving => 'savings',
    MoneyAccountType.investment => 'show_chart',
    MoneyAccountType.loan => 'request_quote',
    MoneyAccountType.alipay => 'account_balance_wallet',
    MoneyAccountType.wechat => 'chat',
    MoneyAccountType.cloudQuickPass => 'tap_and_play',
    MoneyAccountType.prepaidCard => 'card_giftcard',
    MoneyAccountType.other => 'more_horiz',
    MoneyAccountType.internal => 'account_balance_wallet',
  };
}

IconData accountIconDataForType(MoneyAccountType type) {
  return switch (type) {
    MoneyAccountType.cash => Icons.payments_rounded,
    MoneyAccountType.bank => Icons.account_balance_rounded,
    MoneyAccountType.creditCard => Icons.credit_card_rounded,
    MoneyAccountType.huabei => Icons.credit_card_rounded,
    MoneyAccountType.baitiao => Icons.credit_card_rounded,
    MoneyAccountType.meituanCredit => Icons.credit_score_rounded,
    MoneyAccountType.otherCredit => Icons.credit_score_rounded,
    MoneyAccountType.saving => Icons.savings_rounded,
    MoneyAccountType.investment => Icons.show_chart_rounded,
    MoneyAccountType.loan => Icons.request_quote_rounded,
    MoneyAccountType.alipay => Icons.account_balance_wallet_rounded,
    MoneyAccountType.wechat => Icons.chat_bubble_outline_rounded,
    MoneyAccountType.cloudQuickPass => Icons.tap_and_play_rounded,
    MoneyAccountType.prepaidCard => Icons.card_giftcard_rounded,
    MoneyAccountType.other => Icons.more_horiz_rounded,
    MoneyAccountType.internal => Icons.account_balance_wallet_rounded,
  };
}
