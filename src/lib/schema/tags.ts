import { z } from 'zod/v4';
import {
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from './common';

export const TagsSchema = z.object({
  serial_num: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema,
});

export type Tags = z.infer<typeof TagsSchema>;
