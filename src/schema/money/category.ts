import z from 'zod';
import { CategoryNameSchema, DateTimeSchema, SubCategoryNameSchema } from '../common';

/**
 * 分类 Schema
 * 使用 CategoryNameSchema 确保名称格式统一
 */
export const CategorySchema = z.object({
  name: CategoryNameSchema,
  icon: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const CategoryCreateSchema = CategorySchema.pick({ name: true, icon: true }).strict();

export const CategoryUpdateSchema = CategoryCreateSchema.partial();

/**
 * 子分类 Schema
 * 使用 SubCategoryNameSchema 和 CategoryNameSchema 确保名称格式统一
 */
export const SubCategorySchema = z.object({
  name: SubCategoryNameSchema,
  icon: z.string(),
  categoryName: CategoryNameSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SubCategoryCreateSchema = SubCategorySchema.pick({
  name: true,
  icon: true,
  categoryName: true,
}).strict();

export const SubCategoryUpdateSchema = SubCategoryCreateSchema.partial();

export type Category = z.infer<typeof CategorySchema>;
export type CategoryCreate = z.infer<typeof CategoryCreateSchema>;
export type CategoryUpdate = z.infer<typeof CategoryUpdateSchema>;
export type SubCategory = z.infer<typeof SubCategorySchema>;
export type SubCategoryCreate = z.infer<typeof SubCategoryCreateSchema>;
export type SubCategoryUpdate = z.infer<typeof SubCategoryUpdateSchema>;
