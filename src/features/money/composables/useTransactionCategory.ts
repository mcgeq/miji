/**
 * 交易分类管理 Composable
 *
 * 职责：
 * - 根据交易类型过滤分类
 * - 提供分类和子分类映射
 * - 处理收入类别白名单
 */

import { computed } from 'vue';
import { INCOME_ALLOWED_CATEGORIES, TRANSFER_CATEGORY } from '../constants/transactionConstants';
import type { TransactionType } from '@/schema/common';
import type { Ref } from 'vue';

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
   * 分类映射（根据交易类型过滤）
   */
  const categoryMap = computed(() => {
    const map = new Map<string, CategoryItem>();

    subCategories.value.forEach(sub => {
      // 收入类型：只显示白名单分类
      if (transactionType.value === 'Income') {
        if (INCOME_ALLOWED_CATEGORIES.includes(sub.categoryName as any)) {
          if (!map.has(sub.categoryName)) {
            map.set(sub.categoryName, { name: sub.categoryName, subs: [] });
          }
          map.get(sub.categoryName)!.subs.push(sub.name);
        }
      } else if (transactionType.value === 'Transfer') {
        // 转账类型：只显示转账分类
        if (sub.categoryName === TRANSFER_CATEGORY) {
          if (!map.has(TRANSFER_CATEGORY)) {
            map.set(TRANSFER_CATEGORY, { name: TRANSFER_CATEGORY, subs: [] });
          }
          map.get(TRANSFER_CATEGORY)!.subs.push(sub.name);
        }
      } else {
        // 支出类型：显示所有分类
        if (!map.has(sub.categoryName)) {
          map.set(sub.categoryName, { name: sub.categoryName, subs: [] });
        }
        map.get(sub.categoryName)!.subs.push(sub.name);
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
