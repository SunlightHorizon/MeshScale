# MeshScale Design System

## Overview

This document describes the design system alignment between the React Native mobile app and the React web app (meshscale-ui). The React web app is the source of truth for design decisions, and the React Native app has been updated to match pixel-perfectly where possible, with documented exceptions for platform limitations.

## Design Token Updates

### Border Radius

| Component | Old (RN) | Web | New (RN) | Match |
|-----------|----------|-----|----------|-------|
| Card | 14px (xl) | 10px (lg) | 12px (lg) | ~2px tolerance ✓ |
| Project Card | 16px (2xl) | 10px (lg) | 8px (lg) | ~2px tolerance ✓ |
| Button | 8px (md) | 6px (md) | 8px (md) | ✓ |
| Badge | 9999px (full) | 9999px (full) | 9999px (full) | ✓ |

### Typography

| Element | Old (RN) | Web | New (RN) | Match |
|---------|----------|-----|----------|-------|
| base | 14px | 16px | 16px | ✓ |
| 2xl (stat values) | 20px | 24px | 24px | ✓ |
| 3xl (new) | N/A | 30px | 30px | ✓ |

**Line heights updated to match:**
- base: 20px → 24px
- 2xl: 28px → 32px
- 3xl: 36px (new)

### Colors (OKLCH → Hex)

Colors are already aligned. RN uses hex equivalents:

| Purpose | Web | RN Hex | Match |
|---------|-----|--------|-------|
| Primary | oklch(0.546 0.245 264) | #4f46e5 | ✓ |
| Border | oklch(0.9 0.015 264) | #e4e4ed | ✓ |
| Background (dark) | oklch(0.145 0 0) | #171717 | ✓ |

## Component Changes

### New: Button Component

**File:** `components/ui/button.tsx`

A new versatile button component was created for React Native, replacing scattered TouchableOpacity implementations across the codebase.

**Variants:**
- `default`: Primary indigo background
- `destructive`: Red background for destructive actions
- `outline`: Bordered, secondary style
- `secondary`: Gray background
- `ghost`: Transparent, hover-only
- `link`: Text-based, underlined

**Sizes:**
- `default`: h-9 (36px), standard button
- `xs`: h-6 (24px), compact
- `sm`: h-8 (32px), small
- `lg`: h-10 (40px), large
- `icon`, `icon-xs`, `icon-sm`, `icon-lg`: Square buttons for icons only

**Features:**
- Haptic feedback on press (via expo-haptics)
- Disabled state support
- Flexible children (text or custom elements)
- Dark mode support

**Platform Notes:**
- Uses Pressable instead of TouchableOpacity for better touch control
- No focus rings (not applicable to touch devices)
- Press animations via `active:` Tailwind classes

**Usage:**
```tsx
import { Button } from '@/components/ui/button';

<Button variant="default" size="sm" onPress={() => {}}>
  Submit
</Button>
```

### Updated: Card Component

**File:** `components/ui/card.tsx`

**Changes:**
- Border radius: `rounded-xl` (14px) → `rounded-lg` (12px)
- Added missing exports: `CardTitle`, `CardDescription`, `CardAction`

**New Exports:**
- `CardTitle`: Semantic text component (text-base, font-semibold)
- `CardDescription`: Semantic text component (text-sm, muted color)
- `CardAction`: Flex container for action badges/buttons in card headers

**Usage:**
```tsx
<Card>
  <CardHeader title="Title" subtitle="Subtitle" />
  <CardContent>
    {/* content */}
  </CardContent>
</Card>

// With actions
<View className="gap-2">
  <CardTitle>My Title</CardTitle>
  <CardDescription>My description</CardDescription>
</View>
```

## Component Updates

| Component | File | Changes |
|-----------|------|---------|
| StatCard | `features/dashboard/stat-card.tsx` | text-2xl → text-3xl for values |
| ProjectCard | `features/projects/project-card.tsx` | Border radius fixed, uses Button component |
| ProjectHeader | `features/project-detail/project-header.tsx` | Uses Button component |
| SettingsCards | `features/settings/settings-cards.tsx` | Uses Button component |
| ProjectsScreen | `app/(tabs)/projects.tsx` | New Deployment button uses Button |
| NewProjectScreen | `app/project/new.tsx` | Cancel/Deploy buttons use Button |

## Platform Differences (Acceptable)

### 1. Container Queries

**Web:** Uses CSS container queries to scale typography responsively
```css
@container (min-width: 500px) {
  .stat-value { font-size: 30px; }
}
```

**RN:** Fixed text-3xl (30px) on all screen sizes
- **Justification:** React Native doesn't support container queries; using responsive screen-width queries would be over-engineered
- **Result:** RN stat cards are always at 30px; web scales from 24px to 30px

### 2. Focus States

**Web:** Keyboard focus rings on interactive elements
```css
focus-visible: ring-ring/50 ring-[3px]
```

**RN:** Press states only (no keyboard input)
- **Justification:** Touch devices don't have keyboard focus; press feedback is platform-standard
- **Result:** RN buttons use `active:` styling instead of focus rings

