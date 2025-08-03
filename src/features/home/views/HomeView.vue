<template>
  <!-- 外层网格：手机 1×4、桌面 2×2，间隙 1rem -->
  <div
    class="grid grid-cols-1 md:grid-cols-2 grid-rows-4 md:grid-rows-2 gap-4 p-4 min-h-screen bg-gradient-to-br from-gray-100 to-gray-200"
  >
    <!-- 区域 1：红 -->
    <div
      class="home-scoop text-red-600 bg-gradient-to-br from-red-50 to-red-100 hover:from-red-100 hover:to-red-200"
    >
      区域 1
    </div>

    <!-- 区域 2：蓝 -->
    <div
      class="home-scoop text-blue-600 bg-gradient-to-br from-blue-50 to-blue-100 hover:from-blue-100 hover:to-blue-200"
    >
      区域 2
    </div>

    <!-- 区域 3：紫 -->
    <div
      class="home-scoop text-purple-600 bg-gradient-to-br from-purple-50 to-purple-100 hover:from-purple-100 hover:to-purple-200"
    >
      区域 3
    </div>

    <!-- 区域 4：黄 -->
    <div
      class="home-scoop text-yellow-600 bg-gradient-to-br from-yellow-50 to-yellow-100 hover:from-yellow-100 hover:to-yellow-200"
    >
      区域 4
    </div>
  </div>
</template>

<script setup></script>

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
