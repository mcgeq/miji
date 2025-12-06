<script setup lang="ts">
  import { FileCheck, Hash, Pencil, Plus, Trash2 } from 'lucide-vue-next';
  import Card from '@/components/ui/Card.vue';
  import type { Tags, TagsWithUsageStats } from '@/schema/tags';
  import type { TagCreate } from '@/services/tags';
  import { TagDb } from '@/services/tags';
  import { toast } from '@/utils/toast';
  import TagCreateModal from '../components/TagCreateModal.vue';

  // 使用联合类型，支持有或没有 usage 字段的标签
  type TagWithOptionalUsage = Tags | TagsWithUsageStats;
  const tagsMap = ref(new Map<string, TagWithOptionalUsage>());
  const loading = ref(false);
  const showCreateModal = ref(false);

  // 加载标签列表
  async function loadTags() {
    loading.value = true;
    try {
      const tags = await TagDb.listTags();
      tagsMap.value = new Map(tags.map(t => [t.serialNum, t]));
    } catch (error) {
      console.error('加载标签列表失败:', error);
      toast.error('无法加载标签列表，请稍后重试');
    } finally {
      loading.value = false;
    }
  }

  // 打开创建模态框
  function openCreateModal() {
    showCreateModal.value = true;
  }

  // 创建标签
  async function handleCreateConfirm(data: TagCreate) {
    try {
      const newTag = await TagDb.createTag(data);
      tagsMap.value.set(newTag.serialNum, newTag);
      toast.success(`标签"${newTag.name}"创建成功`);
      showCreateModal.value = false;
    } catch (error) {
      console.error('创建标签失败:', error);
      toast.error(`创建失败: ${String(error)}`);
    }
  }

  // 编辑标签（TODO: 待实现）
  function handleEdit(serialNum: string) {
    const tag = tagsMap.value.get(serialNum);
    if (!tag) return;

    toast.info('编辑功能待实现');
    console.log('编辑标签:', tag);
  }

  // 删除标签
  async function handleDelete(serialNum: string) {
    const tag = tagsMap.value.get(serialNum);
    if (!tag) return;

    try {
      await TagDb.deleteTag(serialNum);
      tagsMap.value.delete(serialNum);
      toast.success(`标签"${tag.name}"删除成功`);
    } catch (error) {
      console.error('删除标签失败:', error);
      const errorMsg = String(error);
      // 检查是否是引用错误，使用不同的提示
      if (errorMsg.includes('个待办事项正在使用')) {
        toast.warning(errorMsg);
      } else {
        toast.error('删除失败');
      }
    }
  }

  // 初始化加载
  onMounted(() => {
    loadTags();
  });
</script>

<template>
  <div class="space-y-4 p-4">
    <!-- 加载中 -->
    <div v-if="loading" class="flex justify-center items-center py-8">
      <div
        class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-gray-100"
      />
    </div>

    <!-- 标签列表 -->
    <div v-else>
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl font-bold">标签管理</h2>
        <button
          class="p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center justify-center"
          title="创建标签"
          @click="openCreateModal"
        >
          <Plus :size="20" />
        </button>
      </div>

      <!-- 空状态 -->
      <div v-if="tagsMap.size === 0" class="text-center py-8 text-gray-500">
        暂无标签，点击 + 按钮开始添加
      </div>

      <!-- 标签卡片 -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <Card
          v-for="[serialNum, tag] in tagsMap"
          :key="serialNum"
          shadow="md"
          padding="md"
          class="border-l-4 border-l-blue-500 dark:border-l-blue-400 h-32 flex flex-col hover:shadow-lg transition-shadow"
        >
          <!-- 标题栏 -->
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2 flex-1 min-w-0">
              <Hash class="w-5 h-5 text-blue-600 dark:text-blue-400 flex-shrink-0" />
              <h3 class="font-semibold text-base text-blue-600 dark:text-blue-400 truncate">
                {{ tag.name }}
              </h3>
            </div>

            <!-- 操作按钮 -->
            <div class="flex items-center gap-1 flex-shrink-0">
              <!-- 引用计数 -->
              <span
                v-if="'usage' in tag && tag.usage.todos.count > 0"
                class="flex items-center gap-1 px-2 py-1 text-xs text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-gray-800 rounded"
                :title="`被 ${tag.usage.todos.count} 个待办事项引用`"
              >
                <FileCheck :size="14" />
                {{ tag.usage.todos.count }}
              </span>

              <button
                class="p-1.5 text-gray-500 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded transition-colors"
                title="编辑标签"
                @click="handleEdit(serialNum)"
              >
                <Pencil :size="16" />
              </button>
              <button
                class="p-1.5 text-gray-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded transition-colors"
                title="删除标签"
                @click="handleDelete(serialNum)"
              >
                <Trash2 :size="16" />
              </button>
            </div>
          </div>

          <!-- 描述 - 只显示一行，超出部分隐藏 -->
          <p
            v-if="tag.description"
            class="text-sm text-gray-600 dark:text-gray-400 line-clamp-1 flex-1"
            :title="tag.description"
          >
            {{ tag.description }}
          </p>
          <p v-else class="text-sm text-gray-400 dark:text-gray-500 italic flex-1">暂无描述</p>
        </Card>
      </div>
    </div>

    <!-- 创建标签模态框 -->
    <TagCreateModal
      :open="showCreateModal"
      @close="showCreateModal = false"
      @confirm="handleCreateConfirm"
    />
  </div>
</template>
