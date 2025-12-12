/**
 * 交易分类管理 Composable
 *
 * 职责：
 * - 根据交易类型过滤分类
 * - 提供分类和子分类映射
 * - 处理收入类别白名单
 */

import type { Ref } from 'vue';
import { computed } from 'vue';
import type { TransactionType } from '@/schema/common';
import { INCOME_ALLOWED_CATEGORIES, TRANSFER_CATEGORY } from '../constants/transactionConstants';

export interface CategoryItem {
  name: string;
  subs: string[];
}

export interface SubCategory {
  categoryName: string;
  name: string;
}

export function useTransactionCategory(
  transactionType: Ref<TransactionType>,
  subCategories: Ref<SubCategory[]>,
) {
  /**
   * 辅助函数：添加子分类到映射
   */
  function addSubCategoryToMap(
    map: Map<string, CategoryItem>,
    categoryName: string,
    subName: string,
  ): void {
    if (!map.has(categoryName)) {
      map.set(categoryName, { name: categoryName, subs: [] });
    }
    map.get(categoryName)?.subs.push(subName);
  }

  /**
   * 辅助函数：检查是否应包含收入分类
   */
  function shouldIncludeForIncome(categoryName: string): boolean {
    return INCOME_ALLOWED_CATEGORIES.includes(
      categoryName as (typeof INCOME_ALLOWED_CATEGORIES)[number],
    );
  }

  /**
   * 辅助函数：检查是否应包含转账分类
   */
  function shouldIncludeForTransfer(categoryName: string): boolean {
    return categoryName === TRANSFER_CATEGORY;
  }

  /**
   * 辅助函数：根据交易类型判断是否应包含分类
   */
  function shouldIncludeCategory(type: TransactionType, categoryName: string): boolean {
    if (type === 'Income') return shouldIncludeForIncome(categoryName);
    if (type === 'Transfer') return shouldIncludeForTransfer(categoryName);
    return true; // Expense: include all
  }

  /**
   * 分类映射（根据交易类型过滤）
   */
  const categoryMap = computed(() => {
    const map = new Map<string, CategoryItem>();

    subCategories.value.forEach(sub => {
      if (shouldIncludeCategory(transactionType.value, sub.categoryName)) {
        addSubCategoryToMap(map, sub.categoryName, sub.name);
      }
    });

    return map;
  });

  /**
   * 获取分类列表（数组格式）
   */
  const categories = computed(() => {
    return Array.from(categoryMap.value.values());
  });

  /**
   * 获取所有子分类列表
   */
  const allSubCategories = computed(() => {
    const subs: string[] = [];
    categoryMap.value.forEach(category => {
      subs.push(...category.subs);
    });
    return subs;
  });

  /**
   * 检查分类是否有效
   */
  function isCategoryValid(categoryName: string): boolean {
    return categoryMap.value.has(categoryName);
  }

  /**
   * 检查子分类是否有效
   */
  function isSubCategoryValid(categoryName: string, subCategoryName: string): boolean {
    const category = categoryMap.value.get(categoryName);
    return category ? category.subs.includes(subCategoryName) : false;
  }

  /**
   * 获取分类的第一个子分类
   */
  function getFirstSubCategory(categoryName: string): string | undefined {
    const category = categoryMap.value.get(categoryName);
    return category?.subs[0];
  }

  return {
    categoryMap,
    categories,
    allSubCategories,
    isCategoryValid,
    isSubCategoryValid,
    getFirstSubCategory,
  };
}
