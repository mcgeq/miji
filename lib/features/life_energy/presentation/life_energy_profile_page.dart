import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/router/app_routes.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/life_energy_group_card.dart';
import 'package:miji/features/life_energy/presentation/life_energy_bonus_section.dart';
import 'package:miji/features/life_energy/presentation/life_energy_payroll_fields.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 收入与工时：12 个字段分三组，对应空态里那三步（收入 → 时间 → 开销）。
///
/// 页面名不叫「工作档案」：档案是**我们**存的东西，用户点进来是为了填「我赚多少、
/// 干多久」这两件事。标题直接说这两件事，比一个抽象名词省一句解释。
///
/// 为什么是一整页而不是弹层：12 个字段塞进底部弹层，键盘一弹就只剩 300px，
/// 用户得在「看不见自己在填哪一组」的状态下滚动。
///
/// 表单里**没有税率、社保**这类字段：输入项统一是到手，默认周期是全年。
/// 个税走累计预扣，每月到手先高后低、年终奖还不在任何一个月里 —— 只有
/// 「全年 ÷ 12」是稳定口径，且这个数一年只需要改一次。
class LifeEnergyProfilePage extends ConsumerWidget {
  const LifeEnergyProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentWorkProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('收入与工时')),
      body: profile.when(
        loading: () => const AppSkeletonList(rows: 6),
        error: (error, stackTrace) => AppErrorState(
          title: '读取收入与工时失败',
          onRetry: () => ref.invalidate(currentWorkProfileProvider),
        ),
        data: (value) => _ProfileForm(initial: value),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});

  final WorkProfile? initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _employer;
  late final TextEditingController _pay;
  late final TextEditingController _days;
  late final TextEditingController _hoursPerDay;
  late final TextEditingController _commuteMinutes;
  late final TextEditingController _regularOvertimeHours;
  late final TextEditingController _transport;
  late final TextEditingController _meal;
  late final TextEditingController _clothing;
  late final TextEditingController _childcare;
  late final TextEditingController _decompress;
  late final TextEditingController _other;

  late LifeEnergyPayCycle _payCycle;
  late String _currencyCode;

  /// 收入口径。**不换算**：net 与 gross 各存一份自己那个数，切换时把输入框
  /// 换成对应那份。反推税前是多解的（社保基数封顶后，税前差 1,000 到手可能
  /// 只差 600），拿一个换算结果糊过去，用户会对不上工资条。
  late LifeEnergyCompensationMode _mode;
  late SocialInsuranceConfig _payroll;
  int _netMinor = 0;
  int _grossMinor = 0;

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initial;
    final userId = profile?.userId ?? '';
    final blank = profile ?? WorkProfile.blank(userId);
    _payCycle = blank.payCycle;
    _currencyCode =
        profile?.currencyCode ??
        ref.read(currentUserCurrentLedgerValueProvider)?.baseCurrencyCode ??
        'CNY';
    _mode = profile?.compensationMode ?? LifeEnergyCompensationMode.net;
    _payroll = profile?.payroll ?? SocialInsuranceConfig.defaults;
    _netMinor = profile?.payAmountMinor ?? 0;
    _grossMinor = profile?.grossMonthlyMinor ?? 0;
    _employer = TextEditingController(text: profile?.employer ?? '');
    _pay = _amountController(
      _mode == LifeEnergyCompensationMode.gross ? _grossMinor : _netMinor,
    );
    _days = _numberController(blank.workDaysPerMonth);
    _hoursPerDay = _numberController(
      blank.workMinutesPerDay / 60,
      decimal: true,
    );
    _commuteMinutes = _numberController(blank.commuteMinutesPerDay);
    _regularOvertimeHours = _numberController(
      blank.overtimeMinutesPerMonth / 60,
      decimal: true,
    );
    _transport = _amountController(blank.costTransportMinor);
    _meal = _amountController(blank.costMealMinor);
    _clothing = _amountController(blank.costClothingMinor);
    _childcare = _amountController(blank.costChildcareMinor);
    _decompress = _amountController(blank.costDecompressMinor);
    _other = _amountController(blank.costOtherMinor);
  }

  TextEditingController _amountController(int minor) {
    return TextEditingController(
      text: minor == 0 ? '' : (minor / 100).toStringAsFixed(2),
    );
  }

  TextEditingController _numberController(num value, {bool decimal = false}) {
    if (value == 0) {
      return TextEditingController();
    }
    return TextEditingController(
      text: decimal
          ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
          : value.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _employer,
      _pay,
      _days,
      _hoursPerDay,
      _commuteMinutes,
      _regularOvertimeHours,
      _transport,
      _meal,
      _clothing,
      _childcare,
      _decompress,
      _other,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _money(TextEditingController controller) {
    try {
      final value = parseMoneyAmountToMinor(controller.text);
      return value < 0 ? 0 : value;
    } on MoneyAmountParseException {
      return 0;
    }
  }

  int _minutes(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim()) ?? 0;
    final minutes = (value * 60).round();
    return minutes < 0 ? 0 : minutes;
  }

  int _count(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim()) ?? 0;
    return value < 0 ? 0 : value;
  }

  /// 「按月」一键换「全年」：×12 并把周期切过去。
  ///
  /// 为什么给这个按钮：用户填月大多是因为只记得上个月的数，不是想要月口径。
  /// 让他手算 ×12 再重新输入，等于把口径纠正的成本转嫁给他；而这一步恰好是
  /// 本功能最该替用户做的（×12 不会错，个税累计才是用户算不了的部分）。
  ///
  /// 换算不精确的地方由文案兜住：这里只是「按月 × 12」，不等于真实全年
  /// （累计预扣下 12 月的税比 1 月重），所以按钮叫「换成全年」而不是「算准确」。
  void _annualizeFromMonthly() {
    final monthly = _money(_pay);
    setState(() {
      _payCycle = LifeEnergyPayCycle.year;
      if (monthly > 0) {
        _pay.text = (monthly * 12 / 100).toStringAsFixed(2);
      }
    });
  }

  /// 税前口径下「这个月到手」的预览。
  ///
  /// 用 [WorkProfile.payrollPreview] 而不是历史段：编辑档案时改的是**这份档案**，
  /// 用户要看的是「我把税前改成 25,000，这个月能拿到多少」。历史段的差异在
  /// 面板和薪资历史页那边接管，两边分工不重叠。
  /// **以输入框里的数为准**，不读 `_grossMinor`：那个字段只是「切走时记住的
  /// 上一份值」，敲键盘时不会更新 —— 拿它算预览，用户填完税前看到的是 0，
  /// 按保存还会被告知「先填税前月薪」。
  int get _previewNet {
    final grossMinor = _money(_pay);
    if (_mode != LifeEnergyCompensationMode.gross || grossMinor <= 0) {
      return 0;
    }
    final now = ref.read(lifeEnergyClockProvider)();
    final draft = WorkProfile(
      userId: '',
      payAmountMinor: 0,
      compensationMode: _mode,
      grossMonthlyMinor: grossMinor,
      payroll: _payroll,
      payCycle: LifeEnergyPayCycle.month,
      currencyCode: _currencyCode,
    );
    final net = draft.payrollPreview().month(now.month)?.netMinor ?? 0;
    // 基数被手填得比税前还大时，算出来会是负数（扣得比拿的多）。负的到手
    // 会让时薪变成负数，一路传到清单上 —— 这里夹到 0，跟
    // [WorkProfile.withResolvedNet] 同一条口径。
    return net < 0 ? 0 : net;
  }

  /// 切换口径：**不换算**另一个数，只把输入框换成对应那份。
  ///
  /// 同时保留用户已经填过的值，来回切不丢 —— 否则试一下「税前推算」再切回来，
  /// 之前填的到手就没了，用户下次就不敢点了。
  void _switchMode(LifeEnergyCompensationMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() {
      if (_mode == LifeEnergyCompensationMode.gross) {
        _grossMinor = _money(_pay);
      } else {
        _netMinor = _money(_pay);
      }
      _mode = mode;
      final next = mode == LifeEnergyCompensationMode.gross
          ? _grossMinor
          : _netMinor;
      _pay.text = next == 0 ? '' : (next / 100).toStringAsFixed(2);
    });
  }

  WorkProfile get _draft {
    final base = widget.initial ?? WorkProfile.blank('');
    final employer = _employer.text.trim();
    final gross = _mode == LifeEnergyCompensationMode.gross;
    return base.copyWith(
      employer: employer.isEmpty ? null : employer,
      clearEmployer: employer.isEmpty,
      // 档案页的六项才是工作开销的真相。段上的「合计覆盖」只属于历史快照，
      // 一旦进了这一页就丢掉它 —— 否则用户改六项、时薪却纹丝不动。
      clearWorkCostOverride: true,
      compensationMode: _mode,
      grossMonthlyMinor: gross ? _money(_pay) : 0,
      payroll: _payroll,
      // 税前口径下这个字段是**算出来的**当月到手：写回去之后时薪那套算式
      // （月净收入 ÷ 月工时）一行都不用改。
      payAmountMinor: gross ? _previewNet : _money(_pay),
      payCycle: gross ? LifeEnergyPayCycle.month : _payCycle,
      currencyCode: _currencyCode,
      workDaysPerMonth: _count(_days),
      workMinutesPerDay: _minutes(_hoursPerDay),
      commuteMinutesPerDay: _count(_commuteMinutes),
      overtimeMinutesPerMonth: _minutes(_regularOvertimeHours),
      costTransportMinor: _money(_transport),
      costMealMinor: _money(_meal),
      costClothingMinor: _money(_clothing),
      costChildcareMinor: _money(_childcare),
      costDecompressMinor: _money(_decompress),
      costOtherMinor: _money(_other),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;
    final draft = _draft;
    final gross = draft.isGrossMode;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              spacing.pageCompact,
              8,
              spacing.pageCompact,
              24,
            ),
            children: [
              LifeEnergyGroupCard(
                title: gross ? '收入 · 填税前，到手自动算' : '收入',
                hint: gross
                    ? '填工资条上的「应发」。到手由五险一金、专项附加扣除和'
                          '累计预扣算出来，一年 12 个月都不相同。'
                    : '填全年到手。个税走累计预扣 —— 年初扣得少、年末扣得多，'
                          '同一个月的到手在一年里能差几千（收入越高差越多），'
                          '年终奖还落在任何一个月之外。填全年就都不用管了。',
                children: [
                  _ModeSwitch(mode: _mode, onChanged: _switchMode),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _employer,
                    labelText: '工作单位',
                    hintText: '选填，例如「云图科技」',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  AppAmountField(
                    // 测试要精确定位金额框：它上面还有「工作单位」文本框，
                    // 按 TextField 序号取会随字段增删而错位。
                    key: const ValueKey('lifeEnergyPayAmount'),
                    controller: _pay,
                    labelText: gross ? '税前月薪' : _payCycle.amountLabel,
                    currencyCode: _currencyCode,
                    prominent: true,
                    helperText: gross ? '合同上写的那个数，也叫「应发工资」' : null,
                    onChanged: (_) => setState(() {
                      // 镜像跟着输入走：否则「切到另一个口径再切回来」会把它
                      // 还原成上次切换时的旧值，刚填的数当场消失。
                      if (gross) {
                        _grossMinor = _money(_pay);
                      } else {
                        _netMinor = _money(_pay);
                      }
                    }),
                  ),
                  if (gross) ...[
                    const SizedBox(height: 8),
                    _GrossToNetHint(
                      netMinor: _previewNet,
                      currencyCode: _currencyCode,
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    SegmentedButton<LifeEnergyPayCycle>(
                      segments: [
                        for (final cycle in LifeEnergyPayCycle.values)
                          ButtonSegment<LifeEnergyPayCycle>(
                            value: cycle,
                            label: Text(cycle.label),
                          ),
                      ],
                      selected: {_payCycle},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _payCycle = selection.first);
                      },
                    ),
                    if (_payCycle == LifeEnergyPayCycle.month) ...[
                      const SizedBox(height: 10),
                      _MonthlyCycleNotice(onAnnualize: _annualizeFromMonthly),
                    ],
                  ],
                  const SizedBox(height: 12),
                  gross ? const _HowToFindGross() : const _HowToFindIncome(),
                ],
              ),
              if (gross) ...[
                const SizedBox(height: 16),
                PayrollFieldsSection(
                  config: _payroll,
                  grossMonthlyMinor: _money(_pay),
                  currencyCode: _currencyCode,
                  onConfigChanged: (config) =>
                      setState(() => _payroll = config),
                ),
                const SizedBox(height: 16),
                LifeEnergyBonusSection(currencyCode: _currencyCode),
              ],
              const SizedBox(height: 16),
              LifeEnergyGroupCard(
                title: '时间',
                hint:
                    '「通勤」这一项常被漏掉，但正是它把「一天 8 小时」变成 '
                    '${formatLifeEnergyDayHours(draft.dailyHours)} 小时。',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _days,
                          labelText: '每月工作天数',
                          hintText: '22',
                          suffixText: '天',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: _hoursPerDay,
                          labelText: '每天工作',
                          hintText: '8',
                          suffixText: '小时',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _commuteMinutes,
                          labelText: '每天往返通勤',
                          hintText: '70',
                          suffixText: '分钟',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: _regularOvertimeHours,
                          labelText: '常规加班',
                          hintText: '每月小时',
                          suffixText: '小时',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '常规加班指典型月份的加班（比如长期每周六上班）。'
                    '临时加班不要填这里 —— 去面板上「记录加班」，那里的波动只影响本月视图。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LifeEnergyGroupCard(
                title: '为了上班多花的钱',
                hint: '只填「因为上班才发生」的部分。工作餐差额 = 比在家吃多花的那几块。',
                children: [
                  AppAmountField(
                    controller: _transport,
                    labelText: '交通',
                    currencyCode: _currencyCode,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  AppAmountField(
                    controller: _meal,
                    labelText: '工作餐差额',
                    currencyCode: _currencyCode,
                    helperText: '比在家吃多花的部分，不是整份外卖的钱',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  AppAmountField(
                    controller: _clothing,
                    labelText: '置装',
                    currencyCode: _currencyCode,
                    helperText: '为了上班才买的衣服、鞋子',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  AppAmountField(
                    controller: _childcare,
                    labelText: '托儿',
                    currencyCode: _currencyCode,
                    helperText: '因为上班才产生的照护费用',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  AppAmountField(
                    controller: _decompress,
                    labelText: '解压消费',
                    currencyCode: _currencyCode,
                    helperText: '因为上班太累才花的（外卖、按摩、周末逃离）',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  AppAmountField(
                    controller: _other,
                    labelText: '其他',
                    currencyCode: _currencyCode,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              if (gross) ...[
                const SizedBox(height: 16),
                _PayrollEntry(
                  onTap: () =>
                      context.push(AppRoutes.bookkeepingLifeEnergyPayroll),
                ),
              ],
              if (ref.watch(salaryHistoryProvider)?.hasHistory ?? false) ...[
                const SizedBox(height: 16),
                _SalaryHistoryEntry(
                  onTap: () =>
                      context.push(AppRoutes.bookkeepingLifeEnergyRaises),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        _StickyWageBar(
          profile: draft,
          month: ref.watch(lifeEnergyClockProvider)().month,
          currencyCode: _currencyCode,
          saving: _saving,
          onSave: () => _save(draft),
        ),
      ],
    );
  }

  Future<void> _save(WorkProfile draft) async {
    final gross = draft.isGrossMode;
    // 校验的是**金额框里那个数**，不是算出来的到手：到手算不出来可能是参数
    // 或月份的问题，那时报「先填税前月薪」会把用户指向一个已经填好的字段。
    if (_money(_pay) <= 0) {
      setState(() => _error = gross ? '先填税前月薪' : '先填${_payCycle.amountLabel}');
      return;
    }
    if (draft.workDaysPerMonth <= 0 || draft.workMinutesPerDay <= 0) {
      setState(() => _error = '工作天数和每天工作小时都要大于 0');
      return;
    }
    final userId = ref.read(currentWorkProfileProvider).asData?.value?.userId;
    final session = ref.read(authSessionControllerProvider).userId;
    final resolvedUserId = userId ?? session;
    if (resolvedUserId == null) {
      setState(() => _error = '登录状态异常，请重新进入');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(lifeEnergyActionsProvider)
          .saveProfile(
            WorkProfile(
              userId: resolvedUserId,
              employer: draft.employer,
              payAmountMinor: draft.payAmountMinor,
              payCycle: draft.payCycle,
              currencyCode: _currencyCode,
              compensationMode: draft.compensationMode,
              grossMonthlyMinor: draft.grossMonthlyMinor,
              payroll: draft.payroll,
              workDaysPerMonth: draft.workDaysPerMonth,
              workMinutesPerDay: draft.workMinutesPerDay,
              commuteMinutesPerDay: draft.commuteMinutesPerDay,
              overtimeMinutesPerMonth: draft.overtimeMinutesPerMonth,
              costTransportMinor: draft.costTransportMinor,
              costMealMinor: draft.costMealMinor,
              costClothingMinor: draft.costClothingMinor,
              costChildcareMinor: draft.costChildcareMinor,
              costDecompressMinor: draft.costDecompressMinor,
              costOtherMinor: draft.costOtherMinor,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }
}

/// 吸底条：改任一字段就重算真实时薪。
///
/// 这是表单的反馈回路 —— 比保存后回面板看结果强得多：用户当场就能看见
/// 「通勤多填 30 分钟，时薪掉了 2 块」。
class _StickyWageBar extends StatelessWidget {
  const _StickyWageBar({
    required this.profile,
    required this.month,
    required this.currencyCode,
    required this.saving,
    required this.onSave,
  });

  final WorkProfile profile;
  final int month;
  final String currencyCode;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final configured = profile.isConfigured;
    final gross = profile.isGrossMode;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // 税前口径下先给「这个月到手」：它是用户能在工资条上核对
                      // 的那个数；时薪是派生的，放在同一行的后半句里。
                      gross
                          ? '$month 月到手 · 时薪 '
                                '${configured ? formatLifeEnergyWage(profile.hourlyWageMinor, currencyCode) : '—'}'
                          : '真实时薪',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      configured
                          ? gross
                                ? formatMoneyMinorWithDigits(
                                    profile.payAmountMinor,
                                    currencyCode,
                                    0,
                                  )
                                : formatLifeEnergyWage(
                                    profile.hourlyWageMinor,
                                    currencyCode,
                                  )
                          : '—',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    // 1、2 月的时薪会比年末高（税还没爬满档）。挂一行全年平均，
                    // 不让用户把预扣节奏当成涨薪 —— 也不让他以为下个月还会涨。
                    if (configured && gross) ...[
                      const SizedBox(height: 2),
                      Text(
                        '全年平均 ${formatLifeEnergyWage(profile.averageHourlyWageMinor, currencyCode)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                    // 填全年时回显月均：用户填 144,000 之后需要的第一个确认
                    // 就是「这确实等于每月 12,000」，否则会怀疑自己填错了量级。
                    if (configured &&
                        !gross &&
                        profile.payCycle == LifeEnergyPayCycle.year) ...[
                      const SizedBox(height: 2),
                      Text(
                        '月均到手 ${formatMoneyMinorWithDigits(profile.monthlyGrossMinor.round(), currencyCode, 0)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: Text(saving ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 选了「按月」时的提醒。
///
/// 不禁止，只说明往哪偏 —— 有人确实只有月度数字（刚入职、刚涨薪）。但如果
/// 不提，用户会拿 1 月的到手当基准，把时薪算高 3~8%，而他永远不会知道。
class _MonthlyCycleNotice extends StatelessWidget {
  const _MonthlyCycleNotice({required this.onAnnualize});

  final VoidCallback onAnnualize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ink = colorScheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        // 深色档的 tertiaryContainer 和卡片面几乎同色，只靠底色分不出这是一块
        // 提示 —— 补一道描边，两档都能一眼看出边界。
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '按月填会偏',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '1 月的到手还没扣够全年的税，算出的时薪会偏高；12 月的又偏低。'
            '手头只有月度数字的话，填最近 12 个月的平均值。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onAnnualize,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('换成全年（×12）'),
            style: TextButton.styleFrom(
              foregroundColor: ink,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「全年到手」从哪拿。默认收起：四条路径对多数人是噪音，但它必须存在 ——
/// 不写清获取路径，用户会去翻半天工资条然后随便填一个数。
class _HowToFindIncome extends StatefulWidget {
  const _HowToFindIncome();

  @override
  State<_HowToFindIncome> createState() => _HowToFindIncomeState();
}

class _HowToFindIncomeState extends State<_HowToFindIncome> {
  static const _rows = [
    '个税 App →「收入纳税明细查询」：全年收入合计减去已缴税额',
    '或者把工资卡这一年的入账加起来',
    '年终奖、季度奖、补贴都算 —— 只要是到手的钱',
    '只看到手：社保公积金已经扣掉了，不用再加回来',
    '工作不满一年：切到「按月」，填最近几个月的平均',
  ];

  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '这个数从哪拿',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '· ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// 「计算方式」那一行。
///
/// 放在收入组的第一行、而不是藏进设置：用户随时要能看到自己在哪种口径里，
/// 也能一眼换回去 —— 这比任何免责声明都让人放心。
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final LifeEnergyCompensationMode mode;
  final ValueChanged<LifeEnergyCompensationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '计算方式',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        Text(
          '随时可以换回「直接填到手」，两个数各自留着，不会互相换算',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<LifeEnergyCompensationMode>(
          segments: [
            for (final value in LifeEnergyCompensationMode.values)
              ButtonSegment<LifeEnergyCompensationMode>(
                value: value,
                label: Text(value.label),
              ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

/// 税前口径下，金额框下面那行「按当前参数，10 月到手 ¥14,650」。
///
/// 必须紧挨着输入框：这是填税前的人唯一能核对的东西 —— 他不知道自己应交多少
/// 税，但他知道上个月卡里到了多少钱。数字不对，他就知道参数要改。
class _GrossToNetHint extends StatelessWidget {
  const _GrossToNetHint({required this.netMinor, required this.currencyCode});

  final int netMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (netMinor <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      '按当前参数，这个月到手 ${formatMoneyMinorWithDigits(netMinor, currencyCode, 0)}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0,
        height: 1.35,
      ),
    );
  }
}

/// 税前模式下「这个数从哪拿」。
class _HowToFindGross extends StatefulWidget {
  const _HowToFindGross();

  @override
  State<_HowToFindGross> createState() => _HowToFindGrossState();
}

class _HowToFindGrossState extends State<_HowToFindGross> {
  static const _rows = [
    '工资条 / 个税 App 上的「应发合计」，不是「实发」',
    '合同上写的是年薪：÷12 填进来，年终奖填到下面那栏',
    '年终奖**单独计税**，不摊进月薪 —— 摊进去会算出完全不同的税',
    '有加班费、补贴的月份不用管：这里要的是固定的那部分月薪',
  ];

  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '税前月薪从哪拿',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '· ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.replaceAll('**', ''),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// 通往「到手明细」的入口。
///
/// 只有想核对的人会点 —— 所以放在最底部、字号最小，不打扰只想填完就走的人。
class _PayrollEntry extends StatelessWidget {
  const _PayrollEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '看看是怎么算的',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '12 个月的个税、一年的五险一金',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 档案页里通往「薪资历史」的入口。
///
/// **只有超过一段时才出现**：不涨薪也不跳槽的人不该看到一个只有一行的列表，
/// 那会让人以为漏填了什么。
class _SalaryHistoryEntry extends StatelessWidget {
  const _SalaryHistoryEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '薪资历史',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '涨薪与跳槽，每段各用当时的通勤和开销',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
