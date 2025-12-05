// router/index.ts
import { createRouter, createWebHashHistory } from 'vue-router';
import { routes } from 'vue-router/auto-routes';
import { authGuard } from './guards/auth.guard';
import { firstLaunchGuard } from './guards/firstLaunch.guard';
import { progressDone, progressStart } from './guards/progress.guard';

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

// 进度条守卫 - 开始
router.beforeEach(progressStart);

// 首次启动守卫 - 检测并引导新用户
router.beforeEach(firstLaunchGuard);

// 认证守卫 - 主要的权限检查
router.beforeEach(authGuard);

// 进度条守卫 - 结束
router.afterEach(progressDone);

export default router;
