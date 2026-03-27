/**
 * Utility functions for building Tailwind class strings dynamically
 * Replaces React Native StyleSheet with NativeWind classes
 */

/**
 * Joins multiple class strings, filtering out falsy values
 * Useful for conditional classes
 */
export const cn = (...classes: (string | undefined | null | false)[]): string => {
  return classes.filter(Boolean).join(' ');
};

/**
 * Status badge styling based on status
 */
export const getStatusBadgeClasses = (
  status: 'running' | 'stopped' | 'deploying' | 'error' | 'success' | 'failed' | 'in-progress'
): { container: string; dot: string; text: string } => {
  const baseContainer = 'flex items-center gap-2 px-2 py-0.5 rounded-full';
  const baseDot = 'w-1.5 h-1.5 rounded-full';

  const statusMap = {
    running: {
      container: cn(baseContainer, 'bg-success-50'),
      dot: 'bg-success',
      text: 'text-success-text text-xs font-medium',
    },
    stopped: {
      container: cn(baseContainer, 'bg-stopped-50'),
      dot: 'bg-stopped',
      text: 'text-stopped-text text-xs font-medium',
    },
    deploying: {
      container: cn(baseContainer, 'bg-deploying-50'),
      dot: 'bg-deploying',
      text: 'text-deploying-text text-xs font-medium',
    },
    error: {
      container: cn(baseContainer, 'bg-error-50'),
      dot: 'bg-error',
      text: 'text-error-text text-xs font-medium',
    },
    success: {
      container: cn(baseContainer, 'bg-success-50'),
      dot: 'bg-success',
      text: 'text-success-text text-xs font-medium',
    },
    failed: {
      container: cn(baseContainer, 'bg-failed-50'),
      dot: 'bg-failed',
      text: 'text-failed-text text-xs font-medium',
    },
    'in-progress': {
      container: cn(baseContainer, 'bg-deploying-50'),
      dot: 'bg-deploying',
      text: 'text-deploying-text text-xs font-medium',
    },
  };

  return statusMap[status];
};

/**
 * Type badge styling based on project type
 */
export const getTypeBadgeClasses = (
  type: 'website' | 'game-server' | 'api' | 'worker' | 'cron'
): { container: string; text: string } => {
  const baseContainer = 'px-2 py-0.5 rounded-md border text-xs font-medium';

  const typeMap = {
    website: {
      container: cn(baseContainer, 'border-type-website-text bg-type-website-50'),
      text: 'text-type-website-text',
    },
    'game-server': {
      container: cn(baseContainer, 'border-type-game-server-text bg-type-game-server-50'),
      text: 'text-type-game-server-text',
    },
    api: {
      container: cn(baseContainer, 'border-type-api-text bg-type-api-50'),
      text: 'text-type-api-text',
    },
    worker: {
      container: cn(baseContainer, 'border-type-worker-text bg-type-worker-50'),
      text: 'text-type-worker-text',
    },
    cron: {
      container: cn(baseContainer, 'border-type-cron-text bg-type-cron-50'),
      text: 'text-type-cron-text',
    },
  };

  return typeMap[type];
};

/**
 * Progress bar classes based on percentage and color threshold
 */
export const getProgressBarClasses = (
  percentage: number
): { container: string; bar: string; barFill: string; text: string } => {
  const getBarColor = () => {
    if (percentage > 80) return 'bg-red-500'; // high usage
    if (percentage > 60) return 'bg-yellow-500'; // medium usage
    return 'bg-green-500'; // low usage
  };

  return {
    container: 'w-full',
    bar: cn(
      'h-1.5 rounded-full overflow-hidden bg-gray-200',
      'dark:bg-gray-700'
    ),
    barFill: getBarColor(),
    text: cn(
      percentage > 80 ? 'text-red-600 dark:text-red-400' :
      percentage > 60 ? 'text-yellow-600 dark:text-yellow-400' :
      'text-green-600 dark:text-green-400',
      'text-xs font-medium'
    ),
  };
};

/**
 * Card styling with proper theme support
 */
export const getCardClasses = (): string => {
  return cn(
    'bg-white dark:bg-neutral-900',
    'border border-gray-200 dark:border-neutral-800',
    'rounded-xl',
    'p-6',
    'shadow-subtle'
  );
};

/**
 * Input/Field styling
 */
