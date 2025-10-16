<script setup lang="ts">
import QuickMoneyActions from '@/components/common/QuickMoneyActions.vue';
import TodayPeriod from '@/components/common/TodayPeriod.vue';
import TodayTodos from '@/components/common/TodayTodos.vue';

// Tab 类型定义
type TabType = 'money' | 'period' | 'todos' | 'stats';

// 当前激活的tab
const activeTab = ref<TabType>('money');

// Money store
const moneyStore = useMoneyStore();

// Tab配置
const tabs = [
  { id: 'money' as TabType, label: '财务' },
  { id: 'period' as TabType, label: '经期' },
  { id: 'todos' as TabType, label: '待办' },
  { id: 'stats' as TabType, label: '统计' },
];

// 切换tab
function switchTab(tab: TabType) {
  activeTab.value = tab;
}

// 切换全局金额可见性
function toggleGlobalAmountVisibility() {
  moneyStore.toggleGlobalAmountVisibility();
}
</script>

<template>
  <div class="tab-container">
    <!-- Tab导航 -->
    <div class="tab-nav">
      <button
        v-for="tab in tabs"
        :key="tab.id"
        class="tab-btn"
        :class="{ active: activeTab === tab.id }"
        @click="switchTab(tab.id)"
      >
        <span class="tab-label">{{ tab.label }}</span>
      </button>
    </div>

    <!-- Tab内容 -->
    <div class="tab-content">
      <div v-if="activeTab === 'money'" class="tab-panel">
        <QuickMoneyActions
          :show-amount-toggle="true"
          @toggle-amount-visibility="toggleGlobalAmountVisibility"
        />
      </div>
      <div v-if="activeTab === 'period'" class="tab-panel">
        <TodayPeriod />
      </div>
      <div v-if="activeTab === 'todos'" class="tab-panel tab-panel-scrollable">
        <TodayTodos />
      </div>
      <div v-if="activeTab === 'stats'" class="tab-panel">
        <div class="stats-placeholder">
          <LucideBarChart3 class="placeholder-icon" />
          <h3>统计面板</h3>
          <p>这里将显示数据统计信息</p>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="postcss">
/* Tab容器 */
.tab-container {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-height: 0; /* 允许 flex 子项缩小 */
  box-sizing: border-box;
  overflow: hidden;
}

/* Tab导航 */
.tab-nav {
  display: flex;
  background: linear-gradient(135deg,
    var(--color-base-100) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, transparent) 100%);
  border-bottom: 1px solid color-mix(in oklch, var(--color-base-300) 50%, transparent);
  padding: 0.75rem;
  gap: 0.5rem;
  flex-shrink: 0;
  overflow-x: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
  justify-content: center;
  align-items: center;
  backdrop-filter: blur(12px);
  box-shadow: 0 2px 8px color-mix(in oklch, var(--color-neutral) 5%, transparent);
}

.tab-nav::-webkit-scrollbar {
  display: none;
}

.tab-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  padding: 0.75rem 1.25rem;
  background: transparent;
  border: none;
  border-radius: 0.875rem;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  color: var(--color-base-content);
  opacity: 0.7;
  min-width: 3.5rem;
  flex-shrink: 0;
  position: relative;
  flex: 0 0 auto;
  text-align: center;
  width: auto;
  font-weight: 500;
  backdrop-filter: blur(8px);
}

.tab-btn:hover {
  opacity: 1;
  background-color: color-mix(in oklch, var(--color-primary) 8%, transparent);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px color-mix(in oklch, var(--color-primary) 15%, transparent);
  color: var(--color-primary);
}

.tab-btn.active {
  opacity: 1;
  color: var(--color-primary);
  background: linear-gradient(135deg,
    color-mix(in oklch, var(--color-primary) 12%, transparent) 0%,
    color-mix(in oklch, var(--color-primary) 8%, transparent) 100%);
  font-weight: 600;
  box-shadow:
    0 4px 16px color-mix(in oklch, var(--color-primary) 20%, transparent),
    0 1px 3px color-mix(in oklch, var(--color-primary) 10%, transparent);
  transform: translateY(-1px);
  border: 1px solid color-mix(in oklch, var(--color-primary) 20%, transparent);
}

.tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: -0.25rem;
  left: 50%;
  transform: translateX(-50%);
  width: 2rem;
  height: 3px;
  background: linear-gradient(90deg,
    var(--color-primary) 0%,
    color-mix(in oklch, var(--color-primary) 80%, transparent) 100%);
  border-radius: 2px;
  box-shadow: 0 2px 4px color-mix(in oklch, var(--color-primary) 30%, transparent);
}

.tab-btn:hover .tab-icon {
  transform: scale(1.1);
}

.tab-label {
  font-size: 0.8rem;
  font-weight: 500;
  white-space: nowrap;
  text-align: center;
  width: 100%;
  display: block;
  line-height: 1.2;
  letter-spacing: 0.025em;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

/* Tab内容 */
.tab-content {
  flex: 1;
  overflow: hidden;
  position: relative;
  min-height: 0; /* 允许 flex 子项缩小 */
}

.tab-panel {
  width: 100%;
  height: 100%;
  padding: 0.75rem;
  box-sizing: border-box;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.tab-panel-scrollable {
  overflow-y: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.tab-panel-scrollable::-webkit-scrollbar {
  display: none;
}

/* 统计面板占位符 */
.stats-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  gap: 1rem;
  color: var(--color-base-content);
  opacity: 0.6;
  text-align: center;
}

.placeholder-icon {
  width: 3rem;
  height: 3rem;
  opacity: 0.5;
}

.stats-placeholder h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.stats-placeholder p {
  margin: 0;
  font-size: 0.875rem;
  opacity: 0.7;
}
</style>
