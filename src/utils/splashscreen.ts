/**
 * Frontend Splashscreen Utility
 *
 * Provides a lightweight, configurable splashscreen for mobile devices
 * that displays before the main Vue app is initialized.
 */

export interface SplashscreenConfig {
  /** Application name to display */
  appName?: string;
  /** Logo text or content */
  logoText?: string;
  /** Loading text to display */
  loadingText?: string;
  /** Background gradient colors */
  backgroundColors?: {
    from: string;
    to: string;
  };
  /** Whether to show the spinner */
  showSpinner?: boolean;
  /** Whether to show the progress bar */
  showProgressBar?: boolean;
  /** Custom CSS class names */
  customClasses?: {
    container?: string;
    logo?: string;
    appName?: string;
    loadingText?: string;
    spinner?: string;
    progressBar?: string;
  };
}

const DEFAULT_CONFIG: Required<SplashscreenConfig> = {
  appName: 'MiJi',
  logoText: 'M',
  loadingText: '正在加载应用...',
  backgroundColors: {
    from: '#667eea',
    to: '#764ba2',
  },
  showSpinner: true,
  showProgressBar: true,
  customClasses: {},
};

/**
 * Creates a frontend splashscreen element
 * @param config Configuration options for the splashscreen
 * @returns The created splashscreen HTML element
 */
export function createFrontendSplashscreen(config: SplashscreenConfig = {}): HTMLElement {
  const finalConfig = { ...DEFAULT_CONFIG, ...config };

  // Ensure styles are loaded
  if (!document.querySelector('link[href*="splashscreen.css"]')) {
    // Styles should be imported in main.ts, but we check just in case
    console.warn('Splashscreen styles may not be loaded. Ensure splashscreen.css is imported.');
  }

  const splashscreen = document.createElement('div');
  splashscreen.id = 'frontend-splashscreen';

  const container = document.createElement('div');
  container.className = finalConfig.customClasses.container || 'frontend-splashscreen-container';

  // Logo
  const logo = document.createElement('div');
  logo.className = finalConfig.customClasses.logo || 'frontend-splashscreen-logo';
  logo.textContent = finalConfig.logoText;
  container.appendChild(logo);

  // App Name
  const appName = document.createElement('div');
  appName.className = finalConfig.customClasses.appName || 'frontend-splashscreen-app-name';
  appName.textContent = finalConfig.appName;
  container.appendChild(appName);

  // Loading Text
  const loadingText = document.createElement('div');
  loadingText.className =
    finalConfig.customClasses.loadingText || 'frontend-splashscreen-loading-text';
  loadingText.textContent = finalConfig.loadingText;
  container.appendChild(loadingText);

  // Spinner
  if (finalConfig.showSpinner) {
    const spinner = document.createElement('div');
    spinner.className = finalConfig.customClasses.spinner || 'frontend-splashscreen-spinner';
    container.appendChild(spinner);
  }

  // Progress Bar
  if (finalConfig.showProgressBar) {
    const progressBar = document.createElement('div');
    progressBar.className =
      finalConfig.customClasses.progressBar || 'frontend-splashscreen-progress-bar';
    const progressFill = document.createElement('div');
    progressFill.className = 'frontend-splashscreen-progress-fill';
    progressBar.appendChild(progressFill);
    container.appendChild(progressBar);
  }

  splashscreen.appendChild(container);

  // Apply background gradient if custom colors are provided
  if (
    finalConfig.backgroundColors.from !== DEFAULT_CONFIG.backgroundColors.from ||
    finalConfig.backgroundColors.to !== DEFAULT_CONFIG.backgroundColors.to
  ) {
    splashscreen.style.background = `linear-gradient(135deg, ${finalConfig.backgroundColors.from} 0%, ${finalConfig.backgroundColors.to} 100%)`;
  }

  document.body.appendChild(splashscreen);
  return splashscreen;
}

/**
 * Closes the frontend splashscreen with a fade-out animation
 * @param splashscreen The splashscreen element to close
 * @param fadeDuration Duration of the fade-out animation in milliseconds
 */
export function closeFrontendSplashscreen(
  splashscreen: HTMLElement | null,
  fadeDuration: number = 500,
): void {
  if (!splashscreen) {
    return;
  }

  // Add fade-out class
  splashscreen.classList.add('frontend-splashscreen-fade-out');

  // Remove element after animation
  setTimeout(() => {
    if (splashscreen.parentNode) {
      splashscreen.remove();
    }
  }, fadeDuration);
}

/**
 * Updates the loading text on an existing splashscreen
 * @param splashscreen The splashscreen element
 * @param newText The new loading text
 */
export function updateSplashscreenText(splashscreen: HTMLElement | null, newText: string): void {
  if (!splashscreen) {
    return;
  }

  const loadingTextElement = splashscreen.querySelector('.frontend-splashscreen-loading-text');
  if (loadingTextElement) {
    loadingTextElement.textContent = newText;
  }
}

/**
 * Updates the progress bar on an existing splashscreen
 * @param splashscreen The splashscreen element
 * @param progress Progress value from 0 to 100
 */
export function updateSplashscreenProgress(
  splashscreen: HTMLElement | null,
  progress: number,
): void {
  if (!splashscreen) {
    return;
  }

  const progressFill = splashscreen.querySelector(
    '.frontend-splashscreen-progress-fill',
  ) as HTMLElement | null;
  if (progressFill) {
    const clampedProgress = Math.max(0, Math.min(100, progress));
    progressFill.style.width = `${clampedProgress}%`;
    // Remove animation to allow manual control
    progressFill.style.animation = 'none';
  }
}
