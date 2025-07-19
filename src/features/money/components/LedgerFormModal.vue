<template>
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[60]"
    @click.self="$emit('close')">
    <div class="bg-white rounded-lg w-full max-w-2xl max-h-[90vh] overflow-hidden shadow-2xl">
      <!-- 头部 -->
      <div class="flex justify-between items-center p-6 border-b border-gray-200 bg-gray-50">
        <h2 class="text-xl font-bold text-gray-800">
          {{ isEdit ? t('familyLedger.editLedger') : t('familyLedger.createNewLedger') }}
        </h2>
        <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 transition-colors">
          <X class="w-6 h-6" />
        </button>
      </div>

      <!-- 表单内容 -->
      <div class="p-6 overflow-y-auto max-h-[calc(90vh-160px)]">
        <form @submit.prevent="handleSubmit" class="space-y-6">
          <!-- 基本信息 -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900 border-b border-gray-200 pb-2">{{ t('familyLedger.basicInfo')
            }}</h3>

            <!-- 账本名称 -->
            <div>
              <label for="name" class="block text-sm font-medium text-gray-700 mb-2">
                {{ t('familyLedger.ledgerName') }} <span class="text-red-500">*</span>
              </label>
              <input id="name" v-model="form.name" type="text" required maxlength="50"
                :placeholder="t('common.placeholders.enterName')"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              <p class="text-xs text-gray-500 mt-1">{{ form.name.length }}/50</p>
            </div>

            <!-- 账本描述 -->
            <div>
              <label for="description" class="block text-sm font-medium text-gray-700 mb-2">
                {{ t('familyLedger.ledgerDescription') }}
              </label>
              <textarea id="description" v-model="form.description" rows="3" maxlength="200"
                :placeholder="t('common.placeholders.enterDescription')"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"></textarea>
              <p class="text-xs text-gray-500 mt-1">{{ form.description.length }}/200</p>
            </div>
          </div>

          <!-- 货币设置 -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium text-gray-900 border-b border-gray-200 pb-2">{{
              t('familyLedger.currencySettings') }}</h3>

            <div>
              <label for="currency" class="block text-sm font-medium text-gray-700 mb-2">
                {{ t('financial.baseCurrency') }} <span class="text-red-500">*</span>
              </label>
              <select id="currency" v-model="form.baseCurrency.code" @change="updateCurrencyInfo" required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="">{{ t('messages.selectCurrency') }}</option>
                <option v-for="currency in availableCurrencies" :key="currency.code" :value="currency.code">
                  {{ currency.symbol }} {{ currency.code }} - {{ currency.nameZh }}
                </option>
              </select>
              <p class="text-xs text-gray-500 mt-1">
                {{ t('messages.selectedAsDefault') }}
              </p>
            </div>
          </div>

          <!-- 成员管理 -->
          <div class="space-y-4">
            <div class="flex justify-between items-center border-b border-gray-200 pb-2">
              <h3 class="text-lg font-medium text-gray-900">{{ t('familyLedger.members') }}</h3>
              <button type="button" @click="addMember"
                class="flex items-center gap-1 text-sm text-blue-600 hover:text-blue-700">
                <Plus class="w-4 h-4" />
                {{ t('familyLedger.addMember') }}
              </button>
            </div>

            <div v-if="form.members.length === 0" class="text-center py-6 text-gray-500">
              <Users class="w-12 h-12 mx-auto mb-2 text-gray-300" />
              <p>{{ t('familyLedger.noMembers') }}</p>
              <p class="text-sm">{{ t('familyLedger.clickAddMember') }}</p>
            </div>

            <div v-else class="space-y-3">
              <div v-for="(member, index) in form.members" :key="index"
                class="flex items-center gap-3 p-3 border border-gray-200 rounded-md">
                <div class="flex-1">
                  <input v-model="member.name" type="text" :placeholder="t('familyLedger.memberName')" required
                    maxlength="20"
                    class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:border-blue-500" />
                </div>
                <div class="flex-1">
                  <select v-model="member.role"
                    class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:border-blue-500">
                    <option value="Owner">{{ t('roles.owner') }}</option>
                    <option value="Admin">{{ t('roles.admin') }}</option>
                    <option value="Member">{{ t('roles.member') }}</option>
                    <option value="Viewer">{{ t('roles.viewer') }}</option>
                  </select>
                </div>
                <div class="flex items-center gap-2">
                  <label class="flex items-center gap-1 text-sm text-gray-600">
                    <input v-model="member.isPrimary" type="checkbox" class="rounded border-gray-300" />
                    {{ t('familyLedger.primaryMember') }}
                  </label>
                  <button type="button" @click="removeMember(index)" class="text-red-500 hover:text-red-700 p-1"
                    :disabled="form.members.length === 1">
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>

      <!-- 底部操作栏 -->
      <div class="flex justify-between items-center p-6 border-t border-gray-200 bg-gray-50">
        <div class="text-sm text-gray-600">
          <span v-if="isEdit">{{ t('familyLedger.editLedger') }}</span>
          <span v-else>{{ t('familyLedger.createNewLedger') }}</span>
        </div>
        <div class="flex gap-3">
          <button type="button" @click="$emit('close')"
            class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors">
            {{ t('common.actions.cancel') }}
          </button>
          <button @click="handleSubmit" :disabled="!isFormValid || saving"
            class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
            <span v-if="saving">{{ t('common.misc.saving') }}</span>
            <span v-else>{{ isEdit ? t('common.actions.update') : t('common.actions.create') }}</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Plus, Trash2, Users, X } from 'lucide-vue-next';