export const getInputClasses = (): string => {
  return cn(
    'w-full px-4 py-2.5',
    'bg-white dark:bg-neutral-900',
    'border border-gray-200 dark:border-neutral-800',
    'rounded-md',
    'text-base text-neutral-900 dark:text-white',
    'placeholder:text-gray-500 dark:placeholder:text-gray-400',
    'focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary',
    'dark:focus:border-primary-dark dark:focus:ring-primary-dark'
  );
};

/**
 * Button styling with variants
 */
export const getButtonClasses = (
  variant: 'primary' | 'secondary' | 'ghost' = 'primary'
): string => {
  const baseClasses = 'px-4 py-2.5 rounded-md font-medium text-sm inline-flex items-center justify-center focus:outline-none';

  const variants = {
    primary: cn(
      baseClasses,
      'bg-primary text-white dark:bg-primary-dark',
      'hover:bg-indigo-700 dark:hover:bg-indigo-600',
      'active:bg-indigo-800'
    ),
    secondary: cn(
      baseClasses,
      'bg-gray-100 text-neutral-900 dark:bg-neutral-800 dark:text-white',
      'hover:bg-gray-200 dark:hover:bg-neutral-700',
      'active:bg-gray-300 dark:active:bg-neutral-600'
    ),
    ghost: cn(
      baseClasses,
      'text-neutral-900 dark:text-white',
      'hover:bg-gray-100 dark:hover:bg-neutral-800',
      'active:bg-gray-200 dark:active:bg-neutral-700'
    ),
  };

  return variants[variant];
};

/**
 * Container/Page styling
 */
export const getPageClasses = (): string => {
  return cn(
    'flex-1',
    'bg-white dark:bg-neutral-950',
    'px-4 sm:px-6 lg:px-8',
    'py-6'
  );
};

/**
 * Sidebar styling
 */
export const getSidebarClasses = (): string => {
  return cn(
    'hidden lg:flex',
    'w-sidebar min-w-sidebar',
    'bg-white dark:bg-neutral-900',
    'border-r border-gray-200 dark:border-neutral-800',
    'flex-col',
    'py-6'
  );
};

/**
 * Grid classes for responsive layouts
 */
export const getGridClasses = (
  cols: 'auto' | 1 | 2 | 3 | 4 | 6 = 'auto'
): string => {
  const colMap = {
    auto: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4',
    1: 'grid-cols-1',
    2: 'grid-cols-1 sm:grid-cols-2',
    3: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3',
    4: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4',
    6: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6',
  };

  return cn(
    'grid',
    'gap-4',
    colMap[cols]
  );
};

/**
 * Flexbox utility for common flex patterns
 */
export const getFlexClasses = (
  direction: 'row' | 'col' = 'row',
  justify: 'start' | 'center' | 'between' | 'end' = 'start',
  items: 'start' | 'center' | 'end' | 'stretch' = 'center',
  gap: number = 2
): string => {
  const dirMap = {
    row: 'flex-row',
    col: 'flex-col',
  };

  const justifyMap = {
    start: 'justify-start',
    center: 'justify-center',
    between: 'justify-between',
    end: 'justify-end',
  };

  const itemsMap = {
    start: 'items-start',
    center: 'items-center',
    end: 'items-end',
    stretch: 'items-stretch',
  };

  const gapMap: Record<number, string> = {
    1: 'gap-1',
    2: 'gap-2',
    3: 'gap-3',
    4: 'gap-4',
    6: 'gap-6',
    8: 'gap-8',
  };

  return cn(
    'flex',
    dirMap[direction],
    justifyMap[justify],
    itemsMap[items],
    gapMap[gap] || 'gap-2'
  );
};

/**
 * Typography classes
 */
export const getTypographyClasses = (
  variant: 'h1' | 'h2' | 'h3' | 'h4' | 'body' | 'small' | 'caption' = 'body'
): string => {
  const variants = {
    h1: 'text-2xl font-bold text-neutral-900 dark:text-white',
    h2: 'text-xl font-bold text-neutral-900 dark:text-white',
    h3: 'text-lg font-semibold text-neutral-900 dark:text-white',
    h4: 'text-base font-semibold text-neutral-900 dark:text-white',
    body: 'text-base text-neutral-700 dark:text-neutral-300',
    small: 'text-sm text-neutral-600 dark:text-neutral-400',
    caption: 'text-xs text-neutral-500 dark:text-neutral-500',
  };

  return variants[variant];
};
