// ─── useThemeColors ──────────────────────────────────────────────────────────
// Convenience hook that returns the full Colors object for the current theme.
// Replaces the repetitive pattern:
//   const colorScheme = useColorScheme() ?? 'light';
//   const colors = Colors[colorScheme];

import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';

export type ThemeColors = typeof Colors.light;

export function useThemeColors(): ThemeColors {
  const colorScheme = useColorScheme() ?? 'light';
  return Colors[colorScheme];
}
