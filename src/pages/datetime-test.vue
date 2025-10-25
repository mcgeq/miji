<script setup lang="ts">
import { ref } from 'vue';
import DateTimePicker from '@/components/common/DateTimePicker.vue';

const selectedDateTime = ref<Date | null>(null);
const disabledDateTime = ref<Date | null>(new Date());
const mobileDateTime = ref<Date | null>(null);
</script>

<template>
  <div class="datetime-test-page">
    <h1>DateTimePicker 测试页面</h1>

    <div class="test-section">
      <h2>基本用法</h2>
      <div class="form-row">
        <label>选择日期时间：</label>
        <DateTimePicker
          v-model="selectedDateTime"
          format="yyyy-MM-dd HH:mm:ss"
          placeholder="请选择日期时间"
        />
      </div>
      <p>选中的值：{{ selectedDateTime }}</p>
    </div>

    <div class="test-section">
      <h2>禁用状态</h2>
      <div class="form-row">
        <label>禁用状态：</label>
        <DateTimePicker
          v-model="disabledDateTime"
          :disabled="true"
          format="yyyy-MM-dd HH:mm:ss"
        />
      </div>
    </div>

    <div class="test-section">
      <h2>移动端测试</h2>
      <div class="form-row">
        <label>移动端适配：</label>
        <DateTimePicker
          v-model="mobileDateTime"
          format="yyyy-MM-dd HH:mm:ss"
          placeholder="移动端测试"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.datetime-test-page {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

.test-section {
  margin-bottom: 2rem;
  padding: 1rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  background-color: var(--color-base-100);
}

.form-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
}

.form-row label {
  min-width: 120px;
  font-weight: 500;
}

h1 {
  color: var(--color-base-content);
  margin-bottom: 2rem;
}

h2 {
  color: var(--color-base-content);
  margin-bottom: 1rem;
}

p {
  color: var(--color-base-content-soft);
  font-size: 0.875rem;
}

/* 移动端适配 */
@media (max-width: 768px) {
  .form-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .form-row label {
    min-width: auto;
  }
}
</style>
