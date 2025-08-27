// src/utils/debugLog.ts
import { debug, error, info, trace, warn } from '@tauri-apps/plugin-log';

type LogType = 'info' | 'warn' | 'error' | 'debug' | 'trace';

// 日志级别优先级
const levelPriority: Record<LogType, number> = {
  trace: 1,
  error: 2,
  warn: 3,
  info: 4,
  debug: 5,
};

// 日志类型图标
const emojiMap: Record<LogType, string> = {
  trace: '↳',
  info: 'ℹ',
  warn: '⚠',
  error: '❌',
  debug: '🐛',
};

// 日志类型样式，模拟 UnoCSS 风格
const styleMap: Record<LogType, string> = {
  trace:
    'color: #94a3b8; background: #f1f5f9; padding: 4px 8px; border-radius: 4px; font-weight: 500; font-family: monospace;',
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
function getTimestamp(locale: string = 'en-US'): string {
  const formatter = new Intl.DateTimeFormat(locale, {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    // @ts-expect-error - 显式说明：fractionalSecondDigits 在现代浏览器中已支持，用于精确到毫秒的时间戳
    fractionalSecondDigits: 3,
  });
  return formatter.format(new Date());
}

// 数据格式化
function formatData(data: unknown): {
  formatted: string;
  isObject: boolean;
  isTableFriendly: boolean;
} {
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
}

// 核心日志函数
function debugLog(
  label: string,
  type: LogType = 'info',
  args: any[],
  options: {
    locale?: string;
    collapse?: boolean;
    category?: string;
    formatter?: (data: unknown) => string;
  } = { locale: 'en-US', collapse: true },
) {
  if (!isDebugEnabled || levelPriority[type] > levelPriority[logLevel]) return;

  const emoji = emojiMap[type]!;
  const style = styleMap[type]!;
  const timestamp = getTimestamp(options.locale);
  const category = options.category ? `${options.category.toUpperCase()}/` : '';
  const prefix = `%c[${timestamp}] ${emoji} ${category}${label.toUpperCase()}`;

  // ------------------------------
  // 1. 调用 tauri-plugin-log 输出日志（核心）
  // ------------------------------
  // 直接传递原始参数（tauri 支持多参数和对象格式化）
  switch (type) {
    case 'trace':
      trace(prefix, ...args);
      break;
    case 'debug':
      debug(prefix, ...args);
      break;
    case 'info':
      info(prefix, ...args);
      break;
    case 'warn':
      warn(prefix, ...args);
      break;
    case 'error':
      error(prefix, ...args);
      break;
  }
  // ------------------------------
  // 2. 保留原有 console 样式输出（开发环境专属）
  // ------------------------------
  if (import.meta.env.DEV) {
    const groupFn = options.collapse ? console.groupCollapsed : console.group;
    groupFn(prefix, style);

    // 遍历参数并输出（支持对象展开和表格）
    args.forEach(item => {
      const { formatted, isObject } = formatData(item);

      if (isObject && item != null) {
        // 对象/数组使用 console.table 展示
        if (Array.isArray(item)) {
          console.table(item);
        } else {
          console.table({ [label]: item }); // 包装为对象便于表格展示
        }
      } else {
        // 基础类型使用带样式的 console 输出
        console[type](
          `%c${formatted}`,
          'font-family: monospace; white-space: pre-wrap; padding-left: 8px;',
        );
      }
    });

    // 错误/调试日志附加堆栈跟踪
    if (type === 'error' || type === 'debug') {
      console.groupCollapsed(
        '%cStack Trace',
        'color: #6b7280; font-size: 0.8em;',
      );
      console.trace();
      console.groupEnd();
    }

    // 环境信息（模式、Node 版本）
    console.groupCollapsed(
      '%cEnvironment',
      'color: #6b7280; font-size: 0.8em;',
    );
    console.log(`%cMode: ${import.meta.env.MODE}`, 'color: #6b7280;');
    // const isNodeEnv = typeof window === 'undefined';
    // if (isNodeEnv) {
    //   if (process?.version) {
    //     console.log(`%cNode: ${process.version}`, 'color: #6b7280;');
    //   }
    // }
    console.groupEnd();

    console.groupEnd();
  }
}

// 快捷调用
export const Lg = {
  i: (label: string, ...args: unknown[]) => debugLog(label, 'info', args),
  w: (label: string, ...args: unknown[]) => debugLog(label, 'warn', args),
  e: (label: string, ...args: unknown[]) => debugLog(label, 'error', args),
  d: (label: string, ...args: unknown[]) => debugLog(label, 'debug', args),
};
