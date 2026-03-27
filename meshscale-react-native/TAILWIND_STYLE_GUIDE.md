/**
 * MESHSCALE TAILWIND/NATIVEWIND STYLE GUIDE
 * 
 * This document outlines the new styling approach after migrating from React Native StyleSheet
 * to Tailwind CSS with NativeWind.
 */

// ─── IMPORT PATTERN ──────────────────────────────────────────────────────────
// Old: import { useThemeColors } from '@/hooks/use-theme-colors'
// New: import { cn } from '@/lib/tailwind-utils'

import { cn } from '@/lib/tailwind-utils';

// ─── TEXT STYLING ────────────────────────────────────────────────────────────

// Before:
// <Text style={[styles.title, { color: colors.text }]}>Title</Text>

// After:
// <Text className="text-lg font-semibold text-neutral-900 dark:text-white">Title</Text>

// Typography Classes:
// - Headings: text-xl font-bold (h1), text-lg font-semibold (h2), text-base font-semibold (h3)
// - Body: text-base text-neutral-700 dark:text-neutral-300
// - Small: text-sm text-neutral-600 dark:text-neutral-400
// - Captions: text-xs text-neutral-500 dark:text-neutral-500

// ─── LAYOUT & SPACING ────────────────────────────────────────────────────────

// Before:
// const styles = StyleSheet.create({
//   container: { paddingHorizontal: 16, gap: 16, flexDirection: 'row' }
// });

// After:
// className="flex flex-row px-4 gap-4"

// Spacing (8px base unit):
// px-1 (4px), px-2 (8px), px-3 (12px), px-4 (16px), px-6 (24px), px-8 (32px)
// py-1 (4px), py-2 (8px), py-3 (12px), py-4 (16px), py-6 (24px)
// gap-1 (4px), gap-2 (8px), gap-3 (12px), gap-4 (16px), gap-6 (24px)

// ─── FLEXBOX ─────────────────────────────────────────────────────────────────

// Before:
// flexDirection: 'row', justifyContent: 'between', alignItems: 'center'

// After:
// className="flex flex-row justify-between items-center"

// Common patterns:
// Row with center align: flex flex-row items-center gap-X
// Column with start align: flex flex-col items-start gap-X
// Centered container: flex items-center justify-center
// Space between: flex justify-between

// ─── COLORS ──────────────────────────────────────────────────────────────────

// Before:
// const backgroundColor = colors.background;
// <View style={{ backgroundColor }} />

// After:
// <View className="bg-white dark:bg-neutral-900" />

// Semantic colors:
// Background: bg-white dark:bg-neutral-900 (pages) / bg-gray-50 dark:bg-neutral-950 (surface)
// Text: text-neutral-900 dark:text-white (primary) / text-neutral-600 dark:text-neutral-400 (secondary)
// Border: border-gray-200 dark:border-neutral-800
// Muted: text-neutral-500 dark:text-neutral-500

// Status colors:
// Success: bg-green-100 dark:bg-green-950, text-green-700 dark:text-green-400
// Error: bg-red-100 dark:bg-red-950, text-red-700 dark:text-red-400
// Warning: bg-yellow-100 dark:bg-yellow-950, text-yellow-700 dark:text-yellow-400
// Info: bg-blue-100 dark:bg-blue-950, text-blue-700 dark:text-blue-400

// ─── BORDER RADIUS ───────────────────────────────────────────────────────────

// Before:
// borderRadius: 14 (cards), 9999 (badges), 6 (buttons)

// After:
// rounded-sm (4px), rounded-md (6px), rounded-lg (8px), rounded-xl (14px), rounded-full (9999px)

// ─── SHADOWS ──────────────────────────────────────────────────────────────────

// Before:
// shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.05, shadowRadius: 2

// After:
// shadow-sm (subtle), shadow (medium), shadow-lg (prominent)

// ─── RESPONSIVE ──────────────────────────────────────────────────────────────

// Responsive prefixes:
// sm: (640px), md: (768px), lg: (1024px), xl: (1280px)

// Example:
// <View className="flex flex-col md:flex-row gap-4" />

// Hide/show at breakpoints:
// <View className="hidden lg:flex" /> {/* Hidden on mobile, shown on desktop */}

// ─── CONDITIONAL CLASSES ─────────────────────────────────────────────────────

// Before:
// style={[styles.button, isActive && { backgroundColor: colors.tint }]}

// After:
// className={cn(
//   'bg-gray-100 dark:bg-gray-800',
//   isActive && 'bg-indigo-600 dark:bg-indigo-500'
// )}

// ─── COMPONENT PATTERN ───────────────────────────────────────────────────────

// New component signature pattern:

interface ComponentProps {
  className?: string;
  // ... other props
}

