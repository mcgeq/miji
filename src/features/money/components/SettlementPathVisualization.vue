<script setup lang="ts">
  import { Download, Maximize2, RotateCcw } from 'lucide-vue-next';
  import Button from '@/components/ui/Button.vue';
  import Checkbox from '@/components/ui/Checkbox.vue';
  import { toast } from '@/utils/toast';

  // ==================== Props ====================

  interface TransferSuggestion {
    from: string;
    fromName: string;
    to: string;
    toName: string;
    amount: number;
    currency: string;
  }

  interface Props {
    transfers: TransferSuggestion[];
  }

  const props = defineProps<Props>();

  // ==================== 接口定义 ====================

  interface Node {
    id: string;
    name: string;
    initials: string;
    x: number;
    y: number;
    color: string;
    balance: number;
  }

  interface Position {
    x: number;
    y: number;
  }

  // ==================== 状态管理 ====================

  const canvasRef = ref<HTMLElement | null>(null);
  const canvasWidth = ref(800);
  const canvasHeight = ref(500);

  const nodes = ref<Node[]>([]);
  const showLabels = ref(true);
  const showBalance = ref(true);
  const activeNode = ref<number | null>(null);
  const activeTransfer = ref<number | null>(null);

  // 拖拽状态
  const dragging = ref(false);
  const dragNodeIndex = ref<number | null>(null);
  const dragStartPos = ref<Position>({ x: 0, y: 0 });

  // ==================== 计算属性 ====================

  // 所有成员列表
  const members = computed(() => {
    const memberSet = new Set<string>();
    props.transfers.forEach(transfer => {
      memberSet.add(transfer.from);
      memberSet.add(transfer.to);
    });
    return Array.from(memberSet);
  });

  // ==================== 方法 ====================

  // 初始化节点
  function initializeNodes() {
    const memberIds = members.value;
    const nodeCount = memberIds.length;

    // 计算成员的净额
    const balances: Record<string, number> = {};
    memberIds.forEach(id => {
      balances[id] = 0;
    });

    props.transfers.forEach(transfer => {
      balances[transfer.from] -= transfer.amount; // 付款人减少
      balances[transfer.to] += transfer.amount; // 收款人增加
    });

    // 创建节点
    nodes.value = memberIds.map((id, index) => {
      const transfer = props.transfers.find(t => t.from === id || t.to === id);
      const name = transfer?.from === id ? transfer.fromName : transfer?.toName || '未知';

      // 圆形布局
      const angle = (Math.PI * 2 * index) / nodeCount - Math.PI / 2;
      const radius = Math.min(canvasWidth.value, canvasHeight.value) * 0.35;
      const centerX = canvasWidth.value / 2;
      const centerY = canvasHeight.value / 2;

      return {
        id,
        name,
        initials: name.charAt(0).toUpperCase(),
        x: centerX + radius * Math.cos(angle),
        y: centerY + radius * Math.sin(angle),
        color: getNodeColor(balances[id]),
        balance: balances[id],
      };
    });
  }

  // 获取节点颜色
  function getNodeColor(balance: number): string {
    if (balance > 0) return '#10b981'; // 绿色 - 债权人
    if (balance < 0) return '#ef4444'; // 红色 - 债务人
    return '#6b7280'; // 灰色 - 平衡
  }

  // 获取连线路径
  function getConnectionPath(transfer: TransferSuggestion): string {
    const fromNode = nodes.value.find(n => n.id === transfer.from);
    const toNode = nodes.value.find(n => n.id === transfer.to);

    if (!(fromNode && toNode)) return '';

    // 计算节点边缘的连接点
    const angle = Math.atan2(toNode.y - fromNode.y, toNode.x - fromNode.x);
    const fromX = fromNode.x + 30 * Math.cos(angle);
    const fromY = fromNode.y + 30 * Math.sin(angle);
    const toX = toNode.x - 35 * Math.cos(angle); // 留出箭头空间
    const toY = toNode.y - 35 * Math.sin(angle);

    // 使用二次贝塞尔曲线
    const midX = (fromX + toX) / 2;
    const midY = (fromY + toY) / 2;

    // 计算控制点（增加曲度）
    const perpAngle = angle + Math.PI / 2;
    const curve = 30;
    const controlX = midX + curve * Math.cos(perpAngle);
    const controlY = midY + curve * Math.sin(perpAngle);

    return `M ${fromX},${fromY} Q ${controlX},${controlY} ${toX},${toY}`;
  }

  // 获取标签位置（在路径中点）
  function getLabelPosition(transfer: TransferSuggestion): Position {
    const fromNode = nodes.value.find(n => n.id === transfer.from);
    const toNode = nodes.value.find(n => n.id === transfer.to);

    if (!(fromNode && toNode)) return { x: 0, y: 0 };

    return {
      x: (fromNode.x + toNode.x) / 2,
      y: (fromNode.y + toNode.y) / 2,
    };
  }

  // 节点拖拽开始
  function handleNodeMouseDown(index: number, event: MouseEvent) {
    dragging.value = true;
    dragNodeIndex.value = index;
    dragStartPos.value = {
      x: event.clientX - nodes.value[index].x,
      y: event.clientY - nodes.value[index].y,
    };
  }

  // 画布拖拽
  function handleCanvasMouseDown() {
    // 可以添加画布整体拖拽逻辑
  }

  // 鼠标移动
  function handleCanvasMouseMove(event: MouseEvent) {
    if (dragging.value && dragNodeIndex.value !== null) {
      const rect = canvasRef.value?.getBoundingClientRect();
      if (!rect) return;

      const node = nodes.value[dragNodeIndex.value];
      node.x = event.clientX - rect.left - dragStartPos.value.x + node.x;
      node.y = event.clientY - rect.top - dragStartPos.value.y + node.y;

      dragStartPos.value = {
        x: event.clientX - node.x,
        y: event.clientY - node.y,
      };
    }
  }

  // 鼠标释放
  function handleCanvasMouseUp() {
    dragging.value = false;
    dragNodeIndex.value = null;
  }

  // 重置布局
  function resetLayout() {
    initializeNodes();
    toast.success('布局已重置');
  }

  // 居中显示
  function centerView() {
    initializeNodes();
    toast.success('已居中');
  }

  // 导出图片
  async function downloadImage() {
    try {
      // TODO: 实现SVG转PNG导出
      toast.info('导出功能开发中...');
    } catch (error) {
      console.error('导出失败:', error);
      toast.error('导出失败');
    }
  }

  // 格式化金额
  function formatAmount(amount: number): string {
    return amount.toFixed(2);
  }

  // ==================== 监听器 ====================

  watch(
    () => props.transfers,
    () => {
      initializeNodes();
    },
    { deep: true },
  );

  // ==================== 生命周期 ====================

  onMounted(() => {
    initializeNodes();
  });
