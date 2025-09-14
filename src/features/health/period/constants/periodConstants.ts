import type { Intensity, SymptomsType } from '@/schema/common';

export const durationPresets = [
  { days: 3, label: '3天' },
  { days: 4, label: '4天' },
  { days: 5, label: '5天' },
  { days: 6, label: '6天' },
  { days: 7, label: '7天' },
];

export const symptomGroups: {
  type: SymptomsType;
  label: string;
  icon: string;
  color: string;
}[] = [
  {
    type: 'Pain' as const,
    label: '疼痛程度',
    icon: 'i-tabler-pain',
    color: 'text-red-500',
  },
  {
    type: 'Fatigue' as const,
    label: '疲劳程度',
    icon: 'i-tabler-battery-low',
    color: 'text-orange-500',
  },
  {
    type: 'MoodSwing' as const,
    label: '情绪波动',
    icon: 'i-tabler-mood-confuzed',
    color: 'text-blue-500',
  },
];

export const intensityLevels: { value: Intensity; label: string }[] = [
  { value: 'Light' as const, label: '轻度' },
  { value: 'Medium' as const, label: '中度' },
  { value: 'Heavy' as const, label: '重度' },
];