export function Component({ className, ...props }: ComponentProps) {
  return (
    <View
      className={cn(
        'flex flex-row items-center gap-2',      // Base layout
        'px-4 py-2',                              // Spacing
        'bg-white dark:bg-neutral-900',          // Colors
        'border border-gray-200 dark:border-neutral-800', // Borders
        'rounded-lg',                             // Shape
        'shadow-sm',                              // Shadow
        className                                 // Custom overrides
      )}
    >
      <Text className="text-sm font-medium text-neutral-900 dark:text-white">
        Label
      </Text>
    </View>
  );
}

// ─── MIGRATION CHECKLIST ─────────────────────────────────────────────────────

// When converting a component:
// ☐ Remove useThemeColors() hook import
// ☐ Remove colors prop from component interface
// ☐ Remove StyleSheet.create() definition
// ☐ Replace all style props with className
// ☐ Use cn() utility for conditional classes
// ☐ Add dark: prefix to all colors for dark mode support
// ☐ Replace padding values: px-X, py-X (X = spacing value in tailwind scale)
// ☐ Replace gaps: gap-X
// ☐ Replace flex properties: flex flex-row/col, items-X, justify-X
// ☐ Replace border-radius: rounded-X
// ☐ Add type-safe variants for complex components

// ─── COMMON CONVERSIONS ──────────────────────────────────────────────────────

// StyleSheet → Tailwind:

// PADDING
// paddingHorizontal: 16     → px-4
// paddingVertical: 12       → py-3
// paddingHorizontal: 24     → px-6

// GAP
// gap: 8                    → gap-2
// gap: 12                   → gap-3
// gap: 16                   → gap-4
// gap: 24                   → gap-6

// FLEXBOX
// flexDirection: 'row'      → flex-row
// flexDirection: 'column'   → flex-col
// alignItems: 'center'      → items-center
// justifyContent: 'center'  → justify-center
// justifyContent: 'space-between' → justify-between

// BORDERS
// borderRadius: 14          → rounded-xl
// borderWidth: 1            → border
// borderColor: colors.border → border-gray-200 dark:border-neutral-800

// TEXT
// fontSize: 16              → text-base
// fontWeight: '600'         → font-semibold
// color: colors.text        → text-neutral-900 dark:text-white

// ─── DARK MODE PATTERN ───────────────────────────────────────────────────────

// Always pair light and dark colors:
// <Text className="text-neutral-900 dark:text-white" />
// <View className="bg-white dark:bg-neutral-900" />
// <View className="border border-gray-200 dark:border-neutral-800" />

// ─── UTILITIES ────────────────────────────────────────────────────────────────

// getStatusBadgeClasses(status) → Returns { container, dot, text }
// getTypeBadgeClasses(type) → Returns { container, text }
// getProgressBarClasses(percentage) → Returns { container, bar, barFill, text }
// getCardClasses() → Base card styling
// getInputClasses() → Input field styling
// getButtonClasses(variant) → Button with variants: primary, secondary, ghost
// getPageClasses() → Page/screen container styling
// getSidebarClasses() → Sidebar styling
// getGridClasses(cols) → Responsive grid: auto, 1, 2, 3, 4, 6
// getFlexClasses() → Flex container with options
// getTypographyClasses(variant) → Typography variants: h1-h4, body, small, caption
// cn(...classes) → Class name joiner with falsy filtering

// ─── EXAMPLE CONVERSIONS ─────────────────────────────────────────────────────

// BEFORE (Card Component):
// interface CardProps { colors: ThemeColors; style?: ViewStyle; }
// <View style={[styles.card, { backgroundColor: colors.card, borderColor: colors.border }, style]}>
//   {children}
// </View>
// const styles = StyleSheet.create({
//   card: { borderRadius: 14, borderWidth: 1, paddingVertical: 24, gap: 24, ... }
// });

// AFTER (Card Component):
// interface CardProps { className?: string; }
// <View className={cn('bg-white dark:bg-neutral-900', 'border border-gray-200 dark:border-neutral-800',
//   'rounded-xl', 'px-6 py-6', 'gap-6', 'shadow-subtle', className)}>
//   {children}
// </View>

// ─── STATUS & PROGRESS ───────────────────────────────────────────────────────

// Conversion Status (completed/in progress/pending):
// ✅ tailwind.config.js - Complete with all design tokens
// ✅ lib/tailwind-utils.ts - All utility functions ready
// ✅ components/ui/card.tsx - Fully converted
// ✅ components/ui/progress-bar.tsx - Fully converted
// ✅ components/shared/status-badge.tsx - Fully converted
// ✅ components/shared/type-icon.tsx - Fully converted
// ✅ features/dashboard/stat-card.tsx - Fully converted
// ✅ features/dashboard/area-chart.tsx - Fully converted
// ✅ features/projects/project-card.tsx - Fully converted
// ✅ app/(tabs)/index.tsx (Dashboard) - Fully converted
// ⏳ Remaining 30+ components - Follow this guide for consistent conversion

export {};
