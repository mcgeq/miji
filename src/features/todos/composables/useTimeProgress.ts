/**
 * 基于时间的任务进度追踪
 * 用于可视化显示任务从创建到截止的时间进度
 */

export function useTimeProgress(createdAt: string | undefined, dueAt: string | undefined) {
  const currentTime = ref(Date.now());
  let timer: number | null = null;

  // 时间进度百分比 (0-100，null表示不显示)
  const timeProgress = computed(() => {
    if (!dueAt) return null;

    const due = new Date(dueAt).getTime();
    const now = currentTime.value;

    // 如果没有创建时间，使用当前时间作为起点
    const created = createdAt ? new Date(createdAt).getTime() : now;

    // 已过期
    if (now >= due) return 100;

    // 还未开始
    if (now <= created) return 0;

    // 计算进度
    const total = due - created;
    const elapsed = now - created;
    return Math.round((elapsed / total) * 100);
  });

  // 剩余时间文本
  const timeRemaining = computed(() => {
    if (!dueAt) return null;

    const due = new Date(dueAt).getTime();
    const now = currentTime.value;
    const diff = due - now;

    if (diff <= 0) return '已逾期';

    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(hours / 24);

    if (days > 7) return `${days}天`;
    if (days > 0) return `${days}天`;
    if (hours > 0) return `${hours}小时`;
    return `${Math.floor(diff / (1000 * 60))}分钟`;
  });

  // 紧急程度（用于边框颜色）
  const urgency = computed(() => {
    const progress = timeProgress.value;

    if (progress === null) return 'normal'; // 没有截止时间，正常状态
    if (progress >= 100) return 'overdue'; // 已逾期 - 红色
    if (progress >= 85) return 'critical'; // 非常紧急 - 深橙色
    if (progress >= 70) return 'urgent'; // 紧急 - 橙色
    if (progress >= 50) return 'warning'; // 警告 - 黄色
    return 'normal'; // 正常 - 绿色/蓝色
  });

  // 边框渐变样式
  const borderGradient = computed(() => {
    const progress = timeProgress.value;

    if (progress === null) return '';

    // 使用 conic-gradient 创建圆形进度指示
    // 从顶部开始，顺时针填充
    const angle = (progress / 100) * 360;

    let color: string;
    switch (urgency.value) {
      case 'overdue':
        color = 'rgb(239, 68, 68)'; // red-500
        break;
      case 'critical':
        color = 'rgb(249, 115, 22)'; // orange-500
        break;
      case 'urgent':
        color = 'rgb(251, 146, 60)'; // orange-400
        break;
      case 'warning':
        color = 'rgb(251, 191, 36)'; // yellow-400
        break;
      default:
        color = 'rgb(59, 130, 246)'; // blue-500
    }

    return `conic-gradient(from -90deg, ${color} ${angle}deg, transparent ${angle}deg)`;
  });

  // 箭头位置（0-360度，从顶部开始顺时针）
  const arrowRotation = computed(() => {
    const progress = timeProgress.value;
    if (progress === null) return 0;
    return (progress / 100) * 360;
  });

  // 启动自动更新
  onMounted(() => {
    // 初始更新
    currentTime.value = Date.now();

    // 每30分钟更新一次
    timer = window.setInterval(
      () => {
        currentTime.value = Date.now();
      },
      30 * 60 * 1000,
    ); // 30分钟
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });

  // 手动刷新方法
  const refresh = () => {
    currentTime.value = Date.now();
  };

  return {
    timeProgress,
    timeRemaining,
    urgency,
    borderGradient,
    arrowRotation,
    refresh,
  };
}
