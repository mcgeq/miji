// src/lib/utils/emit.ts

export function emit<K extends string, T>(
  node: HTMLElement,
  type: K,
  detail: T,
): void {
  const event = new CustomEvent<T>(type, {
    detail,
    bubbles: true,
  });
  node.dispatchEvent(event);
}
