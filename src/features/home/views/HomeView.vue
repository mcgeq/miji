<template>
  <div class="grid grid-cols-1 md:grid-cols-2 grid-rows-4 md:grid-rows-2 gap-2 p-2 min-h-screen bg-gray-100">
    <div class="home-scoop text-red-600">
      区域 1
    </div>
    <div class="home-scoop text-blue-600">
      区域 2
    </div>
    <div class="home-scoop text-purple-600">
      区域 3
    </div>
    <div class="home-scoop text-yellow-600">
      区域 4
    </div>
  </div>
</template>

<script setup>
</script>

<style lang="postcss">
  .home-scoop {
    @apply bg-white rounded-lg shadow-md flex items-center justify-center text-xl font-semibold;
  }
</style>
