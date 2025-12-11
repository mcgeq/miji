import { BarChart, LineChart, PieChart, RadarChart } from 'echarts/charts';
import {
  GridComponent,
  LegendComponent,
  RadarComponent,
  TitleComponent,
  TooltipComponent,
} from 'echarts/components';
// 使用更简单的ECharts配置 - 按需导入减少包大小
import { init, use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';

// Extend Window interface for echarts
declare global {
  interface Window {
    echarts?: unknown;
  }
}

// 注册必要的组件
use([
  CanvasRenderer,
  BarChart,
  LineChart,
  PieChart,
  RadarChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  RadarComponent,
]);

// 创建echarts实例
const echarts = { init, use };

// 初始化ECharts
export function initECharts() {
  // 确保ECharts已经正确初始化
  if (typeof window !== 'undefined') {
    // 禁用 ECharts 的实例销毁警告
    try {
      // 设置全局配置禁用警告
      if (window.echarts) {
        // 重写 console.warn 来过滤 ECharts 相关的警告
        const originalWarn = console.warn;
        console.warn = (...args) => {
          const message = args.join(' ');
          if (message.includes('[ECharts] Instance') && message.includes('has been disposed')) {
            return; // 忽略这个特定的警告
          }
          originalWarn.apply(console, args);
        };
      }
    } catch (error) {
      console.warn('设置 ECharts 配置时出错:', error);
    }
    return echarts;
  }
  return echarts;
}

// 默认主题配置
export const defaultTheme = {
  color: [
    '#3b82f6', // 蓝色
    '#10b981', // 绿色
    '#f59e0b', // 黄色
    '#ef4444', // 红色
    '#8b5cf6', // 紫色
    '#06b6d4', // 青色
    '#84cc16', // 青绿色
    '#f97316', // 橙色
    '#ec4899', // 粉色
    '#6366f1', // 靛蓝色
  ],
  backgroundColor: 'transparent',
  textStyle: {
    fontFamily:
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    fontSize: 12,
    color: '#374151',
  },
  title: {
    textStyle: {
      fontSize: 16,
      fontWeight: 'bold',
      color: '#111827',
    },
    subtextStyle: {
      fontSize: 12,
      color: '#6b7280',
    },
  },
  legend: {
    textStyle: {
      color: '#374151',
    },
  },
  tooltip: {
    backgroundColor: 'rgba(0, 0, 0, 0.8)',
    borderColor: 'transparent',
    textStyle: {
      color: '#ffffff',
    },
  },
  categoryAxis: {
    axisLine: {
      lineStyle: {
        color: '#d1d5db',
      },
    },
    axisTick: {
      lineStyle: {
        color: '#d1d5db',
      },
    },
    axisLabel: {
      color: '#6b7280',
    },
    splitLine: {
      lineStyle: {
        color: '#f3f4f6',
      },
    },
  },
  valueAxis: {
    axisLine: {
      lineStyle: {
        color: '#d1d5db',
      },
    },
    axisTick: {
      lineStyle: {
        color: '#d1d5db',
      },
    },
    axisLabel: {
      color: '#6b7280',
    },
    splitLine: {
      lineStyle: {
        color: '#f3f4f6',
      },
    },
  },
};

// 深色主题配置
export const darkTheme = {
  color: [
    '#60a5fa', // 浅蓝色
    '#34d399', // 浅绿色
    '#fbbf24', // 浅黄色
    '#f87171', // 浅红色
    '#a78bfa', // 浅紫色
    '#22d3ee', // 浅青色
    '#a3e635', // 浅青绿色
    '#fb923c', // 浅橙色
    '#f472b6', // 浅粉色
    '#818cf8', // 浅靛蓝色
  ],
  backgroundColor: 'transparent',
  textStyle: {
    fontFamily:
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    fontSize: 12,
    color: '#d1d5db',
  },
  title: {
    textStyle: {
      fontSize: 16,
      fontWeight: 'bold',
      color: '#f9fafb',
    },
    subtextStyle: {
      fontSize: 12,
      color: '#9ca3af',
    },
  },
  legend: {
    textStyle: {
      color: '#d1d5db',
    },
  },
  tooltip: {
    backgroundColor: 'rgba(0, 0, 0, 0.9)',
    borderColor: 'transparent',
    textStyle: {
      color: '#ffffff',
    },
  },
  categoryAxis: {
    axisLine: {
      lineStyle: {
        color: '#4b5563',
      },
    },
    axisTick: {
      lineStyle: {
        color: '#4b5563',
      },
    },
    axisLabel: {
      color: '#9ca3af',
    },
    splitLine: {
      lineStyle: {
        color: '#374151',
      },
    },
  },
  valueAxis: {
    axisLine: {
      lineStyle: {
        color: '#4b5563',
      },
    },
    axisTick: {
      lineStyle: {
        color: '#4b5563',
      },
    },
    axisLabel: {
      color: '#9ca3af',
    },
    splitLine: {
      lineStyle: {
        color: '#374151',
      },
    },
  },
};

// 工具函数
export const chartUtils = {
  // 格式化金额
  formatAmount: (value: number): string => {
    if (value >= 100000000) {
      return `${(value / 100000000).toFixed(1)}亿`;
    }
    if (value >= 10000) {
      return `${(value / 10000).toFixed(1)}万`;
    }
    if (value >= 1000) {
      return `${(value / 1000).toFixed(1)}千`;
    }
    return value.toFixed(0);
  },

  // 格式化百分比
  formatPercentage: (value: number): string => {
    return `${value.toFixed(1)}%`;
  },

  // 获取颜色
  getColor: (index: number, colors: string[] = defaultTheme.color): string => {
    return colors[index % colors.length];
  },

  // 创建渐变色
  createGradient: (color: string, direction: 'vertical' | 'horizontal' = 'vertical') => {
    return {
      type: 'linear',
      x: direction === 'horizontal' ? 0 : 0,
      y: direction === 'horizontal' ? 0 : 0,
      x2: direction === 'horizontal' ? 1 : 0,
      y2: direction === 'horizontal' ? 0 : 1,
      colorStops: [
        { offset: 0, color },
        { offset: 1, color: `${color}20` },
      ],
    };
  },
};
