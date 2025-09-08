<script setup></script>

<template>
  <!-- 外层网格：手机 1×4、桌面 2×2，间隙 1rem -->
  <div
    class="bg-gradient-to-br p-4 gap-4 grid grid-cols-1 grid-rows-4 min-h-screen from-gray-100 to-gray-200 md:grid-cols-2 md:grid-rows-2"
  >
    <!-- 区域 1：红 -->
    <div
      class="bg-gradient-to-br home-scoop text-red-600 from-red-50 to-red-100 hover:from-red-100 hover:to-red-200"
    >
      区域 1
    </div>

    <!-- 区域 2：蓝 -->
    <div
      class="home-scoop bg-gradient-to-br text-blue-600 from-blue-50 to-blue-100 hover:from-blue-100 hover:to-blue-200"
    >
      区域 2
    </div>

    <!-- 区域 3：紫 -->
    <div
      class="home-scoop bg-gradient-to-br text-purple-600 from-purple-50 to-purple-100 hover:from-purple-100 hover:to-purple-200"
    >
      区域 3
    </div>

    <!-- 区域 4：黄 -->
    <div
      class="home-scoop bg-gradient-to-br text-yellow-600 from-yellow-50 to-yellow-100 hover:from-yellow-100 hover:to-yellow-200"
    >
      区域 4
    </div>
  </div>
</template>

<style lang="postcss">
.home-scoop {
  @apply
    rounded-2xl
    shadow-lg
    backdrop-blur-sm
    transition-all-400
    ease-in-out
    hover:scale-105
    hover:shadow-2xl
    flex
    items-center
    justify-center
    text-2xl
    font-bold;
}
</style>