import { computed, onMounted, ref } from 'vue';
import { FamilyLedger } from '@/schema/money';

interface Props {
  ledger?: FamilyLedger | null;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  close: [];
  save: [ledger: FamilyLedger];
}>();

// 假设 t 函数已经通过 useI18n 或类似方式注入
const { t } = useI18n();

const saving = ref(false);
const isEdit = computed(() => !!props.ledger);

// 可用货币列表
const availableCurrencies = [
  { code: 'CNY', symbol: '¥', nameZh: '人民币', nameEn: 'Chinese Yuan' },
  {
    code: 'USD', symbol: '$', nameZh: '美元', nameEn: 'US Dollar'
  },
  { code: 'EUR', symbol: '€', nameZh: '欧元', nameEn: 'Euro' },
  { code: 'JPY', symbol: '¥', nameZh: '日元', nameEn: 'Japanese Yen' },
  { code: 'GBP', symbol: '£', nameZh: '英镑', nameEn: 'British Pound' },
  { code: 'HKD', symbol: 'HK', nameZh: '港币', nameEn: 'Hong Kong Dollar' },
];

// 表单数据
const form = ref({
  serialNum: '',
  name: '',
  description: '',
  baseCurrency: {
    code: 'CNY',
    symbol: '¥',
    nameZh: '人民币',
    nameEn: 'Chinese Yuan',
  },
  members: [] as Array<{
    serialNum: string;
    name: string;
    role: 'Owner' | 'Admin' | 'Member' | 'Viewer';
    isPrimary: boolean;
    permissions: string;
    createdAt: string;
  }>,
  createdAt: '',
  updatedAt: '',
});

// 表单验证
const isFormValid = computed(() => {
  return (
    form.value.name.trim().length > 0 &&
    form.value.baseCurrency.code &&
    form.value.members.length > 0 &&
    form.value.members.every((member) => member.name.trim().length > 0) &&
    form.value.members.some((member) => member.isPrimary) // 至少有一个主要成员
  );
});

// 更新货币信息
const updateCurrencyInfo = () => {
  const selected = availableCurrencies.find(
    (c) => c.code === form.value.baseCurrency.code,
  );
  if (selected) {
    form.value.baseCurrency = { ...selected };
  }
};

// 添加成员
const addMember = () => {
  const newMember = {
    serialNum: `temp_${Date.now()}`, // 临时ID，保存时会由后端生成
    name: '',
    role: 'Member' as const,
    isPrimary: form.value.members.length === 0, // 第一个成员默认为主要成员
    permissions: '',
    createdAt: new Date().toISOString(),
  };
  form.value.members.push(newMember);
};

