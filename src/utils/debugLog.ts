// src/utils/debugLog.ts
type LogType = 'info' | 'warn' | 'error' | 'debug';

// 日志级别优先级
const levelPriority: Record<LogType, number> = {
  error: 1,
  warn: 2,
  info: 3,
  debug: 4,
};

// 日志类型图标
const emojiMap: Record<LogType, string> = {
  info: 'i',
  warn: '!',
  error: '❌',
  debug: '🐛',
};

// 日志类型样式，模拟 UnoCSS 风格
const styleMap: Record<LogType, string> = {
  info: 'color: #3b82f6; background: #dbeafe; padding: 4px 8px; border-radius: 4px; font-weight: 500; font-family: monospace;',
  warn: 'color: #f59e0b; background: #fef3c7; padding: 4px 8px; border-radius: 4px; font-weight: 500; font-family: monospace;',
  error:
    'color: #ef4444; background: #fee2e2; padding: 4px 8px; border-radius: 4px; font-weight: 500; font-family: monospace;',
  debug:
    'color: #22c55e; background: #d1fae5; padding: 4px 8px; border-radius: 4px; font-weight: 500; font-family: monospace;',
};

// 缓存环境变量
const isDebugEnabled =
  import.meta.env.MODE === 'development' ||
  import.meta.env.VITE_ENABLE_DEBUG === 'true';
const logLevel = (import.meta.env.VITE_LOG_LEVEL as LogType) || 'info';

// 时间戳格式化
const getTimestamp = (locale: string = 'en-US'): string => {
  const formatter = new Intl.DateTimeFormat(locale, {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    // @ts-ignore
    fractionalSecondDigits: 3,
  });
  return formatter.format(new Date());
};

// 数据格式化
const formatData = (
  data: unknown,
): { formatted: string; isObject: boolean; isTableFriendly: boolean } => {
  if (data == null) {
    return { formatted: String(data), isObject: false, isTableFriendly: false };
  }

  if (typeof data === 'object') {
    if (data instanceof Error) {
      return {
        formatted: `${data.name}: ${data.message}\n${data.stack || ''}`,
        isObject: true,
        isTableFriendly: false,
      };
    }

    const isTableFriendly =
      Array.isArray(data) || Object.keys(data).length <= 10;
    try {
      return {
        formatted: JSON.stringify(
          data,
          (_key, value) =>
            typeof value === 'bigint' ? value.toString() : value,
          2,
        ),
        isObject: true,
        isTableFriendly,
      };
    } catch {
      return {
        formatted: String(data),
        isObject: true,
        isTableFriendly: false,
      };
    }
  }

  return { formatted: String(data), isObject: false, isTableFriendly: false };
};

// 核心日志函数
function debugLog(
  label: string,
  type: LogType = 'info',
  args: unknown[],
  options: {
    locale?: string;
    collapse?: boolean;
    category?: string;
    formatter?: (data: unknown) => string;
  } = { locale: 'en-US', collapse: true },
) {
  if (!isDebugEnabled || levelPriority[type] > levelPriority[logLevel]) return;

  const emoji = emojiMap[type] ?? 'i';
  const style =
    styleMap[type] ??
    'color: gray; padding: 4px 8px; border-radius: 4px; font-family: monospace;';
  const timestamp = getTimestamp(options.locale);
  const category = options.category ? `${options.category.toUpperCase()}/` : '';
  const prefix = `%c${emoji} [${category}${label.toUpperCase()}] ${timestamp}`;

  const groupFn = options.collapse ? console.groupCollapsed : console.group;
  groupFn(prefix, style);

  for (const item of args) {
    if (item instanceof Promise) {
      item
        .then((resolved) => debugLog(label, type, [resolved], options))
        .catch((err) => debugLog(label, 'error', [err], options));
      continue;
    }

    const { formatted, isObject, isTableFriendly } = formatData(item);
    const output = options.formatter ? options.formatter(item) : formatted;

    if (isObject && isTableFriendly && item != null) {
      console.table(item);
    } else {
      console[type](
        `%c${output}`,
        'font-family: monospace; white-space: pre-wrap; padding-left: 8px;',
      );
    }
  }

  if (type === 'error' || type === 'debug') {
    console.groupCollapsed(
      '%cStack Trace',
      'color: #6b7280; font-size: 0.9em; font-family: monospace;',
    );
    console.trace();
    console.groupEnd();
  }

  console.groupCollapsed(
    '%cEnvironment',
    'color: #6b7280; font-size: 0.9em; font-family: monospace;',
  );
  console.log(`%cMode: ${import.meta.env.MODE}`, 'color: #6b7280;');
  if (typeof process !== 'undefined' && process.version) {
    console.log(`%cNode: ${process.version}`, 'color: #6b7280;');
  }
  console.groupEnd();

  console.groupEnd();
}

// 快捷调用
export const Lg = {
  i: (label: string, ...args: unknown[]) => debugLog(label, 'info', args),
  w: (label: string, ...args: unknown[]) => debugLog(label, 'warn', args),
  e: (label: string, ...args: unknown[]) => debugLog(label, 'error', args),
  d: (label: string, ...args: unknown[]) => debugLog(label, 'debug', args),
};
