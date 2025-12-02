// mediaQueries.ts
import { useMediaQuery } from '@vueuse/core';

/**
 * 媒体查询断点配置（可根据设计系统调整）
 * 注：断点间无重叠/间隙，覆盖所有屏幕宽度场景
 */
export const MEDIA_BREAKPOINTS = {
  MOBILE_MAX: 768, // 移动端最大宽度（≤768px）
  TABLET_MIN: 769, // 平板最小宽度（≥769px）
  TABLET_MAX: 1024, // 平板最大宽度（≤1024px）
  DESKTOP_MIN: 1025, // 桌面最小宽度（≥1025px）
} as const;

export type MediaBreakpoints = typeof MEDIA_BREAKPOINTS;

/**
 * 媒体查询状态存储
 * 使用 VueUse 的 useMediaQuery 实现响应式媒体查询
 */
export const useMediaQueriesStore = defineStore('media', {
  state: (): {
    isMobile: Ref<boolean>;
    isTablet: Ref<boolean>;
  } => ({
    // 移动端：宽度 ≤ 768px
    isMobile: useMediaQuery(`(max-width: ${MEDIA_BREAKPOINTS.MOBILE_MAX}px)`),
    // 平板：宽度在 769px ~ 1024px 之间
    isTablet: useMediaQuery(
      `(min-width: ${MEDIA_BREAKPOINTS.TABLET_MIN}px) and (max-width: ${MEDIA_BREAKPOINTS.TABLET_MAX}px)`,
    ),
  }),

  getters: {
    /**
     * 判断是否为小屏幕（移动端或平板）
     * @example store.media.isSmallScreen → boolean
     */
    isSmallScreen: state => state.isMobile || state.isTablet,
    isDesktop: state => !state.isMobile && !state.isTablet,
  },
});
