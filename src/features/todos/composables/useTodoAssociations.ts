import { ProjectDb } from '@/services/projects';
import { TagDb } from '@/services/tags';
import type { Tags } from '@/schema/tags';
import type { Projects } from '@/schema/todos';

/**
 * Todo 项目和标签关联管理的组合式函数
 * @param _todoId - Todo 的序列号（当前未使用，等待后端 API 实施后启用）
 */
export function useTodoAssociations(_todoId: string) {
  // 注意: _todoId 参数在后端 API 实施后会被使用
  // 当前暂时保留以保持接口一致性，使用下划线前缀表示预留参数
  // 示例: 后端实施后将用于 TodoDb.listProjects(_todoId)

  // 状态
  const selectedProjects = ref<string[]>([]);
  const selectedTags = ref<string[]>([]);
  const projectsMap = ref<Map<string, Projects>>(new Map());
  const tagsMap = ref<Map<string, Tags>>(new Map());
  const loading = ref(false);
  const error = ref<string | null>(null);

  /**
   * 加载所有项目和标签主数据
   */
  async function loadMasterData() {
    try {
      const [projects, tags] = await Promise.all([ProjectDb.listProjects(), TagDb.listTags()]);

      projectsMap.value = new Map(projects.map(p => [p.serialNum, p]));
      tagsMap.value = new Map(tags.map(t => [t.serialNum, t]));
    } catch (err) {
      console.error('加载主数据失败:', err);
      throw err;
    }
  }

  /**
   * 加载当前 todo 的项目和标签关联
   */
  async function loadAssociations() {
    loading.value = true;
    error.value = null;

    try {
      // 先加载主数据
      await loadMasterData();

      // TODO: 从后端加载当前 todo 的关联
      // 需要实施后端 Commands 后取消注释:
      // import { TodoDb } from '@/services/todos';
      // const [todoProjects, todoTags] = await Promise.all([
      //   TodoDb.listProjects(todoId),
      //   TodoDb.listTags(todoId),
      // ]);
      // selectedProjects.value = todoProjects.map(p => p.serialNum);
      // selectedTags.value = todoTags.map(t => t.serialNum);

      // 临时: 初始化为空数组
      selectedProjects.value = [];
      selectedTags.value = [];
    } catch (err) {
      error.value = '加载关联数据失败';
      console.error('加载关联失败:', err);
    } finally {
      loading.value = false;
    }
  }

  /**
   * 添加项目关联
   */
  async function addProject(projectId: string) {
    try {
      // TODO: 调用后端 API
      // 需要实施后端 Commands 后取消注释:
      // await TodoDb.addProject(todoId, projectId);

      if (!selectedProjects.value.includes(projectId)) {
        selectedProjects.value.push(projectId);
      }
    } catch (err) {
      console.error('添加项目关联失败:', err);
      throw err;
    }
  }

  /**
   * 移除项目关联
   */
  async function removeProject(projectId: string) {
    try {
      // TODO: 调用后端 API
      // 需要实施后端 Commands 后取消注释:
      // await TodoDb.removeProject(todoId, projectId);

      selectedProjects.value = selectedProjects.value.filter(id => id !== projectId);
    } catch (err) {
      console.error('移除项目关联失败:', err);
      throw err;
    }
  }

  /**
   * 添加标签关联
   */
  async function addTag(tagId: string) {
    try {
      // TODO: 调用后端 API
      // 需要实施后端 Commands 后取消注释:
      // await TodoDb.addTag(todoId, tagId);

      if (!selectedTags.value.includes(tagId)) {
        selectedTags.value.push(tagId);
      }
    } catch (err) {
      console.error('添加标签关联失败:', err);
      throw err;
    }
  }

  /**
   * 移除标签关联
   */
  async function removeTag(tagId: string) {
    try {
      // TODO: 调用后端 API
      // 需要实施后端 Commands 后取消注释:
      // await TodoDb.removeTag(todoId, tagId);

      selectedTags.value = selectedTags.value.filter(id => id !== tagId);
    } catch (err) {
      console.error('移除标签关联失败:', err);
      throw err;
    }
  }

  /**
   * 获取项目详情
   */
  function getProject(projectId: string): Projects | undefined {
    return projectsMap.value.get(projectId);
  }

  /**
   * 获取标签详情
   */
  function getTag(tagId: string): Tags | undefined {
    return tagsMap.value.get(tagId);
  }

  /**
   * 获取项目名称
   */
  function getProjectName(projectId: string): string {
    return projectsMap.value.get(projectId)?.name || projectId;
  }

  /**
   * 获取标签名称
   */
  function getTagName(tagId: string): string {
    return tagsMap.value.get(tagId)?.name || tagId;
  }

  /**
   * 获取项目颜色
   */
  function getProjectColor(projectId: string): string {
    return projectsMap.value.get(projectId)?.color || '#3B82F6';
  }

  // 自动加载
  onMounted(() => {
    loadAssociations();
  });

  return {
    // 状态（返回 ref，组件可以直接使用）
    selectedProjects,
    selectedTags,
    projectsMap,
    tagsMap,
    loading,
    error,

    // 方法
    loadAssociations,
    addProject,
    removeProject,
    addTag,
    removeTag,
    getProject,
    getTag,
    getProjectName,
    getTagName,
    getProjectColor,
  };
}
