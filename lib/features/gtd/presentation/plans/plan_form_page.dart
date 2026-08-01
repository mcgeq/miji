import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

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
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '计划名称',
              hintText: '例如：喝水、学习、跑步',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _iconController,
            decoration: const InputDecoration(
              labelText: '图标 (emoji)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: '分类',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '健康习惯', child: Text('💧 健康习惯')),
              DropdownMenuItem(value: '学习成长', child: Text('📚 学习成长')),
              DropdownMenuItem(value: '运动', child: Text('🏃 运动')),
              DropdownMenuItem(value: '生活记录', child: Text('📸 生活记录')),
              DropdownMenuItem(value: '纪念日', child: Text('🎉 纪念日')),
              DropdownMenuItem(value: '其他', child: Text('📌 其他')),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CheckinPlanType>(
            initialValue: _planType,
            decoration: const InputDecoration(
              labelText: '计划类型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: CheckinPlanType.cyclic,
                child: Text('循环计划'),
              ),
              DropdownMenuItem(
                value: CheckinPlanType.event,
                child: Text('事件计划'),
              ),
            ],
            onChanged: (v) => setState(() => _planType = v!),
          ),
          if (!_isEventType) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<CheckinFrequencyType>(
              initialValue: _frequencyType,
              decoration: const InputDecoration(
                labelText: '打卡频率',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: CheckinFrequencyType.daily,
                  child: Text('每天'),
                ),
                DropdownMenuItem(
                  value: CheckinFrequencyType.weekly,
                  child: Text('每周'),
                ),
                DropdownMenuItem(
                  value: CheckinFrequencyType.monthly,
                  child: Text('每月'),
                ),
              ],
              onChanged: (v) => setState(() => _frequencyType = v!),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: '每日目标',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: _targetUnit,
                  decoration: const InputDecoration(
                    labelText: '单位',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '次', child: Text('次')),
                    DropdownMenuItem(value: '分钟', child: Text('分钟')),
                    DropdownMenuItem(value: '杯', child: Text('杯')),
                    DropdownMenuItem(value: '张', child: Text('张')),
                    DropdownMenuItem(value: '个', child: Text('个')),
                    DropdownMenuItem(value: '步', child: Text('步')),
                  ],
                  onChanged: (v) => setState(() => _targetUnit = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CheckinTriggerMode>(
            initialValue: _triggerMode,
            decoration: const InputDecoration(
              labelText: '触发方式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: CheckinTriggerMode.button,
                child: Text('按钮计数'),
              ),
              DropdownMenuItem(
                value: CheckinTriggerMode.timer,
                child: Text('计时器'),
              ),
              DropdownMenuItem(
                value: CheckinTriggerMode.photo,
                child: Text('拍照打卡'),
              ),
            ],
            onChanged: (v) => setState(() => _triggerMode = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CheckinRecordGranularity>(
            initialValue: _recordGranularity,
            decoration: const InputDecoration(
              labelText: '记录模式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: CheckinRecordGranularity.merged,
                child: Text('每日合并（一天一条记录，自动累加）'),
              ),
              DropdownMenuItem(
                value: CheckinRecordGranularity.detailed,
                child: Text('每次独立（每次操作一条记录）'),
              ),
            ],
            onChanged: (v) => setState(() => _recordGranularity = v!),
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
                  decoration: const InputDecoration(
                    labelText: '提醒时间',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
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

      ref.invalidate(allPlansProvider);
      ref.invalidate(activePlansProvider);
      ref.invalidate(todayProgressProvider);

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
