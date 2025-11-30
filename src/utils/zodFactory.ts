import { RepeatPeriodSchema } from '../schema/common';
import { Lg } from './debugLog';
import type { RepeatPeriod } from '../schema/common';
import type { z, ZodObject, ZodRawShape } from 'zod';

/**
 * 通用对象工厂：根据 Zod Schema 和默认值生成合法对象
 *
 * @param schema ZodObject schema
 * @param defaults 默认值，可以是值或函数
 * @param input 可选输入值，将覆盖默认值
 * @returns 满足 schema 的对象
 */
export function createWithDefaults<T extends ZodRawShape, Schema extends ZodObject<T>>(
  schema: Schema,
  defaults: Partial<{
    [K in keyof z.infer<Schema>]: z.infer<Schema>[K] | (() => z.infer<Schema>[K]);
  }>,
  input: Partial<z.infer<Schema>> = {},
): z.infer<Schema> {
  const resolvedDefaults = {} as Partial<z.infer<Schema>>;

  for (const key in defaults) {
    const value = defaults[key];
    resolvedDefaults[key] = typeof value === 'function' ? (value as () => any)() : value;
  }

  const merged: Partial<z.infer<Schema>> = {
    ...resolvedDefaults,
    ...input,
  };

  const parsed = schema.safeParse(merged);
  if (!parsed.success) {
    Lg.e('Zod validation failed:', parsed.error);
    throw new Error('Failed to create valid object');
  }

  return parsed.data;
}

export function createRepeatPeriod(input?: Partial<RepeatPeriod>): RepeatPeriod {
  const type = input?.type ?? 'None';

  // 根据 type 提供对应默认值
  let defaults: Partial<RepeatPeriod> = { type };

  switch (type) {
    case 'None':
      // 没有额外字段
      break;
    case 'Daily':
      defaults = { ...defaults, interval: 1 };
      break;
    case 'Weekly':
      defaults = { ...defaults, interval: 1, daysOfWeek: ['Mon'] };
      break;
    case 'Monthly':
      defaults = { ...defaults, interval: 1, day: 1 };
      break;
    case 'Yearly':
      defaults = { ...defaults, interval: 1, month: 1, day: 1 };
      break;
    case 'Custom':
      defaults = { ...defaults, description: '自定义周期' };
      break;
    default:
      throw new Error(`Unsupported repeat period type: ${type}`);
  }

  // 合并用户输入，优先使用用户输入的值
  const merged = { ...defaults, ...input };

  // 校验并返回（不通过会抛异常）
  return RepeatPeriodSchema.parse(merged);
}
