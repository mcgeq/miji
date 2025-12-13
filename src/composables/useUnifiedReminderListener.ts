/**
 * 统一提醒事件监听器
 * @module composables/useUnifiedReminderListener
 * @description 监听所有模块（Todo、Money、Period）的提醒事件
 */

import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import { toast } from '@/utils/toast';

/**
 * Todo 提醒事件
 */
interface TodoReminderEvent {
  reminder_id: string;
  title: string;
  body: string;
  priority: string;
}

/**
 * 账单提醒事件
 */
interface BillReminderEvent {
  reminder_id: string;
  title: string;
  body: string;
  amount: number;
  currency: string;
}

/**
 * 经期提醒事件
 */
interface PeriodReminderEvent {
  reminder_id: string;
  title: string;
  body: string;
  reminder_type: 'period' | 'ovulation' | 'pms';
}

/**
 * 系统警报事件
 */
interface SystemAlertEvent {
  title: string;
  body: string;
  severity: 'info' | 'warning' | 'error';
}

/**
 * 事件处理器配置
 */
export interface ReminderEventHandlers {
  /** Todo 提醒触发 */
  onTodoReminder?: (event: TodoReminderEvent) => void;
  /** 账单提醒触发 */
  onBillReminder?: (event: BillReminderEvent) => void;
  /** 经期提醒触发 */
  onPeriodReminder?: (event: PeriodReminderEvent) => void;
  /** 排卵期提醒触发 */
  onOvulationReminder?: (event: PeriodReminderEvent) => void;
  /** PMS 提醒触发 */
  onPmsReminder?: (event: PeriodReminderEvent) => void;
  /** 系统警报 */
  onSystemAlert?: (event: SystemAlertEvent) => void;
  /** 显示通知 toast（默认启用） */
  showToast?: boolean;
}

/**
 * 统一提醒事件监听器
 *
 * @example
 * ```typescript
 * // 基础使用
 * useUnifiedReminderListener();
 *
 * // 自定义处理器
 * useUnifiedReminderListener({
 *   onBillReminder: (event) => {
 *     console.log('账单提醒:', event);
 *     refreshBillList();
 *   },
 *   showToast: true,
 * });
 * ```
 */
export function useUnifiedReminderListener(handlers?: ReminderEventHandlers) {
  const unlisteners: UnlistenFn[] = [];
  const showToast = handlers?.showToast ?? true;

  /**
   * 注册所有事件监听器
   */
  async function registerListeners() {
    try {
      // 1. 监听 Todo 提醒
      const unlistenTodo = await listen<TodoReminderEvent>('todo-reminder-fired', event => {
        const payload = event.payload;
        console.log('📝 Todo 提醒触发:', payload);

        if (showToast) {
          const priorityEmoji =
            {
              Urgent: '🚨',
              High: '⚠️',
              Medium: '📌',
              Low: '💡',
            }[payload.priority] || '📝';

          toast.info(`${priorityEmoji} ${payload.title}: ${payload.body}`);
        }

        handlers?.onTodoReminder?.(payload);
      });
      unlisteners.push(unlistenTodo);

      // 2. 监听账单提醒
      const unlistenBill = await listen<BillReminderEvent>('bil-reminder-fired', event => {
        const payload = event.payload;
        console.log('💰 账单提醒触发:', payload);

        if (showToast) {
          const amountText = `${payload.amount} ${payload.currency}`;
          toast.warning(`💰 ${payload.title} - ${amountText}: ${payload.body}`);
        }

        handlers?.onBillReminder?.(payload);
      });
      unlisteners.push(unlistenBill);

      // 3. 监听经期提醒
      const unlistenPeriod = await listen<PeriodReminderEvent>('period-reminder-fired', event => {
        const payload = event.payload;
        console.log('🌸 经期提醒触发:', payload);

        if (showToast) {
          const typeEmoji =
            {
              period: '🌸',
              ovulation: '🌺',
              pms: '💐',
            }[payload.reminder_type] || '🌸';

          toast.info(`${typeEmoji} ${payload.title}: ${payload.body}`);
        }

        handlers?.onPeriodReminder?.(payload);
      });
      unlisteners.push(unlistenPeriod);

      // 4. 监听排卵期提醒
      const unlistenOvulation = await listen<PeriodReminderEvent>(
        'ovulation-reminder-fired',
        event => {
          const payload = event.payload;
          console.log('🌺 排卵期提醒触发:', payload);

          if (showToast) {
            toast.info(`🌺 ${payload.title}: ${payload.body}`);
          }

          handlers?.onOvulationReminder?.(payload);
        },
      );
      unlisteners.push(unlistenOvulation);

      // 5. 监听 PMS 提醒
      const unlistenPms = await listen<PeriodReminderEvent>('pms-reminder-fired', event => {
        const payload = event.payload;
        console.log('💐 PMS 提醒触发:', payload);

        if (showToast) {
          toast.info(`💐 ${payload.title}: ${payload.body}`);
        }

        handlers?.onPmsReminder?.(payload);
      });
      unlisteners.push(unlistenPms);

      // 6. 监听系统警报
      const unlistenAlert = await listen<SystemAlertEvent>('system-alert', event => {
        const payload = event.payload;
        console.log('🔔 系统警报:', payload);

        if (showToast) {
          const severityConfig = {
            info: { fn: toast.info, emoji: 'ℹ️' },
            warning: { fn: toast.warning, emoji: '⚠️' },
            error: { fn: toast.error, emoji: '❌' },
          }[payload.severity] || { fn: toast.info, emoji: '🔔' };

          severityConfig.fn(`${severityConfig.emoji} ${payload.title}: ${payload.body}`);
        }

        handlers?.onSystemAlert?.(payload);
      });
      unlisteners.push(unlistenAlert);

      console.log('✅ 统一提醒监听器已注册，监听 6 种事件');
    } catch (error) {
      console.error('❌ 注册提醒监听器失败:', error);
    }
  }

  /**
   * 清理所有监听器
   */
  function cleanup() {
    unlisteners.forEach(unlisten => {
      try {
        unlisten();
      } catch (error) {
        console.error('清理监听器失败:', error);
      }
    });
    unlisteners.length = 0;
    console.log('🧹 统一提醒监听器已清理');
  }

  // 组件挂载时注册
  onMounted(() => {
    registerListeners();
  });

  // 组件卸载时清理
  onUnmounted(() => {
    cleanup();
  });

  return {
    registerListeners,
    cleanup,
  };
}

/**
 * 仅用于特定模块的监听器
 *
 * @example
 * ```typescript
 * // 仅监听账单提醒
 * useModuleReminderListener('bill', (event) => {
 *   refreshBillList();
 * });
 * ```
 */
export function useModuleReminderListener(
  module: 'todo' | 'bill' | 'period',
  handler: (event: any) => void,
) {
  const eventMap = {
    todo: 'todo-reminder-fired',
    bill: 'bil-reminder-fired',
    period: 'period-reminder-fired',
  };

  const eventName = eventMap[module];
  let unlisten: UnlistenFn | null = null;

  onMounted(async () => {
    unlisten = await listen(eventName, event => {
      console.log(`🔔 ${module} 提醒触发:`, event.payload);
      handler(event.payload);
    });
  });

  onUnmounted(() => {
    unlisten?.();
  });

  return { unlisten };
}
