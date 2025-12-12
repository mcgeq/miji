<script setup lang="ts">
  import { Search, Tag, X } from 'lucide-vue-next';
  import { Modal } from '@/components/ui';
  import type { Tags, TagsWithUsageStats } from '@/schema/tags';
  import { TagDb } from '@/services/tags';

  const props = defineProps<{
    open: boolean;
    selectedTags?: string[]; // 已选中的标签ID列表
  }>();

  const emit = defineEmits<{
    close: [];
    add: [tagId: string];
    remove: [tagId: string];
  }>();

  // 搜索关键词
  const searchQuery = ref('');

  // 从后端获取标签数据（尝试获取带引用数的数据）
  const availableTags = ref<(Tags | TagsWithUsageStats)[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // 加载标签列表
  async function loadTags() {
    loading.value = true;
    error.value = null;
    try {
      const tags = await TagDb.listTags();
      availableTags.value = tags;
    } catch (err) {
      error.value = '加载标签失败';
      console.error('加载标签失败:', err);
    } finally {
      loading.value = false;
    }
  }

  // 监听 open 属性，当打开时加载数据
  watch(
    () => props.open,
    isOpen => {
      if (isOpen && availableTags.value.length === 0) {
        loadTags();
      }
    },
  );

  // 筛选标签
  const filteredTags = computed(() => {
    if (!searchQuery.value) return availableTags.value;
    const query = searchQuery.value.toLowerCase();
    return availableTags.value.filter(tag => tag.name.toLowerCase().includes(query));
  });

  // 已选中的标签
  const selectedTagsSet = computed(() => new Set(props.selectedTags || []));

  // 检查标签是否已选中
  function isSelected(tagId: string): boolean {
    return selectedTagsSet.value.has(tagId);
  }

  // 切换标签选择状态
  function toggleTag(tagId: string) {
    if (isSelected(tagId)) {
      emit('remove', tagId);
    } else {
      emit('add', tagId);
    }
  }

  // 关闭弹窗
  function handleClose() {
    searchQuery.value = '';
    emit('close');
  }

  // 标签颜色列表（用于随机分配颜色）
  const tagColors = [
    '#EF4444', // red
    '#F59E0B', // amber
    '#10B981', // emerald
    '#3B82F6', // blue
    '#8B5CF6', // violet
    '#EC4899', // pink
    '#14B8A6', // teal
    '#F97316', // orange
  ];

  // 根据标签ID获取颜色（简单的哈希算法）
  function getTagColor(tagId: string): string {
    let hash = 0;
    for (let i = 0; i < tagId.length; i++) {
      hash = tagId.charCodeAt(i) + ((hash << 5) - hash);
    }
    return tagColors[Math.abs(hash) % tagColors.length];
  }

  // 获取标签的引用数
  function getTagUsageCount(tag: Tags | TagsWithUsageStats): number {
    if ('usage' in tag) {
      return tag.usage.todos.count || 0;
    }
    return 0;
  }
</script>

<template>
  <Modal :open="open" title="选择标签" size="md" :show-footer="false" @close="handleClose">
    <div class="space-y-4">
      <!-- 搜索框 -->
      <div class="relative">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          v-model="searchQuery"
          type="text"
          placeholder="搜索标签..."
          class="w-full pl-10 pr-10 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
        <button
          v-if="searchQuery"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          @click="searchQuery = ''"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- 已选中的标签 -->
      <div v-if="selectedTags && selectedTags.length > 0" class="space-y-2">
        <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300">
          已选择 ({{ selectedTags.length }})
        </h4>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="tagId in selectedTags"
            :key="tagId"
            class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg hover:opacity-80 transition-opacity text-sm text-white"
            :style="{ backgroundColor: getTagColor(tagId) }"
            @click="emit('remove', tagId)"
          >
            <Tag class="w-4 h-4" />
            <span>{{ availableTags.find(t => t.serialNum === tagId)?.name }}</span>
            <X class="w-3 h-3" />
          </button>
        </div>
      </div>

      <!-- 加载状态 -->
      <div v-if="loading" class="text-center py-12 text-gray-400 dark:text-gray-500">
        <div
          class="animate-spin w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-3"
        />
        <p class="text-sm">加载标签中...</p>
      </div>

      <!-- 错误状态 -->
      <div v-else-if="error" class="text-center py-12">
        <p class="text-sm text-red-600 dark:text-red-400 mb-4">{{ error }}</p>
        <button
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          @click="loadTags"
        >
          重新加载
        </button>
      </div>

      <!-- 标签列表 -->
      <div v-else class="space-y-2">
        <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300">
          可选标签 ({{ filteredTags.length }})
        </h4>
        <div class="max-h-96 overflow-y-auto space-y-2">
          <button
            v-for="tag in filteredTags"
            :key="tag.serialNum"
            class="w-full flex items-center gap-3 p-3 rounded-lg transition-colors text-left"
            :class="
              isSelected(tag.serialNum)
                ? 'bg-blue-50 dark:bg-blue-900/20 border-2 border-blue-500 dark:border-blue-400'
                : 'bg-gray-50 dark:bg-gray-800 border-2 border-transparent hover:border-gray-300 dark:hover:border-gray-600'
            "
            @click="toggleTag(tag.serialNum)"
          >
            <!-- 标签颜色标识 -->
            <div
              class="w-3 h-3 rounded-full shrink-0"
              :style="{ backgroundColor: getTagColor(tag.serialNum) }"
            />

            <!-- 标签信息 -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="font-medium text-gray-900 dark:text-white truncate">
                  {{ tag.name }}
                </span>
                <!-- 引用数 -->
                <span
                  v-if="getTagUsageCount(tag) > 0"
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300"
                  :title="`被 ${getTagUsageCount(tag)} 个待办事项使用`"
                >
                  {{ getTagUsageCount(tag) }}
                </span>
                <span
                  v-if="isSelected(tag.serialNum)"
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 dark:bg-blue-900/50 text-blue-800 dark:text-blue-200"
                >
                  已选
                </span>
              </div>
            </div>

            <!-- 选择图标 -->
            <div
              class="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0"
              :class="
                isSelected(tag.serialNum)
                  ? 'bg-blue-500 border-blue-500'
                  : 'border-gray-300 dark:border-gray-600'
              "
            >
              <div v-if="isSelected(tag.serialNum)" class="w-2 h-2 bg-white rounded-full" />
            </div>
          </button>

          <!-- 空状态 -->
          <div
            v-if="filteredTags.length === 0"
            class="text-center py-12 text-gray-400 dark:text-gray-500"
          >
            <Tag class="mx-auto mb-3 w-12 h-12 opacity-50" />
            <p class="text-sm">{{ searchQuery ? '没有找到匹配的标签' : '还没有标签' }}</p>
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>

<style scoped>
  /* 所有样式已使用 Tailwind CSS 4 */
</style>
