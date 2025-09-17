import z from 'zod';
import { DateTimeSchema, NameSchema } from '../common';

export const CategoreSchema = z.object({
  name: NameSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const CategoreCreateSchema = z.object({
  name: NameSchema,
});

export const CategoreUpdateSchema = z.object({
  name: NameSchema.optional().nullable(),
});

export const SubCategoreSchema = z.object({
  name: NameSchema,
  categoryName: NameSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SubCategoreCreateSchema = SubCategoreSchema.pick({
  name: true,
  category_name: true,
}).strict();

export const SubCategoreUpdateSchema = SubCategoreCreateSchema.optional();

export type Category = z.infer<typeof CategoreSchema>;
export type CategoryCreate = z.infer<typeof CategoreCreateSchema>;
export type CategoryUpdate = z.infer<typeof CategoreUpdateSchema>;
export type SubCategory = z.infer<typeof SubCategoreSchema>;
export type SubCategoryCreate = z.infer<typeof SubCategoreCreateSchema>;
export type SubCategoryUpdate = z.infer<typeof SubCategoreUpdateSchema>;
