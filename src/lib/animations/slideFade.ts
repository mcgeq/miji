// src/lib/animations/slideFade.ts
import { cubicOut } from 'svelte/easing';

export function slideFade(node: Element, { delay = 0, duration = 300 }) {
  const style = getComputedStyle(node);
  const height = parseFloat(style.height);

  return {
    delay,
    duration,
    easing: cubicOut,
    css: (t: number) =>
      `
      opacity: ${t};
      height: ${t * height}px;
      transform: translateY(${(1 - t) * 10}px);
      overflow: hidden;
    `,
  };
}
