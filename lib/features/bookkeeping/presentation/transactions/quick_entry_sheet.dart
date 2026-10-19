import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/category_icon.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_leaf_selector.dart';
import 'package:miji/features/bookkeeping/presentation/components/money_keypad.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/amount_calculator_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_account_rules.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

/// 一屏记一笔：分类宫格 + 常驻自绘键盘。**「支出 / 收入」两个动作的默认通道。**
///
/// 现状表单有 10~14 个控件纵向排布，手机上要滚 2~3 屏，而每一笔真正必动的
/// 只有「分类」和「金额」两项。这里把这两件事铺满整屏，其余字段降级：
///
/// * 高频且必须有默认值的（账户）→ 顶部 chip，一眼可见、点一下可换；
/// * 低频的（名称 / 支付方式 / 家庭账本 / 状态 / 他人代付）→ 「更多」面板；
/// * 更边缘的（分摊 / 分期 / 商家 / 地点 / 标签）→ 页面右上「详细填写」转老表单。
///
/// 原表单**没有**被替换，只是不再占着默认路径：编辑已有流水、模板复制、提醒带入、
/// 截图识别这些入口的字段（商家 / 地点 / 标签 / 分摊 / 分期 / 期数）本页根本没有，
/// 只能由老表单承接；而且「详细填写」会带着这里已填的内容跳过去，不是从空白重填。
/// 打开快速记账。
///
/// [initialAmountMinor] / [initialDescription] 用来承接别处的「顺手记一笔」：
/// 想买清单标了「买了」之后，金额和名字已经在手上，不该让用户再打一遍。
///
/// 返回值是**这一轮真正写进去的那笔流水**（取消或没写就是 null）。想买清单靠
/// 它把 `transactionId` 回填到清单项上 —— 不然「已记入流水」那句话没有依据。
Future<MoneyTransactionEntity?> showQuickEntrySheet(
  BuildContext context, {
  MoneyTransactionType initialType = MoneyTransactionType.expense,
  int? initialAmountMinor,
  String? initialDescription,
}) {
  return showAppResponsiveDialog<MoneyTransactionEntity>(
    context: context,
    expandCompactSheet: true,
    builder: (context) => QuickEntrySheet(
      initialType: initialType,
      initialAmountMinor: initialAmountMinor,
      initialDescription: initialDescription,
    ),
  );
}

class QuickEntrySheet extends ConsumerStatefulWidget {
  const QuickEntrySheet({
    super.key,
    required this.initialType,
    this.initialAmountMinor,
    this.initialDescription,
    this.embedded = false,
    this.dock = false,
    this.selectedLeaf,
    this.onSelectedLeafChanged,
  });

  final MoneyTransactionType initialType;

  /// 预填金额（分）。来自「其他地方已经算好的数」，比如想买清单的价格。
  final int? initialAmountMinor;

  /// 预填名称。同样是为了别再让用户打一遍。
  final String? initialDescription;

  /// 作为**页面内容**嵌进别的页面（记账模块的「分类」tab），而不是弹窗。
  ///
  /// 差别只有两处，其余完全共用：
  /// * 不包 [Material] / [Dialog] —— 外层页面已经提供了背景与尺寸约束；
  /// * 保存成功后**不 pop**（把整个 tab 弹掉没人想要），改为清空复位。
  final bool embedded;

  /// 吸底记账条形态：**只留「金额 + 键盘 + 保存」**，分类由外层列表点选。
  ///
  /// 与 [embedded] 的分工：[embedded] 仍是完整界面（自带 header / 分类宫格 /
  /// 备注行 / chip 行），只是不包弹窗；[dock] 连宫格与 header 都去掉——它们
  /// 会吃掉分类列表的空间，而分类列表就在 dock 上面，用户一眼能看到。
  /// 账户 / 日期 / 更多收成金额行右侧的图标，备注走一个单行弹窗。
  final bool dock;

  /// [dock] 形态下外层列表当前选中的分类；`null` = 还没选。
  final CategoryLeaf? selectedLeaf;

  /// [dock] 形态下本组件内部改了分类（「全部」面板）时通知外层，让列表与
  /// 记账条保持同一个选中项——两边各存一份迟早会对不上。
  final ValueChanged<CategoryLeaf?>? onSelectedLeafChanged;

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> {
  static const _frequentCount = 15;

  /// 宽屏两栏的触发宽度。低于它（但非 compact）仍是居中卡片。
  static const _wideBreakpoint = 900.0;

  /// 两栏时弹窗自身的宽度上限。
  static const _wideSheetWidth = 880.0;

  late MoneyTransactionType _type = widget.initialType;
  String _amountText = '';
  String? _categoryId;
  String? _subCategoryId;
  String? _accountId;
  String? _ledgerId;
  MoneyPaymentMethod _paymentMethod = MoneyPaymentMethod.cash;
  MoneyTransactionStatus _status = MoneyTransactionStatus.completed;
  bool _paidByOthers = false;
  DateTime _transactionAt = DateTime.now();
  bool _keepOpen = false;
  bool _submitting = false;
  String? _errorText;

  /// 「详细填写」转出去的老表单，本轮是否成功写入过一笔。
  ///
  /// 老表单带 [TransactionFormDialog.onSubmit] 时成功只 `pop()` 而不带返回值，
  /// 没法靠返回值判断，只能用这个标志：**写过才关掉本页**，用户取消回来时
  /// 还得接着填，不能被一起关掉。
  bool _detailedFormSaved = false;

  /// 「详细填写」那条路写进去的那笔。
  ///
  /// 为什么必须留着：调用方（想买清单）要靠它把 `transactionId` 回填到清单项上，
  /// 否则流水记了、清单却仍显示「未记入」，用户会以为没记成功。
  MoneyTransactionEntity? _detailedFormCreated;

  final _notesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customPaymentNameController = TextEditingController();
  final _notesFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  FToast? _toast;

  @override
  void initState() {
    super.initState();
    final prefillAmount = widget.initialAmountMinor;
    if (prefillAmount != null && prefillAmount > 0) {
      _amountText = (prefillAmount / 100).toStringAsFixed(2);
    }
    final prefillDescription = widget.initialDescription?.trim();
    if (prefillDescription != null && prefillDescription.isNotEmpty) {
      _descriptionController.text = prefillDescription;
    }
    if (widget.dock) {
      _categoryId = widget.selectedLeaf?.categoryId;
      _subCategoryId = widget.selectedLeaf?.subCategoryId;
    }
    // 文本聚焦时把自绘键盘让给系统键盘：不然名字/备注根本没法输入。
    _notesFocus.addListener(_onFocusChanged);
    _descriptionFocus.addListener(_onFocusChanged);
    // 首帧后再读「上次用的账户」——要等 session 与账本 provider 就绪。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_loadRememberedDefaults()),
    );
  }