### 3. Hover States

**Web:** Hover backgrounds on buttons and cards
```css
hover:bg-accent
```

**RN:** Active/press states only
- **Justification:** Touch devices don't have persistent hover
- **Result:** RN uses press feedback only

### 4. Shadow Rendering

**Web:** CSS box-shadow
```css
box-shadow: 0 1px 2px rgb(0 0 0 / 5%)
```

**RN:** Native elevation (Android) and shadowOffset/shadowOpacity (iOS)
```js
shadowColor: '#000'
shadowOffset: { width: 0, height: 1 }
shadowOpacity: 0.05
shadowRadius: 2
elevation: 1
```

- **Justification:** React Native uses platform-native shadow APIs; iOS and Android render slightly differently
- **Result:** Shadows are visually similar but not pixel-perfect due to platform rendering

### 5. Color Precision

**Web:** OKLCH color space (perceptually uniform)
- Example: `oklch(0.546 0.245 264)` for primary

**RN:** Hex colors (RGB approximation)
- Example: `#4f46e5` for primary

- **Justification:** React Native doesn't support OKLCH; hex equivalents are perceptually identical
- **Result:** Colors match visually; different representation only

## Must-Match Elements

The following must be pixel-perfect between platforms:

- ✓ Border radii (±2px tolerance)
- ✓ Typography sizes (exact)
- ✓ Spacing/padding (exact)
- ✓ Component structure (same semantic hierarchy)
- ✓ Badge sizes and shapes (exact)
- ✓ Button heights and padding (exact)
- ✓ Icon sizes (exact)
- ✓ Line heights (exact)

## Verification Checklist

### Visual Comparison

- [ ] Card border radius: ~10px on both platforms
- [ ] Stat card values: 30px on both platforms
- [ ] Button heights: h-9 (36px) default size
- [ ] Badge padding: px-2 py-0.5 exact match
- [ ] Project card corners: ~10px on both platforms
- [ ] Base typography: 16px on both platforms
- [ ] Status badges: Colors and sizes match exactly

### Device Testing

- [ ] iOS: iPhone SE (small screen)
- [ ] iOS: iPhone 15 Pro (standard)
- [ ] iOS: iPad Pro (large screen)
- [ ] Android: Pixel 5 (standard)
- [ ] Android: Pixel 7 (standard)

### Manual Screenshots

1. **Dashboard Screen**
   - Stat cards (values, badges, spacing)
   - Chart area (spacing, titles)
   - Services table (borders, headers)

2. **Projects Screen**
   - Project cards (corners, shadows, button)
   - Filter tabs (styling)
   - New Deployment button

3. **Project Detail Screen**
   - Header (spacing, buttons)
   - Navigation (tab styling)
   - Content sections (card styling)

4. **Settings Screen**
   - Profile card (inputs, button)
   - Preferences card (switches)
   - Security card (inputs, button)

### Comparison Process

1. Take screenshots at 375px width (iPhone SE equivalent) on both apps
2. Export side-by-side comparisons
3. Overlay at 50% opacity to identify misalignments
4. Verify:
   - Border radius: Use color picker tool to measure curves
   - Font sizes: Compare text height in pixels
   - Spacing: Measure gaps and padding
   - Colors: Ensure hex values match or use perceptual comparison

## Commands

### Run React Native App

```bash
cd meshscale-react-native
npm run ios    # iOS simulator
npm run android # Android simulator
npm start      # Expo development server
```

### Run Web App for Comparison

```bash
cd meshscale-ui
npm run dev
# Open http://localhost:3000 in browser at 375px width
```

### Screenshot Tools

**iOS:**
```bash
xcrun simctl io booted screenshot
```

**Android:**
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

## Future Considerations

### Not Implemented (Platform Limitations)

- Focus-visible rings: Not applicable to touch
- Container queries: Not supported in RN
- Hover states: Not applicable to touch
- OKLCH colors: Not supported in RN

### Potential Future Improvements

1. **Responsive Typography (Web → RN):**
   - Could implement screen-size breakpoints for typography scaling
   - Would require additional complexity; current fixed 30px is acceptable

2. **Haptic Feedback (Web → RN):**
   - Web could add haptic support with Vibration API (limited support)
   - RN already has expo-haptics integrated

3. **Animation Consistency:**
   - Web uses CSS transitions; RN uses React Native Animated API
   - Could implement custom animations for closer parity

4. **Dark Mode:**
   - Both apps support dark mode; verification needed for edge cases

## References

- **Web Design System:** `meshscale-ui/src/components/ui/`
- **Web Theme:** `meshscale-ui/src/app/globals.css`
- **RN Design System:** `meshscale-react-native/components/ui/`
- **RN Theme:** `meshscale-react-native/constants/theme.ts`
- **Tailwind Config (Web):** `meshscale-ui/tailwind.config.js`
- **Tailwind Config (RN):** `meshscale-react-native/tailwind.config.js`

## Contact

For design system questions or discrepancies, refer to:
- Web app source of truth: `meshscale-ui/`
- RN implementation guide: This document
