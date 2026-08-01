/// 打卡预置模板种子数据。
///
/// 按分类组织，在用户首次登陆时按兴趣标签过滤插入。
class CheckinPlanTemplate {
  const CheckinPlanTemplate({
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
    required this.planType,
    required this.frequencyType,
    this.frequencyConfig,
    required this.targetValue,
    required this.targetUnit,
    required this.triggerMode,
    required this.recordGranularity,
    required this.defaultVisibility,
  });

  final String name;
  final String icon;
  final String color;
  final String category;
  final String planType; // cyclic | event
  final String frequencyType; // daily | weekly | monthly | cron | once
  final String? frequencyConfig;
  final double targetValue;
  final String targetUnit;
  final String triggerMode; // button | photo | timer
  final String recordGranularity; // merged | detailed
  final String defaultVisibility; // private | public
}

// ---------------------------------------------------------------------------
// 💧 健康习惯
// ---------------------------------------------------------------------------

const _healthHabitTemplates = [
  CheckinPlanTemplate(
    name: '喝水',
    icon: '💧',
    color: '#0EA5E9',
    category: '健康习惯',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 8,
    targetUnit: '杯',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '早睡',
    icon: '🌙',
    color: '#6366F1',
    category: '健康习惯',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '按时吃饭',
    icon: '🍚',
    color: '#F59E0B',
    category: '健康习惯',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 3,
    targetUnit: '餐',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '大便记录',
    icon: '🚽',
    color: '#78716C',
    category: '健康习惯',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'button',
    recordGranularity: 'detailed',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '洗澡',
    icon: '🚿',
    color: '#06B6D4',
    category: '健康习惯',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
];

// ---------------------------------------------------------------------------
// 📚 学习成长
// ---------------------------------------------------------------------------

const _studyTemplates = [
  CheckinPlanTemplate(
    name: '每日学习',
    icon: '📖',
    color: '#8B5CF6',
    category: '学习成长',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 60,
    targetUnit: '分钟',
    triggerMode: 'timer',
    recordGranularity: 'detailed',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '阅读',
    icon: '📚',
    color: '#EC4899',
    category: '学习成长',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 30,
    targetUnit: '分钟',
    triggerMode: 'timer',
    recordGranularity: 'detailed',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '背单词',
    icon: '📝',
    color: '#10B981',
    category: '学习成长',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 20,
    targetUnit: '个',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
];

// ---------------------------------------------------------------------------
// 🏃 运动
// ---------------------------------------------------------------------------

const _exerciseTemplates = [
  CheckinPlanTemplate(
    name: '每日运动',
    icon: '🏃',
    color: '#EF4444',
    category: '运动',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 30,
    targetUnit: '分钟',
    triggerMode: 'timer',
    recordGranularity: 'detailed',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '跑步',
    icon: '🏃‍♂️',
    color: '#F97316',
    category: '运动',
    planType: 'cyclic',
    frequencyType: 'weekly',
    frequencyConfig: '{"days":[1,3,5]}',
    targetValue: 3,
    targetUnit: '次',
    triggerMode: 'timer',
    recordGranularity: 'detailed',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '散步',
    icon: '🚶',
    color: '#84CC16',
    category: '运动',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 8000,
    targetUnit: '步',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
];

// ---------------------------------------------------------------------------
// 📸 生活记录
// ---------------------------------------------------------------------------

const _lifestyleTemplates = [
  CheckinPlanTemplate(
    name: '每日一拍',
    icon: '📸',
    color: '#D946EF',
    category: '生活记录',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 1,
    targetUnit: '张',
    triggerMode: 'photo',
    recordGranularity: 'detailed',
    defaultVisibility: 'public',
  ),
  CheckinPlanTemplate(
    name: '美食打卡',
    icon: '🍜',
    color: '#F43F5E',
    category: '生活记录',
    planType: 'cyclic',
    frequencyType: 'daily',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'photo',
    recordGranularity: 'detailed',
    defaultVisibility: 'public',
  ),
  CheckinPlanTemplate(
    name: '景点打卡',
    icon: '🗺️',
    color: '#14B8A6',
    category: '生活记录',
    planType: 'event',
    frequencyType: 'once',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'photo',
    recordGranularity: 'detailed',
    defaultVisibility: 'public',
  ),
];

// ---------------------------------------------------------------------------
// 🎉 纪念日
// ---------------------------------------------------------------------------

const _anniversaryTemplates = [
  CheckinPlanTemplate(
    name: '生日',
    icon: '🎂',
    color: '#E11D48',
    category: '纪念日',
    planType: 'event',
    frequencyType: 'monthly',
    frequencyConfig: '{"interval":12}',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '恋爱纪念日',
    icon: '💕',
    color: '#F472B6',
    category: '纪念日',
    planType: 'event',
    frequencyType: 'monthly',
    frequencyConfig: '{"interval":12}',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
  CheckinPlanTemplate(
    name: '入职纪念日',
    icon: '💼',
    color: '#3B82F6',
    category: '纪念日',
    planType: 'event',
    frequencyType: 'monthly',
    frequencyConfig: '{"interval":12}',
    targetValue: 1,
    targetUnit: '次',
    triggerMode: 'button',
    recordGranularity: 'merged',
    defaultVisibility: 'private',
  ),
];

// ---------------------------------------------------------------------------
// 分类 → 模板列表 映射
// ---------------------------------------------------------------------------

/// 按分类分组的模板列表，onboarding 时按用户选择的兴趣标签过滤。
const checkinPlanTemplatesByCategory = <String, List<CheckinPlanTemplate>>{
  '健康习惯': _healthHabitTemplates,
  '学习成长': _studyTemplates,
  '运动': _exerciseTemplates,
  '生活记录': _lifestyleTemplates,
  '纪念日': _anniversaryTemplates,
};

/// 所有模板的扁平列表。
const allCheckinPlanTemplates = <CheckinPlanTemplate>[
  ..._healthHabitTemplates,
  ..._studyTemplates,
  ..._exerciseTemplates,
  ..._lifestyleTemplates,
  ..._anniversaryTemplates,
];
