export function mergeSettings<T extends Record<string, any>>(target: T, source: T): T {
  for (const key in source) {
    if (Object.prototype.hasOwnProperty.call(source, key)) {
      if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
        if (typeof target[key] !== 'object' || target[key] === null) {
          target[key] = {} as any;
        }
        mergeSettings(target[key], source[key]);
      } else {
        target[key] = source[key];
      }
    }
  }
  return target;
}