  @override
  void didUpdateWidget(QuickEntrySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // dock 的分类由外层列表驱动：外层 setState 换选中项后把内部状态跟过来，
    // 免得「列表高亮 A、保存时写的是 B」。
    if (widget.dock &&
        widget.selectedLeaf?.key != oldWidget.selectedLeaf?.key) {
      _categoryId = widget.selectedLeaf?.categoryId;
      _subCategoryId = widget.selectedLeaf?.subCategoryId;
      _errorText = null;
    }
    // dock 上收支分段在外层（分类页顶部）：外层切了收支，这里跟着换目录。
    if (widget.initialType != oldWidget.initialType &&
        widget.initialType != _type) {
      _type = widget.initialType;
      _categoryId = null;
      _subCategoryId = null;
      _accountId = null;
      _errorText = null;
      unawaited(_loadRememberedDefaults());
    }
  }

  @override
  void dispose() {
    _notesFocus.removeListener(_onFocusChanged);
    _descriptionFocus.removeListener(_onFocusChanged);
    _notesFocus.dispose();
    _descriptionFocus.dispose();
    _notesController.dispose();
    _descriptionController.dispose();
    _customPaymentNameController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  bool get _textEditing => _notesFocus.hasFocus || _descriptionFocus.hasFocus;

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  MoneyCategoryKind get _categoryKind => _type == MoneyTransactionType.income
      ? MoneyCategoryKind.income
      : MoneyCategoryKind.expense;

  List<MoneyAccountEntity> get _selectableAccounts {
    final accounts = ref
        .watch(currentUserVisibleAccountsProvider)
        .maybeWhen(
          data: (value) => value.where((account) => account.isActive).toList(),
          orElse: () => const <MoneyAccountEntity>[],
        );
    final internal = ref
        .watch(currentUserMoneyInternalAccountsProvider)
        .maybeWhen(
          data: (value) => value.where((account) => account.isActive).toList(),
          orElse: () => const <MoneyAccountEntity>[],
        );
    return selectableAccountsForType(_type, [...accounts, ...internal]);
  }

  /// 上次录入用的账户与支付方式，按 `userId + 账本 + 收支` 分桶存在
  /// `TransactionEntryDefaultsStore`（SharedPreferences）里。
  ///
  /// 写入不需要新代码：保存时 `createTransaction(rememberDefaults: true)` 已经把
  /// 账户 / 支付方式 / 分类一并写进同一个 store，老表单读的也是它。这里补的是
  /// **读取**——原来每次进都退回「第一个可用账户」。
  ///
  /// 日期**刻意不记**：绝大多数场景默认「今天」才对，带出上次的日期反而会在补记
  /// 时悄悄记错日子；store 里也没有这个字段。
  ///
  /// 读失败（未解锁 / 没存过 / 账户已删）一律静默：账户 chip 就在金额下面一眼
  /// 可见，退回默认值不会有任何损失。
  Future<void> _loadRememberedDefaults() async {
    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      return;
    }
    final type = _type;
    // 与保存时同一个 key：`_ledgerId` 为空表示跟随当前有效账本。
    final ledgerId =
        _ledgerId ??
        ref.read(currentUserEffectiveTransactionLedgerValueProvider)?.id;
    final defaults = await ref
        .read(transactionEntryDefaultsStoreProvider)
        .readDefaults(userId: userId, ledgerId: ledgerId, type: type);
    if (!mounted || defaults == null || _type != type) {
      return;
    }
    setState(() {
      // 用户在异步返回前已经手动选过账户 → 不能覆盖他刚做的选择。
      _accountId ??= defaults.accountId;
      final method = defaults.paymentMethod;
      if (method != null) {
        // 记住的支付方式可能不适用于当前账户（如现金只认 cash），
        // 保存时会经 `effectivePaymentMethodForAccount` 兜底，这里不必先判。
        _paymentMethod = method;
      }
    });
  }

  /// 当前账户：用户选过就用选的，否则退回第一个可用账户。
  ///
  /// 「上次用过哪个账户」由 [_loadRememberedDefaults] 异步补进 [_accountId]；
  /// 记忆里的账户被删或已停用时，这里会自动退回第一个可用账户。
  MoneyAccountEntity? get _selectedAccount {
    final accounts = _selectableAccounts;
    if (accounts.isEmpty) {
      return null;
    }
    final accountId = _accountId;
    if (accountId != null) {
      for (final account in accounts) {
        if (account.id == accountId) {
          return account;
        }
      }
    }
    return accounts.first;
  }

  String get _currencyCode =>
      _selectedAccount?.currencyCode ?? defaultMoneyCurrencyCode;

  MoneyCategoryUsage get _usage {
    return ref
        .watch(currentUserCategoryUsageStatsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyCategoryUsage.empty(),
        );
  }

  /// 当前输入能解析出的金额；空或算式不完整时为 null。
  int? get _amountMinor {
    if (_amountText.trim().isEmpty) {
      return null;
    }
    try {
      return parseMoneyAmountToMinor(_amountText);
    } on MoneyAmountParseException {
      return null;
    }
  }

  // ── 键盘输入 ────────────────────────────────────────────────────────────

  String get _lastSegment {
    final text = _amountText;
    var index = text.length - 1;
    while (index >= 0 && !'+-*/'.contains(text[index])) {
      index--;
    }
    return text.substring(index + 1);
  }

  void _appendDigit(String digit) {
    setState(() {
      _errorText = null;
      // 「0」后面再按数字：替换掉它，避免攒出 05 这种前导零。
      if (_lastSegment == '0') {
        _amountText =
            '${_amountText.substring(0, _amountText.length - 1)}$digit';
        return;
      }
      _amountText = '$_amountText$digit';
    });
  }

  void _appendDot() {
    setState(() {
      _errorText = null;
      final segment = _lastSegment;
      if (segment.contains('.')) {
        return;
      }
      _amountText = segment.isEmpty ? '${_amountText}0.' : '$_amountText.';
    });
  }

