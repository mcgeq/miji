import { z } from 'zod/v4';
import {
  ColorHexRegex,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';

export const ProjectSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema.nullable(),
  ownerId: SerialNumSchema,
  color: z.string().regex(ColorHexRegex, {
    error: 'Color must be in hex format like 0xffff or 0xff00ff00',
  }),
  isArchived: z.boolean(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Projects = z.infer<typeof ProjectSchema>;
