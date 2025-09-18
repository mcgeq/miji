import z from 'zod';
import { DateTimeSchema, NameSchema } from '../common';

export const CategorySchema = z.object({
  name: NameSchema,
  icon: z.string().optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const CategoryCreateSchema = CategorySchema.pick({ name: true, icon: true }).strict();

export const CategoryUpdateSchema = CategoryCreateSchema.optional();

export const SubCategorySchema = z.object({
  name: NameSchema,
  icon: z.string().optional().nullable(),
  categoryName: NameSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SubCategoryCreateSchema = SubCategorySchema.pick({
  name: true,
  icon: true,
  category_name: true,
}).strict();

export const SubCategoryUpdateSchema = SubCategoryCreateSchema.optional();

export type Category = z.infer<typeof CategorySchema>;
export type CategoryCreate = z.infer<typeof CategoryCreateSchema>;
export type CategoryUpdate = z.infer<typeof CategoryUpdateSchema>;
export type SubCategory = z.infer<typeof SubCategorySchema>;
export type SubCategoryCreate = z.infer<typeof SubCategoryCreateSchema>;
export type SubCategoryUpdate = z.infer<typeof SubCategoryUpdateSchema>;