// 删除成员
const removeMember = (index: number) => {
  if (form.value.members.length === 1) {
    // 使用 toast 显示警告，实际项目中需要替换为你的 toast 实现
    // toast.warning(t('messages.atLeastOneMember'));
    console.warn('至少需要保留一个家庭成员');
    return;
  }

  const memberToRemove = form.value.members[index];
  form.value.members.splice(index, 1);

  // 如果删除的是主要成员，且还有其他成员，则将第一个成员设为主要成员
  if (memberToRemove.isPrimary && form.value.members.length > 0) {
    form.value.members[0].isPrimary = true;
  }
};

// 提交表单
const handleSubmit = async () => {
  if (!isFormValid.value) {
    // toast.warning(t('messages.pleaseFillRequired'));
    console.warn('请完善必填信息');
    return;
  }

  // 确保只有一个主要成员
  const primaryMembers = form.value.members.filter((m) => m.isPrimary);
  if (primaryMembers.length === 0) {
    // toast.warning(t('messages.atLeastOnePrimary'));
    console.warn('请至少指定一个主要成员');
    return;
  }
  if (primaryMembers.length > 1) {
    // toast.warning(t('messages.onlyOnePrimary'));
    console.warn('只能有一个主要成员');
    return;
  }

  saving.value = true;
  try {
    const ledgerData: FamilyLedger = {
      ...form.value,
      serialNum: isEdit.value ? form.value.serialNum : `ledger_${Date.now()}`,
      createdAt: isEdit.value ? form.value.createdAt : new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // TODO: 调用实际 API
    if (isEdit.value) {
      // await familyLedgerStore.updateLedger(ledgerData);
      console.log('更新账本:', ledgerData);
    } else {
      // await familyLedgerStore.createLedger(ledgerData);
      console.log('创建账本:', ledgerData);
    }

    emit('save', ledgerData);
  } catch (error) {
    // toast.error(isEdit.value ? t('familyLedger.updateFailed') : t('familyLedger.createFailed'));
    console.error(isEdit.value ? '更新账本失败' : '创建账本失败');
  } finally {
    saving.value = false;
  }
};

// 初始化表单数据
const initializeForm = () => {
  if (props.ledger) {
    // 编辑模式：填充现有数据
    form.value = {
      serialNum: props.ledger.serialNum || '',
      name: props.ledger.name || '',
      description: props.ledger.description || '',
      baseCurrency: props.ledger.baseCurrency || {
        code: 'CNY',
        symbol: '¥',
        nameZh: '人民币',
        nameEn: 'Chinese Yuan',
      },
      members: props.ledger.members ? [...props.ledger.members] : [],
      createdAt: props.ledger.createdAt || '',
      updatedAt: props.ledger.updatedAt || '',
    };
  } else {
    // 创建模式：默认值
    form.value = {
      serialNum: '',
      name: '',
      description: '',
      baseCurrency: {
        code: 'CNY',
        symbol: '¥',
        nameZh: '人民币',
        nameEn: 'Chinese Yuan',
      },
      members: [],
      createdAt: '',
      updatedAt: '',
    };

    // 自动添加一个默认成员
    addMember();
  }
};

onMounted(() => {
  initializeForm();
});
</script>

<style scoped lang="postcss">
/* 自定义滚动条样式 */
.overflow-y-auto::-webkit-scrollbar {
  width: 6px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 3px;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 3px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: #a1a1a1;
}

/* 表单样式优化 */
.form-section {
  @apply space-y-4;
}

.form-section h3 {
  @apply text-lg font-medium text-gray-900 border-b border-gray-200 pb-2;
}

.form-field {
  @apply space-y-2;
}

.form-label {
  @apply block text-sm font-medium text-gray-700;
}

.form-input {
  @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500;
}

.form-help {
  @apply text-xs text-gray-500;
}

/* 成员卡片样式 */
.member-card {
  @apply flex items-center gap-3 p-3 border border-gray-200 rounded-md hover:border-gray-300 transition-colors;
}

.member-card input,
.member-card select {
  @apply px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:border-blue-500;
}

/* 按钮样式 */
.btn-primary {
  @apply px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed;
}

.btn-secondary {
  @apply px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors;
}

.btn-danger {
  @apply text-red-500 hover:text-red-700 p-1;
}
</style>