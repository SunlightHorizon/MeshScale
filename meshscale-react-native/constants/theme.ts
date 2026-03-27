import { Platform } from 'react-native';

// Converted from the meshscale-ui CSS theme (OKLCH → hex)
// Light: --primary oklch(0.546 0.245 264) → indigo-600 #4f46e5
// Dark:  --primary oklch(0.623 0.214 259) → indigo-500 #6366f1

const tintColorLight = '#4f46e5'; // indigo-600
const tintColorDark = '#6366f1';  // indigo-500 (brighter for dark bg)

export const Colors = {
  light: {
    text: '#171717',          // oklch(0.145 0 0)
    background: '#ffffff',    // oklch(1 0 0)
    tint: tintColorLight,
    icon: '#71717a',          // oklch(0.556 0.02 264)
    tabIconDefault: '#71717a',
    tabIconSelected: tintColorLight,
    card: '#ffffff',          // oklch(1 0 0) — pure white, matches web --card
    border: '#e4e4ed',        // oklch(0.9 0.015 264) — lavender-tinted
    muted: '#71717a',         // oklch(0.556 0.02 264)
    mutedBackground: '#f5f5fc', // oklch(0.97 0.005 264) — very light lavender
  },
  dark: {
    text: '#fafafa',          // oklch(0.985 0 0)
    background: '#171717',    // oklch(0.145 0 0)
    tint: tintColorDark,
    icon: '#a1a1b5',          // oklch(0.708 0.02 264)
    tabIconDefault: '#a1a1b5',
    tabIconSelected: tintColorDark,
    card: '#262626',          // oklch(0.205 0 0)
    border: '#2e2e2e',        // oklch(1 0 0 / 10%) solid equivalent
    muted: '#a1a1b5',         // oklch(0.708 0.02 264)
    mutedBackground: '#2d2d3d', // oklch(0.269 0.01 264) — dark with purple tint
  },
};

export const StatusColors = {
  running: { bg: '#dcfce7', text: '#15803d', dot: '#16a34a' },
  stopped: { bg: '#f3f4f6', text: '#6b7280', dot: '#9ca3af' },
  deploying: { bg: '#fef9c3', text: '#a16207', dot: '#ca8a04' },
  error: { bg: '#fee2e2', text: '#dc2626', dot: '#ef4444' },
  success: { bg: '#dcfce7', text: '#15803d', dot: '#16a34a' },
  failed: { bg: '#fee2e2', text: '#dc2626', dot: '#ef4444' },
  'in-progress': { bg: '#fef9c3', text: '#a16207', dot: '#ca8a04' },
} as const;

export const TypeColors: Record<string, { bg: string; text: string }> = {
  website: { bg: '#dbeafe', text: '#1d4ed8' },
  'game-server': { bg: '#f3e8ff', text: '#7c3aed' },
  api: { bg: '#dcfce7', text: '#15803d' },
  worker: { bg: '#fff7ed', text: '#c2410c' },
  cron: { bg: '#fef9c3', text: '#a16207' },
};

export const Fonts = Platform.select({
  ios: {
    sans: 'system-ui',
    serif: 'ui-serif',
    rounded: 'ui-rounded',
    mono: 'ui-monospace',
  },
  default: {
    sans: 'normal',
    serif: 'serif',
    rounded: 'normal',
    mono: 'monospace',
  },
  web: {
    sans: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
    serif: "Georgia, 'Times New Roman', serif",
    rounded: "'SF Pro Rounded', 'Hiragino Maru Gothic ProN', Meiryo, 'MS PGothic', sans-serif",
    mono: "SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace",
  },
});