  void _appendPlus() {
    setState(() {
      _errorText = null;
      if (_amountText.isEmpty) {
        return;
      }
      final last = _amountText[_amountText.length - 1];
      // 连按运算符就换掉上一个，免得出现 12++ 这种表达式。
      _amountText = '+-*/'.contains(last)
          ? '${_amountText.substring(0, _amountText.length - 1)}+'
          : '$_amountText+';
    });
  }

  void _backspace() {
    if (_amountText.isEmpty) {
      return;
    }
    setState(() {
      _errorText = null;
      _amountText = _amountText.substring(0, _amountText.length - 1);
    });
  }

  void _clearAmount() {
    setState(() {
      _errorText = null;
      _amountText = '';
    });
  }

  Future<void> _openCalculator() async {
    final result = await showAmountCalculatorSheet(
      context,
      initialText: _amountText,
      currencyCode: _currencyCode,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _errorText = null;
      _amountText = result;
    });
  }

  // ── 选择 ───────────────────────────────────────────────────────────────

  void _switchType(MoneyTransactionType type) {
    if (type == _type) {
      return;
    }
    setState(() {
      _type = type;
      // 分类目录按收支分开，切换后原分类一定不在新目录里。
      _categoryId = null;
      _subCategoryId = null;
      // 收入不能进信用账户；原账户若不适用就退回默认（getter 会自动兜底）。
      _accountId = null;
      _errorText = null;
    });
    // 收支分桶存默认值，换了收支就得换一批「上次选择」。
    unawaited(_loadRememberedDefaults());
  }

  void _selectLeaf(CategoryLeaf leaf) {
    setState(() {
      _errorText = null;
      _categoryId = leaf.categoryId;
      _subCategoryId = leaf.subCategoryId;
    });
    widget.onSelectedLeafChanged?.call(leaf);
  }

  /// dock 上「×」：取消选中，回到「点列表里的分类开始记账」。
  void _clearSelectedLeaf() {
    setState(() {
      _errorText = null;
      _categoryId = null;
      _subCategoryId = null;
    });
    widget.onSelectedLeafChanged?.call(null);
  }

  Future<void> _openAllLeaves(List<CategoryLeaf> leaves) async {
    final picked = await showCategoryLeafSheet(
      context: context,
      leaves: leaves,
      usage: _usage,
      selectedKey: CategoryLeaf.keyOf(_categoryId, _subCategoryId),
    );
    if (picked == null || !mounted) {
      return;
    }
    _selectLeaf(picked);
  }

  Future<void> _pickAccount() async {
    final accounts = _selectableAccounts;
    if (accounts.isEmpty) {
      return;
    }
    final current = _selectedAccount;
    // 「隐藏金额」在这里先取好再传进弹窗：bottom sheet 挂在根 Navigator 上，
    // 祖先链里没有 AppShellPage 的 MoneyPrivacyScope，在弹窗里就地读只会拿到
    // `false`——开着隐藏金额也照样把每个账户的余额照出来。
    final masked = MoneyPrivacy.of(context);
    final picked = await showModalBottomSheet<MoneyAccountEntity>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final account in accounts)
              ListTile(
                // 与支出表单的账户下拉同一份内容：图标 + 「名称 · 类型」+ 余额。
                // 只写账户名不够——挑信用卡时真正要看的是它还剩多少可用额度，
                // 挑储蓄账户时看的是够不够扣。
                title: AccountOptionContent(account: account, masked: masked),
                trailing: account.id == current?.id
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(account),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _accountId = picked.id;
      // 账户会锁定支付方式（支付宝账户 → 支付宝），跟着切一次。
      _paymentMethod = effectivePaymentMethodForAccount(picked, _paymentMethod);
    });
  }

  /// 选支付渠道（dock 字段行那一格）。
  ///
  /// 只在账户没锁定支付方式时才可能被调用——锁定时可选集合只有一项，弹出来
  /// 也没得选。选到「其他」还要补一句名称：光落一个 other 进库，统计里就是
  /// 一堆说不清的「其他」。
  Future<void> _pickPaymentMethod() async {
    final account = _selectedAccount;
    final methods = availablePaymentMethodsForAccount(account);
    if (methods.length < 2) {
      return;
    }
    final current = effectivePaymentMethodForAccount(account, _paymentMethod);
    final picked = await showModalBottomSheet<MoneyPaymentMethod>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final method in methods)
              ListTile(
                leading: const Icon(Icons.credit_card_rounded),
                title: Text(method.label),
                trailing: method == current
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(method),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _paymentMethod = picked);
    if (picked != MoneyPaymentMethod.other) {
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _DockTextDialog(
        title: '支付方式名称',
        hint: '如：美团月付、抖音月付',
        initialText: _customPaymentNameController.text,
      ),
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() => _customPaymentNameController.text = name.trim());
  }

  /// dock 的日期 / 时间：三个快捷（今天 / 昨天 / 前天）+ 一个能选到**分钟**的日历。
  ///
  /// 快捷项沿用**已选的时分**而不是抹成 00:00：补记昨天的饭钱时「几点吃的」
  /// 仍是自己知道的信息，落成 00:00 之后再想改回正确时间就得整条重来。
  /// 每一项都把自己的完整取值写在副标题里，免得用户按了「昨天」却不知道
  /// 会写成哪个时刻。
  ///
  /// 「日期与时间…」直接复用全项目共用的 [showAppDatePicker]（老表单 / 转账
  /// 表单同一套）——原来这里调的是裸的 `showDatePicker`，**选不到分钟**。
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in <(String, int)>[
              ('今天', 0),
              ('昨天', -1),
              ('前天', -2),
            ])
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(option.$1),
                subtitle: Text(_formatDateTime(_dateWithKeptTime(option.$2))),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_dateWithKeptTime(option.$2)),
              ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('日期与时间…'),
              subtitle: const Text('可精确到分钟'),
              onTap: () async {
                final date = await showAppDatePicker(
                  context: sheetContext,
                  initialDate: _transactionAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(today.year + 1, 12, 31),
                  showTime: true,
                );
                if (date != null && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(date);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _transactionAt = picked);
  }

  /// 第 [dayOffset] 天（0 今天、-1 昨天…），时分秒沿用当前已选值。
  DateTime _dateWithKeptTime(int dayOffset) {
    final target = DateTime.now().add(Duration(days: dayOffset));
    return DateTime(
      target.year,
      target.month,
      target.day,
      _transactionAt.hour,
      _transactionAt.minute,
      _transactionAt.second,
    );
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)} '
        '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }

  Future<void> _openMorePanel() async {
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);
    final familyLedgers = ref
        .watch(currentUserMoneyLedgersProvider)
        .maybeWhen(
          data: (value) =>
              value.where((item) => item.isFamily).toList(growable: false),
          orElse: () => const <MoneyLedgerEntity>[],
        );
    final account = _selectedAccount;
    final result = await showModalBottomSheet<_MoreFieldsResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _MoreFieldsPanel(
        initial: _MoreFieldsResult(
          description: _descriptionController.text,
          ledgerId: _ledgerId ?? ledger?.id,
          paymentMethod: _paymentMethod,
          customPaymentName: _customPaymentNameController.text,
          paidByOthers: _paidByOthers,
          status: _status,
        ),
        familyLedgers: familyLedgers,
        availablePaymentMethods: availablePaymentMethodsForAccount(account),
        paymentMethodLocked: lockedPaymentMethodForAccount(account) != null,
        showPaidByOthers: _type == MoneyTransactionType.expense,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _descriptionController.text = result.description;
      _ledgerId = result.ledgerId;
      _paymentMethod = result.paymentMethod;
      _customPaymentNameController.text = result.customPaymentName;
      _paidByOthers = result.paidByOthers;
      _status = result.status;
      if (result.status == MoneyTransactionStatus.pending) {
        // 待处理不入账、不分摊，没什么要额外清的，但保留这条注释说明意图。
      }
    });
  }

  /// 「详细填写」：带着这里已经填好的内容转到老表单。
  ///
  /// 本页刻意只放高频字段，商家 / 地点 / 标签 / 分摊 / 分期这些没有落点；
  /// 但用户按下去时不能给一张空白表单——金额、分类、备注、账户、日期都带过去，
  /// 老表单只补差额。老表单写成功后再关掉本页，否则同一笔会被记两次。
  Future<void> _openDetailedForm() async {
    if (_submitting) {
      return;
    }
    final account = _selectedAccount;
    final amountMinor = _amountMinor;
    final notes = _notesController.text.trim();
    final description = _descriptionController.text.trim();
    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (dialogContext) => TransactionFormDialog(
        type: _type,
        ledger: ref.read(currentUserEffectiveTransactionLedgerValueProvider),
        initialAmountMinor: amountMinor,
        initialAccountId: account?.id,
        initialPaymentMethod: account == null
            ? null
            : effectivePaymentMethodForAccount(account, _paymentMethod),
        initialDescription: description.isEmpty ? null : description,
        initialNotes: notes.isEmpty ? null : notes,
        initialTransactionAt: _transactionAt,
        categoryId: _categoryId,
        subCategoryId: _subCategoryId,
        onSubmit: _createFromDetailedForm,
      ),
    );
    if (!mounted) {
      return;
    }
    if (_detailedFormSaved) {
      _detailedFormSaved = false;
      final created = _detailedFormCreated;
      _detailedFormCreated = null;
      if (widget.embedded) {
        // 内嵌时本页就是「分类」tab：已经写库成功，清空接着记即可。
        _resetAfterSubmit();
      } else {
        Navigator.of(context).pop(created);
      }
    }
  }

  /// 老表单的提交回调：写库，并把失败原因翻译成表单上的错误文案。
  ///
  /// 成功提示在这里发而不是留给老表单——两个页面叠着，提示点按用户当前的
  /// 视线位置走更合理，且与本页自身的提交路径文案一致。
  Future<String?> _createFromDetailedForm(Object result) async {
    if (result is! TransactionCreateFormResult) {
      return null;
    }
    try {
      _detailedFormCreated = await _writeTransaction(result);
      _detailedFormSaved = true;
      if (!mounted) {
        return null;
      }
      AppToast.success(_ensureToast(), context, '${_type.label}已记录');
      return null;
    } catch (error) {
      return _errorTextFor(error);
    }
  }

  /// 写库（含分摊）。与「详细填写」共用，口径与 [MoneyQuickActionLauncher]
  /// 里那一份保持一致，避免两条通道对同一份结果做不同的处理。
  Future<MoneyTransactionEntity> _writeTransaction(
    TransactionCreateFormResult result,
  ) {
    final actions = ref.read(currentUserMoneyTransactionActionsProvider);
    final splitConfig = result.splitConfig;
    return splitConfig == null
        ? actions.createTransaction(result.draft)
        : actions.createTransactionWithSplit(result.draft, splitConfig);
  }

  // ── 提交 ───────────────────────────────────────────────────────────────

  Future<void> _submit({required bool keepOpen}) async {
    if (_submitting) {
      return;
    }
    final amountMinor = _amountMinor;
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorText = '请输入大于 0 的金额');
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _errorText = '请选择分类');
      return;
    }
    final account = _selectedAccount;
    if (account == null) {
      setState(
        () => _errorText = _type == MoneyTransactionType.income
            ? '暂无可用于收入的账户'
            : '暂无可选账户',
      );
      return;
    }

    final notes = _notesController.text.trim();
    final description = _descriptionController.text.trim();
    final customPaymentName = _customPaymentNameController.text.trim();
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final created = await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransaction(
            MoneyTransactionDraft(
              type: _type,
              transactionAt: _transactionAt,
              amountMinor: amountMinor,
              currencyCode: account.currencyCode,
              // 没写名字就退回类型名，列表会把这类通用文案过滤掉。
              description: description.isEmpty ? _type.label : description,
              notes: notes.isEmpty ? null : notes,
              accountId: account.id,
              categoryId: categoryId,
              subCategoryId: _subCategoryId,
              paymentMethod: effectivePaymentMethodForAccount(
                account,
                _paymentMethod,
              ),
              customPaymentMethodName: customPaymentName.isEmpty
                  ? null
                  : customPaymentName,
              ledgerId: _ledgerId ?? ledger?.id,
              status: _status,
            ),
          );
      if (!mounted) {
        return;
      }
      AppToast.success(_ensureToast(), context, '${_type.label}已记录');
      if (keepOpen || widget.embedded) {
        // 内嵌在「分类」tab 里时没有「保存后关闭」这回事——pop 会把整个
        // 记账页弹掉；一律按「保存再记」的口径清空，好接着记下一笔。
        _resetAfterSubmit();
      } else {
        // 把写进去的那笔带出去：调用方（想买清单）要拿 id 回填。
        Navigator.of(context).pop(created);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = _errorTextFor(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  /// 「保存再记」只清「这一笔特有」的金额与备注；分类 / 账户这些连续记账
  /// 时要沿用的上下文保留（与老表单的复位口径一致）。
  void _resetAfterSubmit() {
    setState(() {
      _amountText = '';
      _notesController.clear();
      _errorText = null;
    });
  }

  String _errorTextFor(Object error) {
    if (error is! MoneyRepositoryException) {
      return '保存失败，请稍后重试';
    }
    return switch (error.code) {
      MoneyRepositoryErrorCode.insufficientFunds => '账户余额不足',
      MoneyRepositoryErrorCode.accountNotFound => '账户不可用，请重新选择',
      MoneyRepositoryErrorCode.creditCardLimitExceeded => '信用账户额度不足',
      MoneyRepositoryErrorCode.categoryNotFound => '分类不可用，请重新选择',
      MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败，请稍后重试',
      _ => '保存失败，请稍后重试',
    };
  }

  // ── 构建 ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final responsive = AppResponsive.of(context);
    final compact = responsive.isCompact;
    // 宽屏左右两栏：左边挑分类，右边金额 + 键盘各占一块。
    // 单栏卡片在宽屏上只有 520 宽、却要撑 720 高，宫格与键盘都会被拉得很空。
    final wide =
        !compact && MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final catalog = ref.watch(
      currentUserCategoryCatalogProvider(_categoryKind),
    );

    final amountBlock = _amountDisplay(theme, colorScheme);
    final notesBlock = _notesRow(theme, colorScheme);
    final chipsBlock = _chipRow(theme, colorScheme);
    final gridBlock = catalog.when(
      data: (value) => _categoryGrid(value),
      loading: () => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Text(
          '分类读取失败',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ),
    );
    final errorBlock = _errorText == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          );

    final body = Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(theme, colorScheme),
        Expanded(
          child: wide
              ? Row(
                  key: const ValueKey('quick-entry-two-column'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 105,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: gridBlock),
                            const SizedBox(height: 8),
                            chipsBlock,
                            ?errorBlock,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    Expanded(
                      flex: 100,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            amountBlock,
                            const SizedBox(height: 8),
                            notesBlock,
                            const Spacer(),
                            // 两栏时键盘留在右栏底部：和金额贴在一起，
                            // 视线不用在左右之间来回跳。
                            if (!_textEditing) _keypad(),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      amountBlock,
                      const SizedBox(height: 8),
                      notesBlock,
                      const SizedBox(height: 8),
                      chipsBlock,
                      const SizedBox(height: 8),
                      Expanded(child: gridBlock),
                      ?errorBlock,
                    ],
                  ),
                ),
        ),
        // 单栏时键盘才是贴底的独立一栏；两栏时它已经在右栏里了。
        // 文本聚焦时一律让位给系统键盘，否则名称/备注没法输入。
        if (!wide && !_textEditing) _keypad(),
      ],
    );

    // 吸底记账条：只出「选中分类 + 金额 + 键盘」，分类列表由外层渲染。
    // 它比完整界面矮得多——分类页本来就要给列表留出一屏的空间。
    if (widget.dock) {
      return Column(
        key: const ValueKey('quick-entry-dock'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dockAmountRow(theme, colorScheme),
          const SizedBox(height: 6),
          _dockFieldRow(theme, colorScheme),
          ?errorBlock,
          const SizedBox(height: 6),
          if (!_textEditing) _keypad(dock: true),
        ],
      );
    }

    // 内嵌时外层页面已经给了背景与尺寸约束，这里只出内容。
    if (widget.embedded) {
      return body;
    }

    final content = Material(
      color: colorScheme.surface,
      borderRadius: compact
          ? BorderRadius.vertical(top: Radius.circular(radius.lg))
          : BorderRadius.circular(radius.lg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : (wide ? _wideSheetWidth : 520),
          maxHeight: compact ? double.infinity : 720,
        ),
        child: body,
      ),
    );

    if (compact) {
      return content;
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.lg),
      ),
      child: content,
    );
  }

  Widget _header(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 152,
            child: AppSlidingSegmentedControl<MoneyTransactionType>(
              minSegmentWidth: 72,
              value: _type,
              onChanged: _switchType,
              segments: const [
                AppSlidingSegment(
                  value: MoneyTransactionType.expense,
                  label: '支出',
                ),
                AppSlidingSegment(
                  value: MoneyTransactionType.income,
                  label: '收入',
                ),
              ],
            ),
          ),
          const Spacer(),
          FilterChip(
            label: const Text('保存再记'),
            selected: _keepOpen,
            onSelected: (value) => setState(() => _keepOpen = value),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _amountDisplay(ThemeData theme, ColorScheme colorScheme) {
    final amountMinor = _amountMinor;
    final expression = _amountText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      expression.isEmpty ? '金额' : expression,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                Text(
                  formatMoneyMinor(amountMinor ?? 0, _currencyCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: amountMinor == null
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '金额计算器',
            onPressed: _submitting ? null : _openCalculator,
            icon: const Icon(Icons.calculate_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  /// dock 顶部的选中分类条。
  ///
  /// 没选分类时它不是空白，而是把「下一步要点什么」写出来——dock 上没有
  /// 宫格，不写的话用户会对着键盘发愣。
  /// 金额行右侧的「这一笔记到哪个分类」。
  ///
  /// 它原来单独占一整行（分类条），但那一行多数时候只有「点上方分类开始记账」
  /// 或一个名字，而金额本身窄——两件窄东西各占一行，等于白送 40px 给留白，
  /// 分类列表就少看半张卡。现在并进金额行：**左侧金额、右侧分类**，
  /// 一行说完「多少钱、记到哪」。
  ///
  /// 选中后显示**「父分类 · 子分类」**而不是光一个名字：分类列表里「早餐」
  /// 可能不止一处，带上父分类才知道自己点的是哪一个。
  Widget _dockCategorySlot(ThemeData theme, ColorScheme colorScheme) {
    final leaf = widget.selectedLeaf;
    if (leaf == null) {
      return ConstrainedBox(
        // 限宽，别让这句提示把金额区挤黄：它是非 flex 子项，先于 Expanded 拿
        // 尺寸，不限宽的话字体一放大就轮到金额被 ellipsis。
        constraints: const BoxConstraints(maxWidth: 120),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: Text(
            '点上方分类开始记账',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }

    final color = appColorFromHex(leaf.colorHex, fallback: colorScheme.primary);
    final label = leaf.isChild
        ? '${leaf.category.name} · ${leaf.name}'
        : leaf.category.name;

    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
      padding: const EdgeInsets.fromLTRB(8, 0, 2, 0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryIconWidget(leaf.iconName, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: '取消选择',
            onPressed: _clearSelectedLeaf,
            icon: const Icon(Icons.close_rounded, size: 15),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
          ),
        ],
      ),
    );
  }

  /// dock 的金额行：左边金额（点一下开计算器），右边是分类。
  ///
  /// 备注 / 账户 / 日期 / 更多**不在这里**——它们曾经是右侧四个图标，但图标
  /// 只能说明「这里有个设置」，说明不了**当前值**（今天是哪天、走的哪个账户、
  /// 备注写了什么），全都得点开才知道；改成下面一行 chip（[_dockFieldRow]），
  /// 把值直接写出来。
  Widget _dockAmountRow(ThemeData theme, ColorScheme colorScheme) {
    final amountMinor = _amountMinor;
    return Container(
      key: const ValueKey('dock-amount-row'),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              // 点金额区开计算器：dock 上没地方再塞一个计算器按钮。
              onTap: _submitting ? null : _openCalculator,
              borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 15,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _amountText.isEmpty ? '金额' : _amountText,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    formatMoneyMinor(amountMinor ?? 0, _currencyCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: amountMinor == null
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _dockCategorySlot(theme, colorScheme),
        ],
      ),
    );
  }

  /// dock 的字段行：备注 / 账户 / 日期 / 更多，**每一项都显示当前值**。
  ///
  /// 没填过显示字段名（点开去填），填了就显示值本身（点开去改）——这一行
  /// 的作用是让用户在按「保存」之前就能看清这一笔会以什么参数记下来，而不是
  /// 把账户 / 日期藏在图标背后。横向排一行可滚动：账户名长短不一，写死三等分
  /// 会让长的先溢出。
  Widget _dockFieldRow(ThemeData theme, ColorScheme colorScheme) {
    final account = _selectedAccount;
    final notes = _notesController.text.trim();
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _DockFieldChip(
            icon: const Icon(Icons.notes_rounded),
            label: notes.isEmpty ? '备注' : notes,
            filled: notes.isNotEmpty,
            tooltip: '备注',
            onTap: _submitting ? null : _openDockNotes,
          ),
          const SizedBox(width: 6),
          _DockFieldChip(
            icon: account == null
                ? const Icon(Icons.account_balance_wallet_rounded)
                : AccountIconView(account: account, size: 14, imageSize: 18),
            label: account?.name ?? '账户',
            tooltip: '账户',
            onTap: _submitting ? null : _pickAccount,
          ),
          const SizedBox(width: 6),
          // 支付渠道只在账户**没锁死**它的时候出现：支付宝账户必然是支付宝、
          // 现金账户必然是现金，此时这一格点开也只有一项，纯粹占地方；
          // 真正需要选的是信用卡 / 其它信用这类一个账户能走好几条渠道的。
          if (lockedPaymentMethodForAccount(account) == null) ...[
            _DockFieldChip(
              icon: const Icon(Icons.credit_card_rounded),
              label: effectivePaymentMethodForAccount(
                account,
                _paymentMethod,
              ).label,
              tooltip: '支付渠道',
              onTap: _submitting ? null : _pickPaymentMethod,
            ),
            const SizedBox(width: 6),
          ],
          _DockFieldChip(
            icon: const Icon(Icons.event_rounded),
            label: _dateLabel(),
            filled: !_isToday,
            // chip 限宽会截断长日期，完整取值放 tooltip。
            tooltip: _formatDateTime(_transactionAt),
            onTap: _submitting ? null : _pickDate,
          ),
          const SizedBox(width: 6),
          _DockFieldChip(
            icon: const Icon(Icons.settings_rounded),
            label: '更多',
            tooltip: '更多设置',
            onTap: _submitting ? null : _openDockMore,
          ),
        ],
      ),
    );
  }

  /// 日期是不是今天：不是今天才把日期 chip 点成主色，免得「今天」这种
  /// 默认值也跟着高亮、把真正需要留意的补记日子淹掉。
  bool get _isToday {
    final now = DateTime.now();
    return _transactionAt.year == now.year &&
        _transactionAt.month == now.month &&
        _transactionAt.day == now.day;
  }

  /// dock 的「更多」：先让用户挑「补几个字段」还是「转完整表单」。
  ///
  /// 完整界面里这两件事各占一个 chip，dock 上只剩一个图标位——合成一个菜单，
  /// 省下的那格留给备注。
  Future<void> _openDockMore() async {
    final choice = await showModalBottomSheet<_DockMoreChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('更多字段'),
              subtitle: const Text('名称 / 账本 / 支付方式 / 状态'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_DockMoreChoice.fields),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('详细填写'),
              subtitle: const Text('分摊 / 分期 / 商家 / 地点 / 标签'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_DockMoreChoice.detailed),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    switch (choice) {
      case _DockMoreChoice.fields:
        await _openMorePanel();
      case _DockMoreChoice.detailed:
        await _openDetailedForm();
    }
  }

  /// dock 上写备注：一行弹窗。
  ///
  /// 完整界面里备注是常驻输入框，dock 上它一周用不到一次，为此占掉一行不划算。
  /// controller 交给 [_DockNotesDialog] 自己持有并随弹窗释放——**不能**在
  /// `await showDialog` 之后 dispose：dialog 的 future 在 pop 时就 complete，
  /// 而退出动画还在跑，弹窗会拿着已释放的 controller 再 build 一帧，直接抛
  /// "used after being disposed"。
  Future<void> _openDockNotes() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _DockTextDialog(
        title: '备注',
        hint: '这一笔花在哪',
        initialText: _notesController.text,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _notesController.text = result.trim());
  }

  Widget _notesRow(ThemeData theme, ColorScheme colorScheme) {
    return AppTextField(
      controller: _notesController,
      focusNode: _notesFocus,
      hintText: '备注（可选）',
      prefixIcon: const Icon(Icons.notes_rounded, size: 18),
      textInputAction: TextInputAction.done,
    );
  }

  Widget _chipRow(ThemeData theme, ColorScheme colorScheme) {
    final account = _selectedAccount;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            context,
            icon: account == null
                ? const Icon(Icons.account_balance_wallet_rounded)
                : AccountIconView(account: account, size: 15, imageSize: 20),
            label: account?.name ?? '选择账户',
            onTap: _submitting ? null : _pickAccount,
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            icon: const Icon(Icons.event_rounded),
            label: _dateLabel(),
            onTap: _submitting ? null : _pickDate,
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            icon: const Icon(Icons.tune_rounded),
            label: '更多',
            onTap: _submitting ? null : _openMorePanel,
          ),
          const SizedBox(width: 8),
          // 「更多」补的是本页已有的低频字段，「详细填写」才是转去老表单
          // （分摊 / 分期 / 商家 / 地点 / 标签都在那边）。两个都叫「更多」会
          // 让人分不清哪个点下去会换页面，所以名字分开写。
          _chip(
            context,
            icon: const Icon(Icons.edit_note_rounded),
            label: '详细填写',
            onTap: _submitting ? null : _openDetailedForm,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
                child: icon,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 日期 chip 的文案，**带时分**。
  ///
  /// 既然时间能精确到分钟，这里就必须把时分带出来：不然用户在日历里挑了
  /// 14:30，回到记账条上还是只看到「今天」，等于白选——用户没法确认到底
  /// 记在哪一刻。
  String _dateLabel() {
    final now = DateTime.now();
    final date = DateTime(
      _transactionAt.year,
      _transactionAt.month,
      _transactionAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    final clock =
        '${_twoDigits(_transactionAt.hour)}:${_twoDigits(_transactionAt.minute)}';
    if (diff == 0) {
      return '今天 $clock';
    }
    if (diff == 1) {
      return '昨天 $clock';
    }
    if (diff == 2) {
      return '前天 $clock';
    }
    if (date.year == now.year) {
      return '${date.month}月${date.day}日 $clock';
    }
    return '${date.year}年${date.month}月${date.day}日 $clock';
  }

  Widget _categoryGrid(MoneyCategoryCatalog catalog) {
    final leaves = buildCategoryLeaves(catalog);
    if (leaves.isEmpty) {
      return Center(
        child: Text(
          '暂无可选分类',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      );
    }
    final frequent = pickFrequentLeaves(leaves, _usage, count: _frequentCount);
    final selectedKey = CategoryLeaf.keyOf(_categoryId, _subCategoryId);

    return SingleChildScrollView(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 5,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        mainAxisExtent: 62,
        children: [
          for (final leaf in frequent)
            _QuickCategoryTile(
              leaf: leaf,
              selected: leaf.key == selectedKey,
              onTap: _submitting ? null : () => _selectLeaf(leaf),
            ),
          _QuickAllCategoriesTile(
            count: leaves.length,
            onTap: _submitting ? null : () => _openAllLeaves(leaves),
          ),
        ],
      ),
    );
  }

  /// 键盘。
  ///
  /// dock 上它是全屏最高的那一块，直接决定分类列表还剩多少空间：键高
  /// 48→38、间距 8→6 之后四行从 216px 压到 170px，而按下去的手感没变
  /// （键宽远大于键高，纵向缩一点不影响命中）。
  Widget _keypad({bool dock = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        dock ? 8 : 12,
        0,
        dock ? 8 : 12,
        dock ? 8 : 12,
      ),
      child: MoneyKeypad(
        height: dock ? 38 : 44,
        spacing: dock ? 6 : 8,
        rowSpacing: dock ? 6 : 8,
        rows: [
          [
            MoneyKeySpec('7', () => _appendDigit('7')),
            MoneyKeySpec('8', () => _appendDigit('8')),
            MoneyKeySpec('9', () => _appendDigit('9')),
            MoneyKeySpec(
              '⌫',
              _backspace,
              tone: MoneyKeyTone.neutral,
              semanticLabel: '退格',
            ),
          ],
          [
            MoneyKeySpec('4', () => _appendDigit('4')),
            MoneyKeySpec('5', () => _appendDigit('5')),
            MoneyKeySpec('6', () => _appendDigit('6')),
            MoneyKeySpec(
              '+',
              _appendPlus,
              tone: MoneyKeyTone.operator,
              semanticLabel: '加',
            ),
          ],
          [
            MoneyKeySpec('1', () => _appendDigit('1')),
            MoneyKeySpec('2', () => _appendDigit('2')),
            MoneyKeySpec('3', () => _appendDigit('3')),
            MoneyKeySpec(
              'C',
              _clearAmount,
              tone: MoneyKeyTone.neutral,
              semanticLabel: '清空',
            ),
          ],
          [
            MoneyKeySpec('0', () => _appendDigit('0'), flex: 2),
            MoneyKeySpec('.', _appendDot),
            MoneyKeySpec(
              '保存',
              _submitting ? null : () => _submit(keepOpen: _keepOpen),
              tone: MoneyKeyTone.operator,
              semanticLabel: '保存',
            ),
          ],
        ],
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// dock 上「更多」的两个去向。
enum _DockMoreChoice { fields, detailed }

/// dock 上「一句话输入」的弹窗：备注用它，支付渠道选「其他」后补名称也用它。
///
/// controller 由它自己持有并在 dispose 里释放——**不能**在 `await showDialog`
/// 之后 dispose：dialog 的 future 在 pop 时就 complete，而退出动画还在跑，
/// 弹窗会拿着已释放的 controller 再 build 一帧，抛 "used after being disposed"。
class _DockTextDialog extends StatefulWidget {
  const _DockTextDialog({
    required this.title,
    required this.hint,
    required this.initialText,
  });

  final String title;
  final String hint;
  final String initialText;

  @override
  State<_DockTextDialog> createState() => _DockTextDialogState();
}

class _DockTextDialogState extends State<_DockTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        decoration: InputDecoration(hintText: widget.hint),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// dock 字段行里的一个 chip：图标 + **当前值**。
///
/// 值可能很长（备注一句话、账户名），所以限宽 132px 后截断——一行放四个
/// 又不挤掉金额，靠的是横向滚动而不是无限收缩字号。
class _DockFieldChip extends StatelessWidget {
  const _DockFieldChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  /// 图标走 Widget：账户 chip 要能渲染用户自定义图片 / SVG 图标。
  final Widget icon;
  final String label;

  /// 长按提示：值被截断时它是看清完整内容的唯一途径。
  final String tooltip;
  final VoidCallback? onTap;

  /// 已偏离默认值（写了备注 / 不是今天）才点亮，作为「这一笔和默认不一样」的提示。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = filled ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled
            ? colorScheme.primaryContainer.withValues(alpha: 0.42)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 14, color: accent),
                    child: icon,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: filled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 宫格里的一个分类格：图标 + 一行叶子名。
class _QuickCategoryTile extends StatelessWidget {
  const _QuickCategoryTile({
    required this.leaf,
    required this.selected,
    required this.onTap,
  });

  final CategoryLeaf leaf;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = appColorFromHex(leaf.colorHex, fallback: colorScheme.primary);

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.42)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: leaf.isChild
              ? '${leaf.category.name} ${leaf.name}'
              : leaf.name,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant.withValues(alpha: 0.56),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CategoryIconWidget(
                        leaf.iconName,
                        size: 17,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leaf.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected ? color : colorScheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 与「全部 N」格：打开现有的底部搜索面板。
class _QuickAllCategoriesTile extends StatelessWidget {
  const _QuickAllCategoriesTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '全部分类，共 $count 个',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.56),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 17,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '全部 $count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「更多」面板一次性返回的字段。
@immutable
class _MoreFieldsResult {
  const _MoreFieldsResult({
    required this.description,
    required this.ledgerId,
    required this.paymentMethod,
    required this.customPaymentName,
    required this.paidByOthers,
    required this.status,
  });

  final String description;
  final String? ledgerId;
  final MoneyPaymentMethod paymentMethod;
  final String customPaymentName;
  final bool paidByOthers;
  final MoneyTransactionStatus status;
}

/// 低频字段面板：名称 / 家庭账本 / 支付方式 / 他人代付 / 状态。
///
/// 面板内维护一份临时状态，点「完成」才回传给主界面——避免用户改了一半
/// 又划走时，主界面已经被改脏。
class _MoreFieldsPanel extends StatefulWidget {
  const _MoreFieldsPanel({
    required this.initial,
    required this.familyLedgers,
    required this.availablePaymentMethods,
    required this.paymentMethodLocked,
    required this.showPaidByOthers,
  });

  final _MoreFieldsResult initial;
  final List<MoneyLedgerEntity> familyLedgers;
  final List<MoneyPaymentMethod> availablePaymentMethods;
  final bool paymentMethodLocked;
  final bool showPaidByOthers;

  @override
  State<_MoreFieldsPanel> createState() => _MoreFieldsPanelState();
}

class _MoreFieldsPanelState extends State<_MoreFieldsPanel> {
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial.description);
  late final TextEditingController _customPaymentNameController =
      TextEditingController(text: widget.initial.customPaymentName);
  late String? _ledgerId = widget.initial.ledgerId;
  late MoneyPaymentMethod _paymentMethod = widget.initial.paymentMethod;
  late bool _paidByOthers = widget.initial.paidByOthers;
  late MoneyTransactionStatus _status = widget.initial.status;

  @override
  void dispose() {
    _descriptionController.dispose();
    _customPaymentNameController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(
      _MoreFieldsResult(
        description: _descriptionController.text.trim(),
        ledgerId: _ledgerId,
        paymentMethod: _paymentMethod,
        customPaymentName: _customPaymentNameController.text.trim(),
        paidByOthers: _paidByOthers,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          spacing.cardPadding,
          0,
          spacing.cardPadding,
          spacing.cardPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '更多字段',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _descriptionController,
              labelText: '名称',
              hintText: '可选，如：和老王吃饭',
              prefixIcon: const Icon(Icons.title_rounded),
              textInputAction: TextInputAction.next,
            ),
            if (widget.familyLedgers.isNotEmpty) ...[
              const SizedBox(height: 12),
              FormDropdown<String?>(
                initialSelection: _ledgerId,
                label: '家庭账本',
                leadingIcon: const Icon(Icons.menu_book_rounded),
                width: double.infinity,
                entries: [
                  const DropdownMenuEntry<String?>(
                    value: null,
                    label: '不加入家庭账本',
                  ),
                  for (final ledger in widget.familyLedgers)
                    DropdownMenuEntry<String?>(
                      value: ledger.id,
                      label: ledger.name,
                    ),
                ],
                onSelected: (value) => setState(() => _ledgerId = value),
              ),
            ],
            const SizedBox(height: 12),
            FormDropdown<MoneyPaymentMethod>(
              initialSelection: _paymentMethod,
              label: '支付方式',
              leadingIcon: const Icon(Icons.credit_card_rounded),
              enabled: !widget.paymentMethodLocked,
              entries: widget.availablePaymentMethods
                  .map(
                    (method) =>
                        DropdownMenuEntry(value: method, label: method.label),
                  )
                  .toList(),
              onSelected: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _paymentMethod = value);
              },
            ),
            if (_paymentMethod == MoneyPaymentMethod.other) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: _customPaymentNameController,
                labelText: '支付方式名称',
                hintText: '如：美团月付、抖音月付',
                prefixIcon: const Icon(Icons.payment_rounded),
              ),
            ],
            if (widget.showPaidByOthers) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('他人代付'),
                subtitle: const Text('记入系统内部账户，由对方承担'),
                value: _paidByOthers,
                onChanged: (value) => setState(() => _paidByOthers = value),
              ),
            ],
            const SizedBox(height: 12),
            AppSlidingSegmentedControl<MoneyTransactionStatus>(
              minSegmentWidth: 80,
              value: _status,
              onChanged: (value) => setState(() => _status = value),
              segments: const [
                AppSlidingSegment(
                  value: MoneyTransactionStatus.completed,
                  label: '已完成',
                ),
                AppSlidingSegment(
                  value: MoneyTransactionStatus.pending,
                  label: '待处理',
                ),
              ],
            ),
            if (_status == MoneyTransactionStatus.pending)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '待处理：暂不占用账户余额，也不计入统计',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}
