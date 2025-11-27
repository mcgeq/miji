/**
 * UI Components - Headless UI + Tailwind CSS 4
 *
 * 所有 UI 组件的统一导出
 * 使用：import { Modal, Button } from '@/components/ui'
 */

export { default as Alert } from './Alert.vue';
export { default as Avatar } from './Avatar.vue';
// 基础组件
export { default as Badge } from './Badge.vue';
export { default as Button } from './Button.vue';
export { default as Card } from './Card.vue';
export { default as Checkbox } from './Checkbox.vue';

export { default as ConfirmDialog } from './ConfirmDialog.vue';
export { default as Descriptions } from './Descriptions.vue';
export { default as Divider } from './Divider.vue';
export { default as Dropdown } from './Dropdown.vue';
// 类型导出
export type { DropdownOption } from './Dropdown.vue';
// 已有组件（保留）
export { default as EnhancedUserSelector } from './EnhancedUserSelector.vue';
export { default as FamilyMemberSelector } from './FamilyMemberSelector.vue';
// 表单组件
export { default as FormRow } from './FormRow.vue';

export { default as Input } from './Input.vue';
// 核心组件
export { default as Modal } from './Modal.vue';
export { default as Pagination } from './Pagination.vue';
export { default as Progress } from './Progress.vue';
export { default as Radio } from './Radio.vue';
export type { RadioOption } from './Radio.vue';
export { default as Select } from './Select.vue';
export type { SelectOption } from './Select.vue';

export { default as Spinner } from './Spinner.vue';
export { default as Switch } from './Switch.vue';
export { default as Tabs } from './Tabs.vue';

export type { TabItem } from './Tabs.vue';
export { default as Textarea } from './Textarea.vue';
export { default as Tooltip } from './Tooltip.vue';
export { default as UserSelector } from './UserSelector.vue';
