/**
 * 进度条路由守卫
 * 使用 NProgress 显示页面加载进度
 */
import type { NavigationGuardNext, RouteLocationNormalized } from 'vue-router';

/**
 * 简单的进度条实现（如果不想依赖 nprogress）
 * 你也可以安装 nprogress: npm install nprogress @types/nprogress
 */
class SimpleProgress {
  private bar: HTMLElement | null = null;
  private isVisible = false;

  start() {
    if (this.isVisible) return;

    this.isVisible = true;

    // 创建进度条元素
    if (!this.bar) {
      this.bar = document.createElement('div');
      this.bar.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 0%;
        height: 2px;
        background: linear-gradient(90deg, #3b82f6, #8b5cf6);
        transition: width 0.4s ease;
        z-index: 9999;
      `;
      document.body.appendChild(this.bar);
    }

    // 开始进度
    requestAnimationFrame(() => {
      if (this.bar) {
        this.bar.style.width = '70%';
      }
    });
  }

  done() {
    if (!this.isVisible || !this.bar) return;

    this.isVisible = false;

    // 完成进度
    this.bar.style.width = '100%';

    // 淡出并移除
    setTimeout(() => {
      if (this.bar) {
        this.bar.style.opacity = '0';
        this.bar.style.transition = 'width 0.4s ease, opacity 0.2s ease';

        setTimeout(() => {
          if (this.bar && this.bar.parentNode) {
            this.bar.parentNode.removeChild(this.bar);
            this.bar = null;
          }
        }, 200);
      }
    }, 100);
  }
}

const progress = new SimpleProgress();

/**
 * 进度条守卫 - 开始
 */
export function progressStart(
  _to: RouteLocationNormalized,
  _from: RouteLocationNormalized,
  next: NavigationGuardNext,
) {
  progress.start();
  next();
}

/**
 * 进度条守卫 - 结束
 */
export function progressDone() {
  progress.done();
}

/**
 * 如果你想使用 NProgress 库，可以使用以下代码：
 *
 * import NProgress from 'nprogress';
 * import 'nprogress/nprogress.css';
 *
 * NProgress.configure({ showSpinner: false });
 *
 * export function progressStart() {
 *   NProgress.start();
 * }
 *
 * export function progressDone() {
 *   NProgress.done();
 * }
 */
