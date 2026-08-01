import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/split_rule_manager_dialog.dart';

class TransactionSplitDialog extends ConsumerStatefulWidget {
  const TransactionSplitDialog({
    super.key,
    required this.ledgerId,
    required this.amountMinor,
    required this.currencyCode,
    this.initialMembers = const <MoneyMemberEntity>[],
    this.initialRecord,
    this.title = '设置分摊',
    this.confirmLabel = '确定',
  });

  final String ledgerId;
  final int amountMinor;
  final String currencyCode;
  final List<MoneyMemberEntity> initialMembers;
  final MoneySplitRecordEntity? initialRecord;
  final String title;
  final String confirmLabel;

  @override
  ConsumerState<TransactionSplitDialog> createState() =>
      _TransactionSplitDialogState();
}

class _TransactionSplitDialogState
    extends ConsumerState<TransactionSplitDialog> {
  final Map<String, TextEditingController> _valueControllers =
      <String, TextEditingController>{};
  final TextEditingController _notesController = TextEditingController();
  final Set<String> _selectedMemberIds = <String>{};
  late List<MoneyMemberEntity> _members;
  MoneySplitType _splitType = MoneySplitType.equal;
  String? _payerMemberId;
  String? _errorText;
  int _ruleApplyVersion = 0;
  bool _didInitializeMembers = false;
  bool _isAddingMember = false;

  @override
  void initState() {
    super.initState();
    _members = List<MoneyMemberEntity>.of(widget.initialMembers);
    _ensureMemberState(_members);
  }

  @override
  void dispose() {
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final members = _members.isEmpty
        ? ref.watch(currentUserMoneyLedgerMembersProvider(widget.ledgerId))
        : AsyncValue<List<MoneyMemberEntity>>.data(_members);
    final splitRules = ref.watch(
      currentUserSplitRulesProvider(widget.ledgerId),
    );
    final activeRules = splitRules.maybeWhen(
      data: (items) => items.where((rule) => rule.isActive).toList(),
      orElse: () => const <MoneySplitRuleEntity>[],
    );

    return AppDialogScaffold(
      title: widget.title,
      maxWidth: 520,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: members.when(
        data: (value) {
          if (_members.isEmpty) {
            _members = List<MoneyMemberEntity>.of(value);
            _ensureMemberState(_members);
          }
          return AppFormColumn(
            children: [
              _TransactionAmountHeader(
                amountMinor: widget.amountMinor,
                currencyCode: widget.currencyCode,
              ),
              AppSlidingSegmentedControl<MoneySplitType>(
                minSegmentWidth: 86,
                value: _splitType,
                segments: MoneySplitType.values
                    .map(
                      (type) => AppSlidingSegment<MoneySplitType>(
                        value: type,
                        label: type.label,
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _splitType = value);
                },
              ),
              if (activeRules.isNotEmpty)
                FormDropdown<String>(
                  key: ValueKey(
                    'split-rule-${activeRules.length}-$_ruleApplyVersion',
                  ),
                  initialSelection: null,
                  label: '应用模板',
                  leadingIcon: const Icon(Icons.playlist_add_check_rounded),
                  width: double.infinity,
                  enableFilter: true,
                  entries: activeRules
                      .map(
                        (rule) => DropdownMenuEntry<String>(
                          value: rule.id,
                          label: rule.name,
                        ),
                      )
                      .toList(),
                  onSelected: (ruleId) {
                    MoneySplitRuleEntity? rule;
                    for (final item in activeRules) {
                      if (item.id == ruleId) {
                        rule = item;
                        break;
                      }
                    }
                    if (rule != null) {
                      _applyRule(rule);
                    }
                  },
                ),
              FormDropdown<String>(
                initialSelection: _payerMemberId,
                label: '付款人',
                leadingIcon: const Icon(Icons.person_pin_circle_outlined),
                width: double.infinity,
                enableFilter: true,
                entries: value
                    .map(
                      (member) => DropdownMenuEntry<String>(
                        value: member.id,
                        label: member.name,
                      ),
                    )
                    .toList(),
                onSelected: (memberId) {
                  setState(() {
                    _payerMemberId = memberId;
                    if (memberId != null) {
                      _selectedMemberIds.add(memberId);
                    }
                  });
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AppIconActionButton(
                  tooltip: '添加成员',
                  onPressed: _isAddingMember ? null : _addMember,
                  icon: Icons.person_add_alt_1_rounded,
                  variant: AppIconActionVariant.outlined,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AppIconActionButton(
                  tooltip: '管理模板',
                  onPressed: _openRuleManager,
                  icon: Icons.tune_rounded,
                  variant: AppIconActionVariant.outlined,
                ),
              ),
              Text(
                '参与成员',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (value.length < 2)
                Text(
                  '至少需要两个成员。可以先添加一个家人或朋友。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ...value.map(_buildMemberTile),
              AppTextField(
                controller: _notesController,
                labelText: '备注',
                maxLines: 2,
              ),
              if (_errorText != null)
                Text(
                  _errorText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => const Text('成员读取失败'),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: widget.confirmLabel,
      ),
    );
  }

  Widget _buildMemberTile(MoneyMemberEntity member) {
    final selected = _selectedMemberIds.contains(member.id);
    final controller = _controllerFor(member.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppSurface(
        tone: AppSurfaceTone.subtle,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedMemberIds.add(member.id);
                  } else {
                    _selectedMemberIds.remove(member.id);
                  }
                });
              },
            ),
            Expanded(
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (_splitType != MoneySplitType.equal)
              SizedBox(
                width: _splitType == MoneySplitType.fixedAmount ? 156 : 132,
                child: _splitType == MoneySplitType.fixedAmount
                    ? AppAmountField(
                        controller: controller,
                        enabled: selected,
                        labelText: '金额',
                        currencyCode: widget.currencyCode,
                      )
                    : AppTextField(
                        controller: controller,
                        enabled: selected,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        labelText: '比例%',
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _ensureMemberState(List<MoneyMemberEntity> members) {
    for (final member in members) {
      _controllerFor(member.id);
    }
    if (_didInitializeMembers || members.isEmpty) {
      return;
    }
    _didInitializeMembers = true;
    final initialRecord = widget.initialRecord;
    if (initialRecord != null) {
      _splitType = initialRecord.splitType;
      _payerMemberId = initialRecord.payerMemberId;
      _selectedMemberIds
        ..clear()
        ..addAll(initialRecord.details.map((detail) => detail.memberId));
      for (final detail in initialRecord.details) {
        final controller = _controllerFor(detail.memberId);
        controller.text = switch (initialRecord.splitType) {
          MoneySplitType.fixedAmount =>
            detail.amountMinor == 0
                ? ''
                : (detail.amountMinor / 100).toStringAsFixed(2),
          MoneySplitType.percentage =>
            detail.percentageBasisPoints == null
                ? ''
                : (detail.percentageBasisPoints! / 100).toStringAsFixed(2),
          MoneySplitType.equal => '',
        };
      }
      _notesController.text = initialRecord.notes ?? '';
      return;
    }
    _payerMemberId = members.first.id;
    _selectedMemberIds.addAll(members.map((member) => member.id));
  }

  TextEditingController _controllerFor(String memberId) {
    return _valueControllers.putIfAbsent(memberId, TextEditingController.new);
  }

  Future<void> _addMember() async {
    final draft = await showAppResponsiveDialog<MoneyMemberDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const _AddMemberDialog(),
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _isAddingMember = true);
    try {
      final member = await ref
          .read(currentUserMoneySplitActionsProvider)
          .createMember(draft, ledgerId: widget.ledgerId);
      if (!mounted) return;
      setState(() {
        _members = <MoneyMemberEntity>[..._members, member];
        _selectedMemberIds.add(member.id);
        _payerMemberId ??= member.id;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '成员添加失败');
    } finally {
      if (mounted) {
        setState(() => _isAddingMember = false);
      }
    }
  }

  Future<void> _openRuleManager() async {
    await showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => SplitRuleManagerDialog(ledgerId: widget.ledgerId),
    );
  }

  void _applyRule(MoneySplitRuleEntity rule) {
    try {
      final decoded = jsonDecode(rule.ruleConfigJson);
      if (decoded is! Map) {
        throw const FormatException();
      }
      final ruleConfig = Map<Object?, Object?>.from(decoded);
      final participantMaps = _ruleParticipantMaps(ruleConfig);
      final memberIds = _memberIdsFromRule(participantMaps);
      if (memberIds.length < 2) {
        throw const FormatException();
      }
      final splitType = _splitTypeFromRule(rule.ruleType, participantMaps);
      final payerMemberId = _payerMemberIdFromRule(ruleConfig, memberIds);
      final weightTotal = _weightTotal(participantMaps);

      setState(() {
        _splitType = splitType;
        _selectedMemberIds
          ..clear()
          ..addAll(memberIds);
        _payerMemberId = payerMemberId;
        _errorText = null;
        _ruleApplyVersion++;
        for (final controller in _valueControllers.values) {
          controller.clear();
        }
        for (final participant in participantMaps) {
          final memberId = _memberIdFromRuleParticipant(participant);
          if (memberId == null || !memberIds.contains(memberId)) {
            continue;
          }
          final controller = _controllerFor(memberId);
          controller.text = switch (splitType) {
            MoneySplitType.fixedAmount => _fixedAmountTextFromRuleParticipant(
              participant,
            ),
            MoneySplitType.percentage => _percentageTextFromRuleParticipant(
              participant,
              weightTotal,
            ),
            MoneySplitType.equal => '',
          };
        }
      });
    } catch (_) {
      setState(() => _errorText = '模板配置无法应用');
    }
  }

  List<Map<Object?, Object?>> _ruleParticipantMaps(Map<Object?, Object?> json) {
    final rawParticipants = json['participants'];
    if (rawParticipants is! Iterable) {
      return const <Map<Object?, Object?>>[];
    }
    return rawParticipants
        .whereType<Map>()
        .map((item) => Map<Object?, Object?>.from(item))
        .toList(growable: false);
  }

  List<String> _memberIdsFromRule(List<Map<Object?, Object?>> participants) {
    final availableIds = _members.map((member) => member.id).toSet();
    if (participants.isEmpty) {
      return _members.map((member) => member.id).toList(growable: false);
    }

    final memberIds = <String>[];
    for (final participant in participants) {
      final memberId = _memberIdFromRuleParticipant(participant);
      if (memberId == null || !availableIds.contains(memberId)) {
        continue;
      }
      if (!memberIds.contains(memberId)) {
        memberIds.add(memberId);
      }
    }
    return memberIds;
  }

  String? _memberIdFromRuleParticipant(Map<Object?, Object?> participant) {
    return _stringFromMap(participant, const [
      'memberId',
      'memberSerialNum',
      'member_id',
    ]);
  }

  String _payerMemberIdFromRule(
    Map<Object?, Object?> json,
    List<String> memberIds,
  ) {
    final configured = _stringFromMap(json, const [
      'payerMemberId',
      'payerMemberSerialNum',
      'payer_member_id',
    ]);
    if (configured != null && memberIds.contains(configured)) {
      return configured;
    }
    final current = _payerMemberId;
    if (current != null && memberIds.contains(current)) {
      return current;
    }
    return memberIds.first;
  }

  MoneySplitType _splitTypeFromRule(
    MoneySplitRuleType ruleType,
    List<Map<Object?, Object?>> participants,
  ) {
    return switch (ruleType) {
      MoneySplitRuleType.equal => MoneySplitType.equal,
      MoneySplitRuleType.fixedAmount => MoneySplitType.fixedAmount,
      MoneySplitRuleType.percentage ||
      MoneySplitRuleType.weighted => MoneySplitType.percentage,
      MoneySplitRuleType.custom =>
        participants.any(_hasFixedAmountConfig)
            ? MoneySplitType.fixedAmount
            : participants.any(_hasPercentageConfig)
            ? MoneySplitType.percentage
            : MoneySplitType.equal,
    };
  }

  bool _hasFixedAmountConfig(Map<Object?, Object?> participant) {
    return _intFromMap(participant, const [
              'amountMinor',
              'fixedAmountMinor',
              'amount_minor',
            ]) !=
            null ||
        _numFromMap(participant, const ['fixedAmount', 'amount']) != null ||
        _stringFromMap(participant, const ['fixedAmount', 'amount']) != null;
  }

  bool _hasPercentageConfig(Map<Object?, Object?> participant) {
    return _intFromMap(participant, const ['percentageBasisPoints']) != null ||
        _numFromMap(participant, const ['percentage', 'weight']) != null;
  }

  String _fixedAmountTextFromRuleParticipant(
    Map<Object?, Object?> participant,
  ) {
    final amountMinor = _intFromMap(participant, const [
      'amountMinor',
      'fixedAmountMinor',
      'amount_minor',
    ]);
    if (amountMinor != null) {
      return (amountMinor / 100).toStringAsFixed(2);
    }
    final amount = _numFromMap(participant, const ['fixedAmount', 'amount']);
    if (amount != null) {
      return amount.toStringAsFixed(2);
    }
    final amountText = _stringFromMap(participant, const [
      'fixedAmount',
      'amount',
    ]);
    if (amountText != null) {
      return (parseMoneyAmountToMinor(amountText) / 100).toStringAsFixed(2);
    }
    return '';
  }

  String _percentageTextFromRuleParticipant(
    Map<Object?, Object?> participant,
    double weightTotal,
  ) {
    final basisPoints = _intFromMap(participant, const [
      'percentageBasisPoints',
      'percentage_basis_points',
    ]);
    if (basisPoints != null) {
      return (basisPoints / 100).toStringAsFixed(2);
    }
    final percentage = _numFromMap(participant, const ['percentage']);
    if (percentage != null) {
      return percentage.toStringAsFixed(2);
    }
    final weight = _numFromMap(participant, const ['weight']);
    if (weight != null && weightTotal > 0) {
      return (weight / weightTotal * 100).toStringAsFixed(2);
    }
    return '';
  }

  double _weightTotal(List<Map<Object?, Object?>> participants) {
    var total = 0.0;
    for (final participant in participants) {
      total += _numFromMap(participant, const ['weight']) ?? 0;
    }
    return total;
  }

  String? _stringFromMap(Map<Object?, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _intFromMap(Map<Object?, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.round();
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  double? _numFromMap(Map<Object?, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  void _submit() {
    try {
      final payerMemberId = _payerMemberId;
      final selectedIds = _selectedMemberIds.toList();
      if (selectedIds.length < 2) {
        setState(() => _errorText = '请选择至少两个参与成员');
        return;
      }
      if (payerMemberId == null || !selectedIds.contains(payerMemberId)) {
        setState(() => _errorText = '付款人必须在参与成员中');
        return;
      }

      final participants = selectedIds.map((memberId) {
        final text = _controllerFor(memberId).text;
        return MoneySplitParticipantDraft(
          memberId: memberId,
          amountMinor: _splitType == MoneySplitType.fixedAmount
              ? parseMoneyAmountToMinor(text)
              : null,
          percentageBasisPoints: _splitType == MoneySplitType.percentage
              ? _parsePercentageBasisPoints(text)
              : null,
        );
      }).toList();

      Navigator.of(context).pop(
        MoneySplitConfigDraft(
          ledgerId: widget.ledgerId,
          splitType: _splitType,
          payerMemberId: payerMemberId,
          participants: participants,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );
    } on MoneyAmountParseException {
      setState(() => _errorText = '金额格式不正确');
    } on FormatException {
      setState(() => _errorText = '比例格式不正确');
    }
  }

  int _parsePercentageBasisPoints(String input) {
    final value = double.parse(input.trim());
    return (value * 100).round();
  }
}

class _TransactionAmountHeader extends StatelessWidget {
  const _TransactionAmountHeader({
    required this.amountMinor,
    required this.currencyCode,
  });

  final int amountMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.call_split_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '分摊金额 ${formatMoneyMinor(amountMinor, currencyCode)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _controller = TextEditingController();
  String _role = 'participant';
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '添加成员',
      maxWidth: 320,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: AppFormColumn(
        children: [
          AppTextField(
            controller: _controller,
            autofocus: true,
            labelText: '成员名称',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: _errorText,
            onSubmitted: (_) => _submit(),
          ),
          FormDropdown<String>(
            initialSelection: _role,
            label: '角色',
            leadingIcon: const Icon(Icons.admin_panel_settings_outlined),
            width: double.infinity,
            entries: const [
              DropdownMenuEntry(value: 'participant', label: '成员'),
              DropdownMenuEntry(value: 'manager', label: '管理员'),
            ],
            onSelected: (value) {
              if (value == null) return;
              setState(() => _role = value);
            },
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: '添加',
        confirmIcon: Icons.add_rounded,
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入成员名称');
      return;
    }
    Navigator.of(context).pop(MoneyMemberDraft(name: name, role: _role));
  }
}
