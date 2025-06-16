// src/lib/utils/dispatchEvent.ts
export type DispatchFn<Events> = <K extends keyof Events>(
  type: K,
  detail?: Events[K],
) => void;
