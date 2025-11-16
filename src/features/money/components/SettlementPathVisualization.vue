<script setup lang="ts">
import { Download, Maximize2, RotateCcw } from 'lucide-vue-next';
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
    const name = transfer?.from === id ? transfer.fromName : (transfer?.toName || '未知');

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

  if (!fromNode || !toNode) return '';

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

  if (!fromNode || !toNode) return { x: 0, y: 0 };

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

watch(() => props.transfers, () => {
  initializeNodes();
}, { deep: true });

// ==================== 生命周期 ====================

onMounted(() => {
  initializeNodes();
});
</script>

<template>
  <div class="settlement-path-visualization">
    <div ref="canvasRef" class="visualization-canvas">
      <!-- SVG图形容器 -->
      <svg
        class="path-svg"
        :width="canvasWidth"
        :height="canvasHeight"
        @mousedown="handleCanvasMouseDown"
        @mousemove="handleCanvasMouseMove"
        @mouseup="handleCanvasMouseUp"
      >
        <!-- 定义箭头标记 -->
        <defs>
          <marker
            id="arrowhead"
            markerWidth="10"
            markerHeight="10"
            refX="9"
            refY="3"
            orient="auto"
          >
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
            <circle
              r="30"
              :fill="node.color"
              class="node-circle"
            />

            <!-- 节点文字 -->
            <text
              class="node-initials"
              text-anchor="middle"
              dy="6"
            >
              {{ node.initials }}
            </text>

            <!-- 节点名称 -->
            <text
              class="node-name"
              text-anchor="middle"
              dy="50"
            >
              {{ node.name }}
            </text>

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
    <div class="control-panel">
      <div class="control-group">
        <label class="control-label">
          <input
            v-model="showLabels"
            type="checkbox"
            class="control-checkbox"
          >
          <span>显示金额标签</span>
        </label>

        <label class="control-label">
          <input
            v-model="showBalance"
            type="checkbox"
            class="control-checkbox"
          >
          <span>显示成员净额</span>
        </label>
      </div>

      <div class="control-group">
        <button class="control-btn" @click="resetLayout">
          <component :is="RotateCcw" class="w-4 h-4" />
          <span>重置布局</span>
        </button>

        <button class="control-btn" @click="centerView">
          <component :is="Maximize2" class="w-4 h-4" />
          <span>居中显示</span>
        </button>

        <button class="control-btn" @click="downloadImage">
          <component :is="Download" class="w-4 h-4" />
          <span>导出图片</span>
        </button>
      </div>
    </div>

    <!-- 图例 -->
    <div class="legend">
      <div class="legend-item">
        <div class="legend-icon legend-icon-positive" />
        <span>债权人（收款）</span>
      </div>
      <div class="legend-item">
        <div class="legend-icon legend-icon-negative" />
        <span>债务人（付款）</span>
      </div>
      <div class="legend-item">
        <div class="legend-icon legend-icon-neutral" />
        <span>平衡</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* 主容器 */
.settlement-path-visualization {
  background-color: #f9fafb;
  border-radius: 0.5rem;
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

:global(.dark) .settlement-path-visualization {
  background-color: #111827;
}

.visualization-canvas {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  overflow: hidden;
}

:global(.dark) .visualization-canvas {
  background-color: #1f2937;
}

/* SVG样式 */
.path-svg {
  display: block;
  width: 100%;
}

/* 连线样式 */
.connection-line {
  stroke: #3b82f6;
  stroke-width: 2;
  fill: none;
  transition: all 0.2s;
  stroke-dasharray: 0;
}

:global(.dark) .connection-line {
  stroke: #60a5fa;
}

.connection-active {
  stroke-width: 4;
  stroke: #2563eb;
  stroke-dasharray: 5, 5;
  animation: dash 1s linear infinite;
}

:global(.dark) .connection-active {
  stroke: #93c5fd;
}

@keyframes dash {
  to {
    stroke-dashoffset: -10;
  }
}

/* 标签样式 */
.label-bg {
  fill: #dbeafe;
  stroke: #3b82f6;
  stroke-width: 1;
}

:global(.dark) .label-bg {
  fill: rgba(30, 58, 138, 0.5);
  stroke: #60a5fa;
}

.label-text {
  fill: #1d4ed8;
  font-size: 0.75rem;
  font-weight: 700;
}

:global(.dark) .label-text {
  fill: #93c5fd;
}

/* 节点样式 */
.node-group {
  cursor: move;
  transition: all 0.2s;
}

.node-active .node-circle {
  stroke: #3b82f6;
  stroke-width: 4;
  filter: drop-shadow(0 0 8px rgba(59, 130, 246, 0.5));
}

:global(.dark) .node-active .node-circle {
  stroke: #60a5fa;
}

.node-circle {
  stroke: white;
  stroke-width: 2;
  transition: all 0.2s;
}

:global(.dark) .node-circle {
  stroke: #374151;
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

:global(.dark) .node-name {
  fill: #f3f4f6;
}

.node-balance {
  font-size: 0.75rem;
  font-weight: 700;
}

.balance-positive {
  fill: #059669;
}

:global(.dark) .balance-positive {
  fill: #34d399;
}

.balance-negative {
  fill: #dc2626;
}

:global(.dark) .balance-negative {
  fill: #f87171;
}

/* 控制面板 */
.control-panel {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

:global(.dark) .control-panel {
  background-color: #1f2937;
}

.control-group {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.control-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #374151;
  cursor: pointer;
}

:global(.dark) .control-label {
  color: #d1d5db;
}

.control-checkbox {
  width: 1rem;
  height: 1rem;
  border-radius: 0.25rem;
  border-color: #d1d5db;
  color: #2563eb;
}

:global(.dark) .control-checkbox {
  border-color: #4b5563;
}

.control-checkbox:focus {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}

.control-btn {
  padding: 0.5rem 0.75rem;
  background-color: #f3f4f6;
  color: #111827;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  transition: background-color 0.15s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.control-btn:hover {
  background-color: #e5e7eb;
}

:global(.dark) .control-btn {
  background-color: #374151;
  color: #f3f4f6;
}

:global(.dark) .control-btn:hover {
  background-color: #4b5563;
}

/* 图例 */
.legend {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1.5rem;
  padding: 0.75rem;
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

:global(.dark) .legend {
  background-color: #1f2937;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #374151;
}

:global(.dark) .legend-item {
  color: #d1d5db;
}

.legend-icon {
  width: 1rem;
  height: 1rem;
  border-radius: 9999px;
}

.legend-icon-positive {
  background-color: #10b981;
}

.legend-icon-negative {
  background-color: #ef4444;
}

.legend-icon-neutral {
  background-color: #9ca3af;
}

:global(.dark) .legend-icon-neutral {
  background-color: #4b5563;
}
</style>
