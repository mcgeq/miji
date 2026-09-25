import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

/// 生成流水 CSV 文本（含 UTF-8 BOM，便于表格软件正确识别中文）。
///
/// 字段顺序固定，便于用户二次处理；账户 / 分类 / 子分类传入名称映射，
/// 缺失时回退到原始 id。
String buildTransactionsCsv({
  required List<MoneyTransactionEntity> transactions,
  Map<String, String> accountNames = const <String, String>{},
  Map<String, String> categoryNames = const <String, String>{},
  Map<String, String> subCategoryNames = const <String, String>{},
}) {
  final buffer = StringBuffer();
  buffer.write('\uFEFF');
  buffer.writeln(
    <String>[
      '时间',
      '类型',
      '金额',
      '币种',
      '账户',
      '分类',
      '子分类',
      '支付方式',
      '商家',
      '地点',
      '备注',
      '标签',
      '退款金额',
      '状态',
    ].join(','),
  );
  for (final transaction in transactions) {
    final subCategoryId = transaction.subCategoryId;
    buffer.writeln(
      <String>[
        _dateText(transaction.transactionAt),
        transaction.type.label,
        _amountText(transaction.amountMinor),
        transaction.currencyCode,
        accountNames[transaction.accountId] ?? transaction.accountId,
        categoryNames[transaction.categoryId] ?? transaction.categoryId,
        subCategoryId == null
            ? ''
            : (subCategoryNames[subCategoryId] ?? subCategoryId),
        transaction.customPaymentMethodName ?? transaction.paymentMethod.label,
        transaction.merchant ?? '',
        transaction.location ?? '',
        transaction.notes ?? '',
        transaction.tags.join('、'),
        _amountText(transaction.refundAmountMinor),
        _statusLabel(transaction.status),
      ].map(_escapeCsv).join(','),
    );
  }
  return buffer.toString();
}

String _amountText(int amountMinor) => (amountMinor / 100).toStringAsFixed(2);

String _dateText(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _statusLabel(MoneyTransactionStatus status) {
  return switch (status) {
    MoneyTransactionStatus.completed => '已完成',
    MoneyTransactionStatus.pending => '待处理',
    MoneyTransactionStatus.voided => '已作废',
  };
}

String _escapeCsv(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
