<script setup lang="ts">
  import ColorSelector from '@/components/common/ColorSelector.vue';
  import TagSelector from '@/components/common/TagSelector.vue';
  import Input from '@/components/ui/Input.vue';
  import Modal from '@/components/ui/Modal.vue';
  import Textarea from '@/components/ui/Textarea.vue';
  import type { Projects } from '@/schema/todos';
  import type { ProjectUpdate } from '@/services/projects';
  import { ProjectTagsDb } from '@/services/projectTags';

  interface Props {
    open: boolean;
    project: Projects | null;
  }

  const props = defineProps<Props>();

  const emit = defineEmits<{
    close: [];
    confirm: [serialNum: string, data: ProjectUpdate, tags: string[]];
  }>();

  const formData = ref<ProjectUpdate>({
    name: '',
    description: null,
    color: '#3b82f6',
    isArchived: false,
  });

  // 选中的标签
  const selectedTags = ref<string[]>([]);
  const loading = ref(false);

  // 颜色选择器专用的计算属性
  const projectColor = computed({
    get: () => formData.value.color || '#3b82f6',
    set: (value: string) => {
      formData.value.color = value;
    },
  });

  // 描述字段的计算属性（处理 null 值）
  const projectDescription = computed({
    get: () => formData.value.description || '',
    set: (value: string) => {
      formData.value.description = value || null;
    },
  });

  // 验证表单
  const isValid = computed(() => {
    return formData.value.name && formData.value.name.trim().length > 0;
  });

  // 加载项目数据和标签
  async function loadProjectData() {
    if (!props.project) return;

    loading.value = true;
    try {
      // 填充表单数据
      formData.value = {
        name: props.project.name,
        description: props.project.description,
        color: props.project.color,
        isArchived: props.project.isArchived,
      };

      // 加载项目标签
      const tags = await ProjectTagsDb.getProjectTags(props.project.serialNum);
      selectedTags.value = tags.map(t => t.serialNum);
    } catch (error) {
      console.error('加载项目数据失败:', error);
    } finally {
      loading.value = false;
    }
  }

  // 重置表单
  const resetForm = () => {
    formData.value = {
      name: '',
      description: null,
      color: '#3b82f6',
      isArchived: false,
    };
    selectedTags.value = [];
  };

  // 处理关闭
  const handleClose = () => {
    resetForm();
    emit('close');
  };

  // 处理确认
  const handleConfirm = () => {
    if (!(isValid.value && props.project)) return;

    emit('confirm', props.project.serialNum, formData.value, selectedTags.value);
    resetForm();
  };

  // 监听 open 变化，打开时加载数据
  watch(
    () => props.open,
    async newVal => {
      if (newVal && props.project) {
        await loadProjectData();
      } else {
        resetForm();
      }
    },
  );
</script>

<template>
  <Modal
    :open="open"
    title="编辑项目"
    :confirm-disabled="!isValid || loading"
    @close="handleClose"
    @cancel="handleClose"
    @confirm="handleConfirm"
  >
    <div v-if="loading" class="flex justify-center items-center py-8">
      <div
        class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-gray-100"
      />
    </div>

    <div v-else class="space-y-4">
      <!-- 项目名称 -->
      <Input
        v-model="formData.name"
        label="项目名称"
        placeholder="请输入项目名称"
        :max-length="200"
        :required="true"
        full-width
      />

      <!-- 项目描述 -->
      <Textarea
        v-model="projectDescription"
        placeholder="请输入项目描述（可选）"
        :rows="3"
        :max-length="500"
        :show-count="true"
        full-width
      />

      <!-- 项目颜色 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          项目颜色
        </label>
        <ColorSelector
          v-model="projectColor"
          :show-custom-color="true"
          :show-random-button="true"
          width="full"
        />
      </div>

      <!-- 项目标签 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          项目标签
        </label>
        <TagSelector v-model="selectedTags" placeholder="为项目添加标签..." />
      </div>

      <!-- 归档状态 -->
      <div class="flex items-center gap-2">
        <input
          id="isArchived"
          v-model="formData.isArchived"
          type="checkbox"
          class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        />
        <label
          for="isArchived"
          class="text-sm font-medium text-gray-700 dark:text-gray-300 cursor-pointer"
        >
          归档此项目
        </label>
      </div>
    </div>
  </Modal>
</template>
