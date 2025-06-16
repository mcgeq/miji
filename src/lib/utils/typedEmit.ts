// src/lib/utils/typedEmit.ts

export function createTypedEmit<Events>() {
  return function emit<K extends keyof Events>(
    node: HTMLElement,
    type: K,
    detail: Events[K],
  ) {
    if (!node) return;
    const event = new CustomEvent<Events[K]>(String(type), {
      detail,
      bubbles: true,
    });
    node.dispatchEvent(event);
  };
}
