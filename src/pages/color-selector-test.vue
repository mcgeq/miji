<script setup lang="ts">
import { ref } from 'vue';
import ColorSelector from '@/components/common/ColorSelector.vue';

const basicColor = ref('#3B82F6');
const extendedColor = ref('#EF4444');
const categorizedColor = ref('#10B981');
const customColor = ref('#8B5CF6');
const fullFeatureColor = ref('#06B6D4');
const professionalColor = ref('#CECECE');
const realWorldColor = ref('#8B5CF6');
</script>

<template>
  <div class="color-selector-test">
    <h1>ColorSelector 组件测试</h1>

    <div class="test-section">
      <h2>基础用法（向后兼容）</h2>
      <p>当前选择: {{ basicColor }}</p>
      <ColorSelector v-model="basicColor" />
    </div>

    <div class="test-section">
      <h2>扩展颜色调色板</h2>
      <p>当前选择: {{ extendedColor }}</p>
      <ColorSelector v-model="extendedColor" :extended="true" />
    </div>

    <div class="test-section">
      <h2>带颜色分类</h2>
      <p>当前选择: {{ categorizedColor }}</p>
      <ColorSelector
        v-model="categorizedColor"
        :extended="true"
        :show-categories="true"
      />
    </div>

    <div class="test-section">
      <h2>自定义颜色选择器</h2>
      <p>当前选择: {{ customColor }}</p>
      <ColorSelector
        v-model="customColor"
        :show-custom-color="true"
      />
    </div>

    <div class="test-section">
      <h2>完整功能</h2>
      <p>当前选择: {{ fullFeatureColor }}</p>
      <ColorSelector
        v-model="fullFeatureColor"
        :extended="true"
        :show-categories="true"
        :show-custom-color="true"
      />
    </div>

    <div class="test-section">
      <h2>专业颜色选择器</h2>
      <p>当前选择: {{ professionalColor }}</p>
      <ColorSelector
        v-model="professionalColor"
        :professional="true"
      />
    </div>

    <div class="test-section">
      <h2>实际使用场景（账户/预算/提醒）</h2>
      <p>当前选择: {{ realWorldColor }}</p>
      <ColorSelector
        v-model="realWorldColor"
        :extended="true"
        :show-categories="true"
        :show-custom-color="true"
      />
    </div>
  </div>
</template>

<style scoped>
.color-selector-test {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

.test-section {
  margin-bottom: 3rem;
  padding: 1.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  background-color: #f9fafb;
}

.test-section h2 {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #374151;
}

.test-section p {
  margin-bottom: 1rem;
  font-weight: 500;
  color: #6b7280;
}
</style>
