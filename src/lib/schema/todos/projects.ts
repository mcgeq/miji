import { z } from 'zod/v4';
import {
  ColorHexRegex,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';

export const ProjectSchema = z.object({
  serial_num: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  owner_id: SerialNumSchema,
  color: z.string().regex(ColorHexRegex, {
    error: 'Color must be in hex format like 0xffff or 0xff00ff00',
  }),
  is_archived: z.boolean(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type Projects = z.infer<typeof ProjectSchema>;
