<script setup lang="ts">
/**
 * FormRow 使用示例
 *
 * 展示新版 FormRow 的各种用法
 */

import { ref } from 'vue';
import { Checkbox, FormRow, Input, Select, Switch, Textarea } from '@/components/ui';

const form = ref({
  name: '',
  email: '',
  category: '',
  description: '',
  notifications: false,
  terms: false,
});

const categoryOptions = [
  { value: '1', label: '类别 1' },
  { value: '2', label: '类别 2' },
  { value: '3', label: '类别 3' },
];

const errors = ref({
  name: '',
  email: '',
});

function validateName() {
  if (!form.value.name) {
    errors.value.name = '名称不能为空';
  } else {
    errors.value.name = '';
  }
}
</script>

<template>
  <div class="p-8 max-w-2xl mx-auto space-y-8">
    <div>
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
        FormRow 组件示例
      </h1>
      <p class="text-gray-600 dark:text-gray-400">
        展示新版 FormRow 的各种用法
      </p>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow space-y-6">
      <h2 class="text-xl font-semibold text-gray-900 dark:text-white">
        基础表单
      </h2>

      <!-- 基础用法 -->
      <FormRow label="姓名" required :error="errors.name">
        <Input
          v-model="form.name"
          placeholder="请输入姓名"
          @blur="validateName"
        />
      </FormRow>

      <!-- 带帮助文本 -->
      <FormRow
        label="邮箱"
        required
        help-text="我们将向此邮箱发送验证邮件"
        :error="errors.email"
      >
        <Input
          v-model="form.email"
          type="email"
          placeholder="example@email.com"
        />
      </FormRow>

      <!-- 可选字段 -->
      <FormRow label="分类" optional>
        <Select
          v-model="form.category"
          :options="categoryOptions"
          placeholder="请选择分类"
        />
      </FormRow>

      <!-- 多行文本 -->
      <FormRow label="描述" full-width>
        <Textarea
          v-model="form.description"
          placeholder="请输入描述..."
          rows="4"
          max-length="200"
          show-count
        />
      </FormRow>

      <!-- 开关 -->
      <FormRow label="通知">
        <Switch
          v-model="form.notifications"
          label="接收邮件通知"
          description="开启后将接收重要更新通知"
        />
      </FormRow>

      <!-- 复选框 -->
      <FormRow label="条款">
        <Checkbox
          v-model="form.terms"
          label="我已阅读并同意服务条款和隐私政策"
        />
      </FormRow>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow space-y-6">
      <h2 class="text-xl font-semibold text-gray-900 dark:text-white">
        高级用法
      </h2>

      <!-- 自定义标签宽度 -->
      <FormRow label="账户名称" label-width="w-32">
        <Input placeholder="自定义标签宽度" />
      </FormRow>

      <!-- 标签右对齐 -->
      <FormRow label="金额" label-width="w-32" label-align="right">
        <Input type="number" placeholder="标签右对齐" />
      </FormRow>

      <!-- 全宽模式 -->
      <FormRow label="详细地址" full-width>
        <Input placeholder="全宽模式 - 标签和输入框各占一行" />
      </FormRow>
    </div>

    <!-- 表单数据预览 -->
    <div class="bg-gray-100 dark:bg-gray-900 rounded-lg p-4">
      <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
        表单数据:
      </h3>
      <pre class="text-xs text-gray-600 dark:text-gray-400">{{ form }}</pre>
    </div>
  </div>
</template>
