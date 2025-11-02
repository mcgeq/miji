/**
 * Bootstrap Error Page Utility
 *
 * Provides a clean, styled error page for displaying bootstrap errors
 * when the application fails to start.
 */

export interface ErrorPageConfig {
  /** Error title */
  title?: string;
  /** Error message */
  message?: string;
  /** Detailed error information */
  details?: string;
  /** Whether to show error details */
  showDetails?: boolean;
  /** Whether to show reload button */
  showReloadButton?: boolean;
  /** Whether to show retry button */
  showRetryButton?: boolean;
  /** Custom retry handler */
  onRetry?: () => void;
  /** Custom CSS class names */
  customClasses?: {
    container?: string;
    content?: string;
    title?: string;
    message?: string;
    details?: string;
    reloadButton?: string;
    retryButton?: string;
  };
}

const DEFAULT_CONFIG: Required<Omit<ErrorPageConfig, 'onRetry' | 'details'>> &
  Pick<ErrorPageConfig, 'onRetry' | 'details'> = {
    title: 'App Loading Error',
    message: 'Failed to start the application. Please restart the app.',
    details: undefined,
    showDetails: false,
    showReloadButton: true,
    showRetryButton: false,
    onRetry: undefined,
    customClasses: {},
  };

/**
 * Creates and displays a bootstrap error page
 * @param error The error that occurred
 * @param config Configuration options
 * @returns The created error page HTML element
 */
export function showBootstrapErrorPage(
  error: unknown,
  config: ErrorPageConfig = {},
): HTMLElement {
  const finalConfig = { ...DEFAULT_CONFIG, ...config };

  // Clear existing content
  if (document.body) {
    document.body.innerHTML = '';
  }

  // Create error page container
  const container = document.createElement('div');
  container.className =
    finalConfig.customClasses.container || 'bootstrap-error-page';

  // Create error page content
  const content = document.createElement('div');
  content.className =
    finalConfig.customClasses.content || 'bootstrap-error-page-content';
  container.appendChild(content);

  // Error icon (optional)
  const icon = document.createElement('div');
  icon.className = 'bootstrap-error-page-icon';
  icon.textContent = '⚠️';
  content.appendChild(icon);

  // Error title
  const title = document.createElement('h1');
  title.className =
    finalConfig.customClasses.title || 'bootstrap-error-page-title';
  title.textContent = finalConfig.title;
  content.appendChild(title);

  // Error message
  const message = document.createElement('p');
  message.className =
    finalConfig.customClasses.message || 'bootstrap-error-page-message';
  message.textContent = finalConfig.message;
  content.appendChild(message);

  // Error details (if enabled)
  if (finalConfig.showDetails) {
    const details = document.createElement('div');
    details.className =
      finalConfig.customClasses.details || 'bootstrap-error-page-details';

    const errorText =
      finalConfig.details ||
      (error instanceof Error
        ? `${error.name}: ${error.message}\n\n${error.stack || ''}`
        : String(error));

    // Format error text for display
    const errorLines = errorText.split('\n').map(line => {
      const pre = document.createElement('pre');
      pre.style.margin = '0';
      pre.style.fontFamily = 'inherit';
      pre.textContent = line;
      return pre.outerHTML;
    });
    details.innerHTML = errorLines.join('');

    content.appendChild(details);
  }

  // Button container
  const buttonContainer = document.createElement('div');

  // Reload button
  if (finalConfig.showReloadButton) {
    const reloadButton = document.createElement('button');
    reloadButton.className =
      finalConfig.customClasses.reloadButton ||
      'bootstrap-error-page-button';
    reloadButton.textContent = 'Reload';
    reloadButton.onclick = () => {
      window.location.reload();
    };
    buttonContainer.appendChild(reloadButton);
  }

  // Retry button
  if (finalConfig.showRetryButton && finalConfig.onRetry) {
    const retryButton = document.createElement('button');
    retryButton.className =
      finalConfig.customClasses.retryButton ||
      'bootstrap-error-page-button bootstrap-error-page-button-secondary';
    retryButton.textContent = 'Retry';
    retryButton.onclick = () => {
      if (finalConfig.onRetry) {
        finalConfig.onRetry();
      }
    };
    buttonContainer.appendChild(retryButton);
  }

  if (buttonContainer.children.length > 0) {
    content.appendChild(buttonContainer);
  }

  // Append to body
  if (document.body) {
    document.body.appendChild(container);
  }

  return container;
}

/**
 * Formats an error for display
 * @param error The error to format
 * @returns Formatted error string
 */
export function formatError(error: unknown): string {
  if (error instanceof Error) {
    return `${error.name}: ${error.message}\n\nStack:\n${error.stack || 'No stack trace available'}`;
  }
  return String(error);
}
