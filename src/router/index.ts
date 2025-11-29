// router/index.ts
import { createRouter, createWebHashHistory } from 'vue-router';
import { routes } from 'vue-router/auto-routes';
import { authGuard } from './guards/auth.guard';
import { progressDone, progressStart } from './guards/progress.guard';

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

// 进度条守卫 - 开始
router.beforeEach(progressStart);

// 认证守卫 - 主要的权限检查
router.beforeEach(authGuard);

// 进度条守卫 - 结束
router.afterEach(progressDone);

export default router;
