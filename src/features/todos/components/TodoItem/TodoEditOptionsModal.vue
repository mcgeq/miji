<script setup lang="ts">
  import {
    Calendar,
    Clock,
    Gauge,
    ListTodo,
    MapPin,
    Pencil,
    Repeat,
    Sparkles,
  } from 'lucide-vue-next';
  import { Modal } from '@/components/ui';
  import type { Todo, TodoUpdate } from '@/schema/todos';
  import TodoEstimate from './TodoEstimate.vue';
  import TodoLocation from './TodoLocation.vue';
  import TodoProgress from './TodoProgress.vue';
  import TodoReminderSettings from './TodoReminderSettings.vue';
  import TodoSmartFeatures from './TodoSmartFeatures.vue';
  import TodoSubtasks from './TodoSubtasks.vue';

  defineProps<{
    show: boolean;
    todo: Todo;
    subtasks?: Todo[];
  }>();

  const emit = defineEmits<{
    editTitle: [];
    editDueDate: [];
    editRepeat: [];
    close: [];
    update: [update: TodoUpdate];
    createSubtask: [parentId: string, title: string];
    updateSubtask: [serialNum: string, partial: TodoUpdate];
    deleteSubtask: [serialNum: string];
  }>();

  const options = [
    { icon: Pencil, label: '编辑标题', action: 'editTitle' },
    { icon: Calendar, label: '设置日期', action: 'editDueDate' },
    { icon: Repeat, label: '设置重复', action: 'editRepeat' },
  ];

  function handleOption(action: string) {
    switch (action) {
      case 'editTitle':
        emit('editTitle');
        break;
      case 'editDueDate':
        emit('editDueDate');
        break;
      case 'editRepeat':
        emit('editRepeat');
        break;
    }
    emit('close');
  }

  function updateTodo(update: TodoUpdate) {
    emit('update', update);
  }

  function onCreateSubtask(parentId: string, title: string) {
    emit('createSubtask', parentId, title);
  }

  function onUpdateSubtask(serialNum: string, partial: TodoUpdate) {
    emit('updateSubtask', serialNum, partial);
  }

  function onDeleteSubtask(serialNum: string) {
    emit('deleteSubtask', serialNum);
  }
</script>

<template>
  <Modal :open="show" title="编辑任务" size="xl" :show-footer="false" @close="emit('close')">
    <div class="space-y-5">
      <!-- 基本编辑选项 -->
      <div class="bg-gray-50 dark:bg-gray-800/50 rounded-xl p-4">
        <h3
          class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2"
        >
          <Pencil class="w-4 h-4" />
          基本设置
        </h3>
        <div class="grid grid-cols-3 gap-2">
          <button
            v-for="option in options"
            :key="option.action"
            class="flex flex-col items-center gap-2 px-3 py-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-all"
            @click="handleOption(option.action)"
          >
            <component :is="option.icon" class="w-5 h-5 text-gray-600 dark:text-gray-400" />
            <span class="text-xs font-medium">{{ option.label }}</span>
          </button>
        </div>
      </div>

      <!-- 任务属性 - 两栏布局 -->
      <div class="bg-gray-50 dark:bg-gray-800/50 rounded-xl p-4">
        <h3
          class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2"
        >
          <Gauge class="w-4 h-4" />
          任务属性
        </h3>
        <div class="grid grid-cols-2 gap-4">
          <!-- 进度设置 -->
          <div
            class="bg-white dark:bg-gray-800 rounded-lg p-3 border border-gray-200 dark:border-gray-700"
          >
            <div class="flex items-center gap-2 mb-2">
              <Gauge class="w-3.5 h-3.5 text-blue-600 dark:text-blue-400" />
              <span class="text-xs font-medium text-gray-700 dark:text-gray-300">任务进度</span>
            </div>
            <div class="flex justify-center">
              <TodoProgress :progress="todo.progress" @update="updateTodo" />
            </div>
          </div>

          <!-- 时间估算 -->
          <div
            class="bg-white dark:bg-gray-800 rounded-lg p-3 border border-gray-200 dark:border-gray-700"
          >
            <div class="flex items-center gap-2 mb-2">
              <Clock class="w-3.5 h-3.5 text-orange-600 dark:text-orange-400" />
              <span class="text-xs font-medium text-gray-700 dark:text-gray-300">时间估算</span>
            </div>
            <div class="flex justify-center">
              <TodoEstimate :estimate-minutes="todo.estimateMinutes" @update="updateTodo" />
            </div>
          </div>

          <!-- 位置信息 -->
          <div
            class="bg-white dark:bg-gray-800 rounded-lg p-3 border border-gray-200 dark:border-gray-700"
          >
            <div class="flex items-center gap-2 mb-2">
              <MapPin class="w-3.5 h-3.5 text-green-600 dark:text-green-400" />
              <span class="text-xs font-medium text-gray-700 dark:text-gray-300">位置</span>
            </div>
            <div class="flex justify-center">
              <TodoLocation :location="todo.location" @update="updateTodo" />
            </div>
          </div>

          <!-- 提醒设置 -->
          <div
            class="bg-white dark:bg-gray-800 rounded-lg p-3 border border-gray-200 dark:border-gray-700"
          >
            <div class="flex items-center gap-2 mb-2">
              <Calendar class="w-3.5 h-3.5 text-purple-600 dark:text-purple-400" />
              <span class="text-xs font-medium text-gray-700 dark:text-gray-300">提醒设置</span>
            </div>
            <div class="flex justify-center">
              <TodoReminderSettings :todo="todo" @update="updateTodo" />
            </div>
          </div>
        </div>
      </div>

      <!-- 子任务管理 -->
      <div class="bg-gray-50 dark:bg-gray-800/50 rounded-xl p-4">
        <h3
          class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2"
        >
          <ListTodo class="w-4 h-4" />
          子任务管理
        </h3>
        <div
          class="bg-white dark:bg-gray-800 rounded-lg p-3 border border-gray-200 dark:border-gray-700"
        >
          <TodoSubtasks
            :todo="todo"
            :subtasks="subtasks"
            @create-subtask="onCreateSubtask"
            @update-subtask="onUpdateSubtask"
            @delete-subtask="onDeleteSubtask"
          />
        </div>
      </div>

      <!-- 智能功能 -->
      <div class="bg-gray-50 dark:bg-gray-800/50 rounded-xl p-4">
        <h3
          class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2"
        >
          <Sparkles class="w-4 h-4" />
          智能功能
        </h3>
        <div
          class="bg-white dark:bg-gray-800 rounded-lg p-3 border border-gray-200 dark:border-gray-700"
        >
          <TodoSmartFeatures :todo="todo" @update="updateTodo" />
        </div>
      </div>
    </div>
  </Modal>
</template>
