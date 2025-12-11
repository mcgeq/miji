import { z } from 'zod';
import type { UsageDetail } from './common';
import { DateTimeSchema, DescriptionSchema, NameSchema, SerialNumSchema } from './common';

export const TagsSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema.nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema,
});

export type Tags = z.infer<typeof TagsSchema>;
export type TagsWithUsageStats = Tags & {
  usage: {
    todos: UsageDetail;
    projects: UsageDetail;
  };
};
