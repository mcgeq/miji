<template>
  <div v-if="showAccount" class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
    <div class="bg-white rounded-lg p-6 w-full max-w-md mx-4">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ editingAccount ? '编辑账户' : '添加账户' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveAccount">
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">账户名称</label>
          <input
            v-model="form.name"
            type="text"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="请输入账户名称"
          />
        </div>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">账户类型</label>
          <select
            v-model="form.type"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">请选择账户类型</option>
            <option value="cash">现金</option>
            <option value="bank">银行卡</option>
            <option value="credit">信用卡</option>
            <option value="alipay">支付宝</option>
            <option value="wechat">微信</option>
            <option value="investment">投资账户</option>
          </select>
        </div>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">初始余额</label>
          <input
            v-model.number="form.balance"
            type="number"
            step="0.01"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="0.00"
          />
        </div>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">颜色</label>
          <div class="flex gap-2">
            <div
              v-for="color in colors"
              :key="color"
              @click="form.color = color"
              :class="[
                'w-8 h-8 rounded-full cursor-pointer border-2',
                form.color === color ? 'border-gray-800' : 'border-gray-300'
              ]"
              :style="{ backgroundColor: color }"
            ></div>
          </div>
        </div>
        
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">描述</label>
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="账户描述（可选）"
          ></textarea>
        </div>
        
        <div class="flex justify-end space-x-3">
          <button
            type="button"
            @click="closeModal"
            class="px-4 py-2 text-gray-600 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            取消
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600"
          >
            {{ editingAccount ? '更新' : '添加' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
export default {
  name: 'AccountModal',
  props: {
    isOpen: {
      type: Boolean,
      default: false,
    },
    editingAccount: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      form: {
        name: '',
        type: '',
        balance: 0,
        color: '#3B82F6',
        description: '',
      },
      colors: [
        '#3B82F6',
        '#EF4444',
        '#10B981',
        '#F59E0B',
        '#8B5CF6',
        '#F97316',
        '#06B6D4',
        '#84CC16',
        '#EC4899',
        '#6B7280',
      ],
    };
  },
  watch: {
    isOpen(newVal) {
      if (newVal) {
        this.resetForm();
      }
    },
    editingAccount: {
      handler(newVal) {
        if (newVal) {
          this.form = { ...newVal };
        }
      },
      immediate: true,
    },
  },
  methods: {
    resetForm() {
      if (this.editingAccount) {
        this.form = { ...this.editingAccount };
      } else {
        this.form = {
          name: '',
          type: '',
          balance: 0,
          color: '#3B82F6',
          description: '',
        };
      }
    },
    closeModal() {
      this.$emit('close');
    },
    saveAccount() {
      const accountData = {
        ...this.form,
        id: this.editingAccount?.id || Date.now(),
        createdAt: this.editingAccount?.createdAt || new Date().toISOString(),
      };

      this.$emit('save', accountData);
      this.closeModal();
    },
  },
};
</script>

<style scoped>
/* 自定义样式 */
</style>
