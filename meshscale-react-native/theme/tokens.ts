/**
 * Design tokens for sidebar components.
 * 
 * Color values mapped to oklch CSS custom properties defined in global.css
 * 
 * Light theme oklch values:
 * --sidebar: oklch(0.975 0.008 264) → #f5f4fe
 * --sidebar-foreground: oklch(0.145 0 0) → #1c1c1c
 * --muted-foreground: oklch(0.556 0.02 264) → #79778a
 * --sidebar-border: oklch(0.9 0.015 264) → #e3e1f0
 * --sidebar-accent: oklch(0.94 0.03 264) → #eceaf8
 * --sidebar-accent-foreground: oklch(0.3 0.08 264) → #35316a
 * --sidebar-primary: oklch(0.546 0.245 264) → #4f46e5
 * 
 * Dark theme oklch values:
 * --sidebar: oklch(0.205 0 0) → #2d2d2d
 * --sidebar-foreground: oklch(0.985 0 0) → #f9f9f9
 * --muted-foreground: oklch(0.708 0.02 264) → #a8a6bb
 * --sidebar-border: oklch(1 0 0 / 10%) → rgba(255,255,255,0.1)
 * --sidebar-accent: oklch(0.269 0.02 264) → #373549
 * --sidebar-accent-foreground: oklch(0.985 0 0) → #f9f9f9
 * --sidebar-primary: oklch(0.623 0.214 259) → #6366f1
 */

export type ColorScheme = 'light' | 'dark';

/**
 * Icon color hex values for both themes.
 * Use these ONLY for lucide-react-native icon components where className isn't supported.
 * 
 * For Views/Text, use className="text-sidebar-foreground" or similar (see global.css)
 */
export const ICON_COLORS = {
  light: {
    sidebar: '#1c1c1c',           // --sidebar-foreground
    sidebarAccentForeground: '#35316a', // --sidebar-accent-foreground
    mutedForeground: '#79778a',   // --muted-foreground
    sidebarPrimary: '#4f46e5',    // --sidebar-primary
  },
  dark: {
    sidebar: '#f9f9f9',           // --sidebar-foreground
    sidebarAccentForeground: '#f9f9f9', // --sidebar-accent-foreground
    mutedForeground: '#a8a6bb',   // --muted-foreground
    sidebarPrimary: '#6366f1',    // --sidebar-primary
  },
} as const;

/**
 * Helper to get the icon color for a given token and color scheme.
 * @param token - The token name from ICON_COLORS
 * @param colorScheme - 'light' or 'dark'
 * @returns The hex color value
 */
export function getIconColor(
  token: keyof typeof ICON_COLORS.light,
  colorScheme: ColorScheme,
): string {
  return ICON_COLORS[colorScheme][token];
}
