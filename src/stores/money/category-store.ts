// src/stores/money/category-store.ts
import { defineStore } from 'pinia';
import type { Category, SubCategory } from '@/schema/money/category';
import { MoneyDb } from '@/services/money/money';

interface CategoryStoreState {
  categories: Category[];
  subCategories: SubCategory[];
  lastFetchedCategories: Date | null;
  lastFetchedSubCategories: Date | null;
  categoriesCacheExpiry: number; // 缓存过期时间（毫秒）
  subCategoriesCacheExpiry: number;
  loading: boolean;
  error: string | null;
}

/**
 * 分类管理 Store
 */
export const useCategoryStore = defineStore('money-categories', {
  state: (): CategoryStoreState => ({
    categories: [],
    subCategories: [],
    lastFetchedCategories: null,
    lastFetchedSubCategories: null,
    categoriesCacheExpiry: 5 * 60 * 1000, // 5分钟
    subCategoriesCacheExpiry: 5 * 60 * 1000,
    loading: false,
    error: null,
  }),

  getters: {
    /**
     * 检查分类缓存是否过期
     */
    isCategoriesCacheExpired: state => {
      if (!state.lastFetchedCategories) return true;
      return Date.now() - state.lastFetchedCategories.getTime() > state.categoriesCacheExpiry;
    },

    /**
     * 检查子分类缓存是否过期
     */
    isSubCategoriesCacheExpired: state => {
      if (!state.lastFetchedSubCategories) return true;
      return Date.now() - state.lastFetchedSubCategories.getTime() > state.subCategoriesCacheExpiry;
    },

    /**
     * 获取所有分类
     * Note: Category schema may not have categoryType field
     */
    getAllCategories: state => state.categories,

    /**
     * 根据分类ID获取子分类
     */
    getSubCategoriesByCategory: state => (categoryName: string) => {
      return state.subCategories.filter(s => s.categoryName === categoryName);
    },

    /**
     * UI格式的分类列表（用于选择器组件）
     */
    uiCategories: state => {
      return state.categories.map(category => ({
        code: category.name,
        icon: category.icon,
      }));
    },

    /**
     * UI格式的子分类列表（用于选择器组件）
     */
    uiSubCategories: state => {
      return state.subCategories.map(sub => ({
        code: sub.name,
        icon: sub.icon,
        categoryName: sub.categoryName,
      }));
    },
  },

  actions: {
    /**
     * 获取分类列表（带缓存）
     */
    async fetchCategories(force = false) {
      if (!(force || this.isCategoriesCacheExpired) && this.categories.length > 0) {
        return;
      }

      this.loading = true;
      this.error = null;

      try {
        this.categories = await MoneyDb.listCategory();
        this.lastFetchedCategories = new Date();
      } catch (error: unknown) {
        this.error = error instanceof Error ? error.message : '获取分类列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 获取子分类列表（带缓存）
     */
    async fetchSubCategories(force = false) {
      if (!(force || this.isSubCategoriesCacheExpired) && this.subCategories.length > 0) {
        return;
      }

      this.loading = true;
      this.error = null;

      try {
        this.subCategories = await MoneyDb.listSubCategory();
        this.lastFetchedSubCategories = new Date();
      } catch (error: unknown) {
        this.error = error instanceof Error ? error.message : '获取子分类列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 清除分类缓存
     */
    clearCategoriesCache() {
      this.lastFetchedCategories = null;
    },

    /**
     * 清除子分类缓存
     */
    clearSubCategoriesCache() {
      this.lastFetchedSubCategories = null;
    },

    /**
     * 清除所有缓存
     */
    clearAllCache() {
      this.clearCategoriesCache();
      this.clearSubCategoriesCache();
    },

    /**
     * 清除错误
     */
    clearError() {
      this.error = null;
    },
  },
});
