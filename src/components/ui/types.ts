/**
 * UI Components Types
 *
 * 所有 UI 组件的类型定义
 */

import type { Component } from 'vue';

/** 下拉菜单选项 */
export interface DropdownOption {
  /** 选项值 */
  value: string;
  /** 显示文本 */
  label: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 图标组件 */
  icon?: Component;
  /** 分隔线（在此选项后显示） */
  divider?: boolean;
}

/** 单选框选项 */
export interface RadioOption {
  /** 选项值 */
  value: string | number;
  /** 显示文本 */
  label: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 描述文本 */
  description?: string;
}

/** 选择器选项 */
export interface SelectOption {
  /** 选项值 */
  value: string | number;
  /** 显示文本 */
  label: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 图标组件 */
  icon?: Component;
  /** 分组标签 */
  group?: string;
}

/** 标签页项 */
export interface TabItem {
  /** 标签名称 */
  name: string;
  /** 标签值（唯一标识） */
  value?: string;
  /** 图标组件 */
  icon?: Component;
  /** 是否禁用 */
  disabled?: boolean;
  /** 徽章数字 */
  badge?: number;
}
