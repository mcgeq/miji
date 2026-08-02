import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

/// 计划创建/编辑页
class PlanFormPage extends ConsumerStatefulWidget {
  const PlanFormPage({super.key, this.editPlanId});

  final String? editPlanId;

  @override
  ConsumerState<PlanFormPage> createState() => _PlanFormPageState();
}

class _PlanFormPageState extends ConsumerState<PlanFormPage> {
  final _nameController = TextEditingController();
  final _iconController = TextEditingController(text: '📌');
  var _category = '其他';
  var _planType = CheckinPlanType.cyclic;
  var _frequencyType = CheckinFrequencyType.daily;
  final _targetController = TextEditingController(text: '1');
  var _targetUnit = '次';
  var _triggerMode = CheckinTriggerMode.button;
  var _recordGranularity = CheckinRecordGranularity.merged;
  var _reminderEnabled = false;
  var _reminderTime = '08:00';
  var _isLoading = false;
  var _isEdit = false;

  bool get _isEventType => _planType == CheckinPlanType.event;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.editPlanId != null;
    if (_isEdit) {
      _loadPlan();
    }
  }

  Future<void> _loadPlan() async {
    final plansAsync = ref.read(allPlansProvider);
    plansAsync.whenData((plans) {
      final plan = plans.where((p) => p.id == widget.editPlanId).firstOrNull;
      if (plan == null) return;
      setState(() {
        _nameController.text = plan.name;
        _iconController.text = plan.icon;
        _category = plan.category;
        _planType = plan.planType;
        _frequencyType = plan.frequencyType;
        _targetController.text = plan.targetValue.toString();
        _targetUnit = plan.targetUnit;
        _triggerMode = plan.triggerMode;
        _recordGranularity = plan.recordGranularity;
        _reminderEnabled = plan.reminderEnabled;
        _reminderTime = plan.reminderTime ?? '08:00';
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑计划' : '新建计划')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppTextField(
            controller: _nameController,
            labelText: '计划名称',
            hintText: '例如：喝水、学习、跑步',
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _iconController, labelText: '图标 (emoji)'),
          const SizedBox(height: 12),
          FormDropdown<String>(
            initialSelection: _category,
            label: '分类',
            enableFilter: true,
            onSelected: (v) {
              if (v != null) setState(() => _category = v);
            },
            entries: const [
              DropdownMenuEntry(
                value: '健康习惯',
                label: '健康习惯',
                labelWidget: Text('💧 健康习惯'),
              ),
              DropdownMenuEntry(
                value: '学习成长',
                label: '学习成长',
                labelWidget: Text('📚 学习成长'),
              ),
              DropdownMenuEntry(
                value: '运动',
                label: '运动',
                labelWidget: Text('🏃 运动'),
              ),
              DropdownMenuEntry(
                value: '生活记录',
                label: '生活记录',
                labelWidget: Text('📸 生活记录'),
              ),
              DropdownMenuEntry(
                value: '纪念日',
                label: '纪念日',
                labelWidget: Text('🎉 纪念日'),
              ),
              DropdownMenuEntry(
                value: '其他',
                label: '其他',
                labelWidget: Text('📌 其他'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormDropdown<CheckinPlanType>(
            initialSelection: _planType,
            label: '计划类型',
            onSelected: (v) {
              if (v != null) setState(() => _planType = v);
            },
            entries: const [
              DropdownMenuEntry(value: CheckinPlanType.cyclic, label: '循环计划'),
              DropdownMenuEntry(value: CheckinPlanType.event, label: '事件计划'),
            ],
          ),
          if (!_isEventType) ...[
            const SizedBox(height: 12),
            FormDropdown<CheckinFrequencyType>(
              initialSelection: _frequencyType,
              label: '打卡频率',
              onSelected: (v) {
                if (v != null) setState(() => _frequencyType = v);
              },
              entries: const [
                DropdownMenuEntry(
                  value: CheckinFrequencyType.daily,
                  label: '每天',
                ),
                DropdownMenuEntry(
                  value: CheckinFrequencyType.weekly,
                  label: '每周',
                ),
                DropdownMenuEntry(
                  value: CheckinFrequencyType.monthly,
                  label: '每月',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _targetController,
                  labelText: '每日目标',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              FormDropdown<String>(
                initialSelection: _targetUnit,
                label: '单位',
                width: 100,
                onSelected: (v) {
                  if (v != null) setState(() => _targetUnit = v);
                },
                entries: const [
                  DropdownMenuEntry(value: '次', label: '次'),
                  DropdownMenuEntry(value: '分钟', label: '分钟'),
                  DropdownMenuEntry(value: '杯', label: '杯'),
                  DropdownMenuEntry(value: '升', label: '升'),
                  DropdownMenuEntry(value: '张', label: '张'),
                  DropdownMenuEntry(value: '个', label: '个'),
                  DropdownMenuEntry(value: '步', label: '步'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormDropdown<CheckinTriggerMode>(
            initialSelection: _triggerMode,
            label: '触发方式',
            onSelected: (v) {
              if (v != null) setState(() => _triggerMode = v);
            },
            entries: const [
              DropdownMenuEntry(
                value: CheckinTriggerMode.button,
                label: '按钮计数',
              ),
              DropdownMenuEntry(value: CheckinTriggerMode.timer, label: '计时器'),
              DropdownMenuEntry(value: CheckinTriggerMode.photo, label: '拍照打卡'),
            ],
          ),
          const SizedBox(height: 12),
          FormDropdown<CheckinRecordGranularity>(
            initialSelection: _recordGranularity,
            label: '记录模式',
            onSelected: (v) {
              if (v != null) setState(() => _recordGranularity = v);
            },
            entries: const [
              DropdownMenuEntry(
                value: CheckinRecordGranularity.merged,
                label: '每日合并（一天一条记录，自动累加）',
              ),
              DropdownMenuEntry(
                value: CheckinRecordGranularity.detailed,
                label: '每次独立（每次操作一条记录）',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('开启提醒'),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_reminderEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _pickTime(context),
                child: InputDecorator(
                  decoration: appInputDecoration(
                    context,
                    labelText: '提醒时间',
                    enabled: true,
                    suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
                  ),
                  child: Text(_reminderTime),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: Text(_isEdit ? '保存修改' : '创建计划'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(checkinRepositoryProvider);

      if (_isEdit && widget.editPlanId != null) {
        final existing = await repo.getPlan(widget.editPlanId!);
        if (existing != null) {
          final updated = existing.copyWith(
            name: name,
            icon: _iconController.text,
            category: _category,
            planType: _planType,
            frequencyType: _frequencyType,
            targetValue: double.tryParse(_targetController.text) ?? 1,
            targetUnit: _targetUnit,
            triggerMode: _triggerMode,
            recordGranularity: _recordGranularity,
            reminderEnabled: _reminderEnabled,
            reminderTime: _reminderEnabled ? _reminderTime : null,
          );
          await repo.updatePlan(updated);
        }
      } else {
        final session = ref.read(authSessionControllerProvider);
        final userId = session.userId;
        if (userId == null) return;

        final newPlan = await repo.createPlan(
          CheckinPlanDraft(
            name: name,
            icon: _iconController.text,
            category: _category,
            planType: _planType,
            frequencyType: _planType == CheckinPlanType.event
                ? CheckinFrequencyType.once
                : _frequencyType,
            targetValue: double.tryParse(_targetController.text) ?? 1,
            targetUnit: _targetUnit,
            triggerMode: _triggerMode,
            recordGranularity: _recordGranularity,
            reminderEnabled: _reminderEnabled,
            reminderTime: _reminderEnabled ? _reminderTime : null,
          ),
          userId,
        );
        // 新建的计划 ID 在 createPlan 后才确定，用它来调度提醒
        if (_reminderEnabled && mounted) {
          ref
              .read(appNotificationServiceProvider)
              .scheduleDailyCheckinReminder(
                planId: newPlan.id,
                planName: name,
                timeString: _reminderTime,
              );
        }
      }

      invalidateCheckinData(ref);

      // 编辑模式：更新提醒
      if (_isEdit && widget.editPlanId != null) {
        _updateReminderForEdit();
      }

      if (mounted) {
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final parts = _reminderTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        _reminderTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _updateReminderForEdit() {
    final notifier = ref.read(appNotificationServiceProvider);
    final name = _nameController.text.trim();
    final planId = widget.editPlanId!;
    if (_reminderEnabled && name.isNotEmpty) {
      notifier.scheduleDailyCheckinReminder(
        planId: planId,
        planName: name,
        timeString: _reminderTime,
      );
    } else {
      notifier.cancelCheckinReminder(planId);
    }
  }
}
