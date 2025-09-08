<script lang="ts" setup generic="T extends { [key: string]: unknown }">
import { computed, shallowRef, watch } from 'vue';

const props = defineProps<{
  entities: Map<string, T>;
  component: any;
  readonly?: boolean;
  displayKey?: keyof T;
}>();

const emit = defineEmits<{
  (e: 'update:entities', val: Map<string, T>): void;
}>();

// 使用 shallowRef 来防止类型被 Vue 展开为 UnwrapRef<T>
const internalMap = shallowRef<Map<string, T>>(new Map(props.entities));

// 当 props.entities 更新时同步更新 internalMap
watch(
  () => props.entities,
  val => {
    internalMap.value = new Map(val);
  },
  { deep: false }, // 因为 shallowRef 不需要 deep
);

// 将 Map 转为 Array 供 v-for 渲染
const entityList = computed(() => Array.from(internalMap.value.entries()));

// 更新单个元素
function updateEntity(key: string, val: T) {
  internalMap.value.set(key, val);
  emit('update:entities', new Map(internalMap.value));
}

// 删除单个元素
function removeEntity(key: string) {
  internalMap.value.delete(key);
  emit('update:entities', new Map(internalMap.value));
}
</script>

<template>
  <div class="p-4 bg-gray-100 flex flex-wrap gap-3">
    <component
      :is="component"
      v-for="([key, entity]) in entityList"
      :key="String(key)"
      :model-value="entity"
      :readonly="readonly"
      :display-key="displayKey"
      @update:model-value="(val: T) => updateEntity(key, val)"
      @remove="() => removeEntity(key)"
    />
  </div>
</template>
