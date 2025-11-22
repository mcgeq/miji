/**
 * v-has-value 指令
 * 自动检测 input/select/textarea 元素是否有值
 * 有值时添加 'has-value' 类，用于样式控制
 */

import type { Directive } from 'vue';

interface HasValueElement extends HTMLElement {
  _hasValueHandler?: () => void;
}

function checkValue(el: HasValueElement) {
  const element = el as HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;
  const hasValue = element.value && element.value.trim() !== '';

  if (hasValue) {
    element.classList.add('has-value');
  } else {
    element.classList.remove('has-value');
  }
}

export const vHasValue: Directive = {
  mounted(el: HasValueElement) {
    // 初始检查
    checkValue(el);

    // 创建事件处理器
    const handler = () => checkValue(el);
    el._hasValueHandler = handler;

    // 监听 input 和 change 事件
    el.addEventListener('input', handler);
    el.addEventListener('change', handler);

    // 对于 select，额外监听 Vue 的更新
    if (el.tagName === 'SELECT') {
      // 使用 MutationObserver 监听属性变化
      const observer = new MutationObserver(() => checkValue(el));
      observer.observe(el, {
        attributes: true,
        attributeFilter: ['value'],
        childList: true,
        subtree: true,
      });
      (el as any)._valueObserver = observer;
    }
  },

  updated(el: HasValueElement) {
    // 每次组件更新时重新检查
    checkValue(el);
  },

  unmounted(el: HasValueElement) {
    // 清理事件监听器
    if (el._hasValueHandler) {
      el.removeEventListener('input', el._hasValueHandler);
      el.removeEventListener('change', el._hasValueHandler);
      delete el._hasValueHandler;
    }

    // 清理 MutationObserver
    if ((el as any)._valueObserver) {
      (el as any)._valueObserver.disconnect();
      delete (el as any)._valueObserver;
    }
  },
};
