<script setup lang="ts">
  // 快捷操作按钮组件
  interface Props {
    showAmountToggle?: boolean;
    amountHidden?: boolean;
  }

  withDefaults(defineProps<Props>(), {
    showAmountToggle: false,
    amountHidden: false,
  });

  const emit = defineEmits<{
    addAccount: [];
    addIncome: [];
    addExpense: [];
    addTransfer: [];
    addBudget: [];
    addReminder: [];
    toggleAmount: [];
  }>();
</script>

<template>
  <div
    class="flex flex-nowrap gap-1.5 md:gap-1.5 w-full items-center justify-center mb-1 overflow-x-auto scrollbar-none px-0.5 py-0.5"
  >
    <!-- 添加账户 -->
    <button
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 text-purple-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      title="添加账户"
      @click="emit('addAccount')"
    >
      <LucideCreditCard :size="12" />
    </button>

    <!-- 记录收入 -->
    <button
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 text-green-600 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      title="记录收入"
      @click="emit('addIncome')"
    >
      <LucidePlusCircle :size="12" />
    </button>

    <!-- 记录支出 -->
    <button
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 text-red-600 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      title="记录支出"
      @click="emit('addExpense')"
    >
      <LucideMinusCircle :size="12" />
    </button>

    <!-- 记录转账 -->
    <button
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 text-blue-600 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      title="记录转账"
      @click="emit('addTransfer')"
    >
      <LucideArrowRightLeft :size="12" />
    </button>

    <!-- 设置预算 -->
    <button
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 text-orange-600 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      title="设置预算"
      @click="emit('addBudget')"
    >
      <LucideTarget :size="12" />
    </button>

    <!-- 设置提醒 -->
    <button
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 text-yellow-600 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      title="设置提醒"
      @click="emit('addReminder')"
    >
      <LucideBell :size="12" />
    </button>

    <!-- 隐藏/显示金额 -->
    <button
      v-if="showAmountToggle"
      class="flex items-center justify-center p-3.5 md:p-4 rounded-xl border border-white dark:border-gray-700 cursor-pointer transition-all bg-gray-50 dark:bg-gray-800 shadow-sm shrink-0 min-w-12 h-12 md:min-w-12 md:h-12 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
      :class="amountHidden ? 'text-gray-500' : 'text-blue-600'"
      :title="amountHidden ? '显示金额' : '隐藏金额'"
      @click="emit('toggleAmount')"
    >
      <LucideEye v-if="!amountHidden" :size="12" />
      <LucideEyeOff v-else :size="12" />
    </button>
  </div>
</template>