</script>

<template>
  <div class="flex flex-col gap-4 p-4 bg-gray-50 dark:bg-gray-900 rounded-lg">
    <div ref="canvasRef" class="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden">
      <!-- SVG图形容器 -->
      <svg
        class="block w-full"
        :width="canvasWidth"
        :height="canvasHeight"
        @mousedown="handleCanvasMouseDown"
        @mousemove="handleCanvasMouseMove"
        @mouseup="handleCanvasMouseUp"
      >
        <!-- 定义箭头标记 -->
        <defs>
          <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
            <polygon points="0 0, 10 3, 0 6" fill="#3b82f6" />
          </marker>
        </defs>

        <!-- 绘制连线 -->
        <g class="connections-layer">
          <g
            v-for="(transfer, index) in transfers"
            :key="`connection-${index}`"
            class="connection-group"
          >
            <!-- 连线路径 -->
            <path
              :d="getConnectionPath(transfer)"
              class="connection-line"
              :class="{ 'connection-active': activeTransfer === index }"
              marker-end="url(#arrowhead)"
              @mouseenter="activeTransfer = index"
              @mouseleave="activeTransfer = null"
            />

            <!-- 金额标签 -->
            <g v-if="showLabels">
              <rect
                :x="getLabelPosition(transfer).x - 40"
                :y="getLabelPosition(transfer).y - 12"
                width="80"
                height="24"
                rx="12"
                class="label-bg"
              />
              <text
                :x="getLabelPosition(transfer).x"
                :y="getLabelPosition(transfer).y + 5"
                class="label-text"
                text-anchor="middle"
              >
                ¥{{ formatAmount(transfer.amount) }}
              </text>
            </g>
          </g>
        </g>

        <!-- 绘制节点 -->
        <g class="nodes-layer">
          <g
            v-for="(node, index) in nodes"
            :key="`node-${index}`"
            :transform="`translate(${node.x}, ${node.y})`"
            class="node-group"
            :class="{ 'node-active': activeNode === index }"
            @mouseenter="activeNode = index"
            @mouseleave="activeNode = null"
            @mousedown.stop="handleNodeMouseDown(index, $event)"
          >
            <!-- 节点圆形 -->
            <circle r="30" :fill="node.color" class="node-circle" />

            <!-- 节点文字 -->
            <text class="node-initials" text-anchor="middle" dy="6">{{ node.initials }}</text>

            <!-- 节点名称 -->
            <text class="node-name" text-anchor="middle" dy="50">{{ node.name }}</text>

            <!-- 节点净额 -->
            <text
              v-if="showBalance"
              class="node-balance"
              :class="{ 'balance-positive': node.balance > 0, 'balance-negative': node.balance < 0 }"
              text-anchor="middle"
              dy="68"
            >
              {{ node.balance > 0 ? '+' : '' }}¥{{ formatAmount(Math.abs(node.balance)) }}
            </text>
          </g>
        </g>
      </svg>
    </div>

    <!-- 控制面板 -->
    <div
      class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg shadow-sm"
    >
      <div class="flex flex-wrap items-center gap-4">
        <Checkbox v-model="showLabels" label="显示金额标签" size="sm" />

        <Checkbox v-model="showBalance" label="显示成员净额" size="sm" />
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <Button variant="secondary" size="sm" :icon="RotateCcw" @click="resetLayout">
          重置布局
        </Button>

        <Button variant="secondary" size="sm" :icon="Maximize2" @click="centerView">
          居中显示
        </Button>

        <Button variant="secondary" size="sm" :icon="Download" @click="downloadImage">
          导出图片
        </Button>
      </div>
    </div>

    <!-- 图例 -->
    <div
      class="flex flex-wrap items-center justify-center gap-6 p-3 bg-white dark:bg-gray-800 rounded-lg shadow-sm"
    >
      <div class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
        <div class="w-4 h-4 rounded-full bg-green-500" />
        <span>债权人（收款）</span>
      </div>
      <div class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
        <div class="w-4 h-4 rounded-full bg-red-500" />
        <span>债务人（付款）</span>
      </div>
      <div class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
        <div class="w-4 h-4 rounded-full bg-gray-400 dark:bg-gray-600" />
        <span>平衡</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
  /* SVG 连线样式 */
  .connection-line {
    stroke: #3b82f6;
    stroke-width: 2;
    fill: none;
    transition: all 0.2s;
    stroke-dasharray: 0;
  }

  .connection-active {
    stroke-width: 4;
    stroke: #2563eb;
    stroke-dasharray: 5, 5;
    animation: dash 1s linear infinite;
  }

  @keyframes dash {
    to {
      stroke-dashoffset: -10;
    }
  }

  /* SVG 标签样式 */
  .label-bg {
    fill: #dbeafe;
    stroke: #3b82f6;
    stroke-width: 1;
  }

  .label-text {
    fill: #1d4ed8;
    font-size: 0.75rem;
    font-weight: 700;
  }

  /* SVG 节点样式 */
  .node-group {
    cursor: move;
    transition: all 0.2s;
  }

  .node-circle {
    stroke: white;
    stroke-width: 2;
    transition: all 0.2s;
  }

  .node-active .node-circle {
    stroke: #3b82f6;
    stroke-width: 4;
    filter: drop-shadow(0 0 8px rgba(59, 130, 246, 0.5));
  }

  .node-initials {
    fill: white;
    font-size: 1rem;
    font-weight: 700;
  }

  .node-name {
    fill: #111827;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .node-balance {
    font-size: 0.75rem;
    font-weight: 700;
  }

  .balance-positive {
    fill: #059669;
  }

  .balance-negative {
    fill: #dc2626;
  }
</style>

<style>
  /* Dark mode overrides - non-scoped to avoid pseudo-class issues */
  .dark .connection-line {
    stroke: #60a5fa;
  }

  .dark .connection-active {
    stroke: #93c5fd;
  }

  .dark .label-bg {
    fill: rgba(30, 58, 138, 0.5);
    stroke: #60a5fa;
  }

  .dark .label-text {
    fill: #93c5fd;
  }

  .dark .node-circle {
    stroke: #374151;
  }

  .dark .node-active .node-circle {
    stroke: #60a5fa;
  }

  .dark .node-name {
    fill: #f3f4f6;
  }

  .dark .balance-positive {
    fill: #34d399;
  }

  .dark .balance-negative {
    fill: #f87171;
  }
</style>
