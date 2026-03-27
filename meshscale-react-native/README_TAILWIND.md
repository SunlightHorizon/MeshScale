# MeshScale React Native - Tailwind CSS Edition

> **A modern React Native + Expo + Router application styled with Tailwind CSS/NativeWind**

This is a project management dashboard for deploying and monitoring web services, built with React Native for cross-platform support (iOS, Android, Web).

## 🎨 Styling Architecture

This project uses **Tailwind CSS with NativeWind** instead of React Native's StyleSheet. This provides:

- ✅ Utility-first styling approach
- ✅ Consistent design tokens in one place
- ✅ Built-in dark mode support
- ✅ Smaller bundle size
- ✅ Better developer experience

### Quick Reference

**Where to find what:**
- Design tokens → `tailwind.config.js`
- Tailwind setup → `global.css`, `babel.config.js`, `metro.config.js`
- Styling utilities → `lib/tailwind-utils.ts`
- Component examples → `components/ui/` and `components/shared/`
- Style guide → `TAILWIND_STYLE_GUIDE.md`
- Migration docs → `CONVERSION_COMPLETE.md`

---

## 📁 Project Structure

```
meshscale-react-native/
│
├── global.css                          # Tailwind CSS directives
├── tailwind.config.js                  # Design tokens & customizations
├── babel.config.js                     # Babel preset with NativeWind
├── metro.config.js                     # Metro bundler config
├── app.json                            # Expo app config
│
├── app/                                # Expo Router screens (file-based routing)
│   ├── _layout.tsx                     # Root layout
│   ├── (tabs)/                         # Tab navigation group
│   │   ├── _layout.tsx                 # Tab layout
│   │   ├── index.tsx                   # Dashboard screen
│   │   ├── projects.tsx                # Projects list
│   │   └── settings.tsx                # Settings
│   └── project/                        # Project detail routes
│       ├── [id].tsx                    # Project detail (dynamic)
│       └── new.tsx                     # New project creation
│
├── components/                         # Reusable UI components
│   ├── ui/                             # Atomic components
│   │   ├── card.tsx                    # Card container & subcomponents
│   │   ├── progress-bar.tsx            # Resource usage bar
│   │   ├── field-label.tsx             # Form labels
│   │   └── icon-symbol.tsx             # Icons (platform-specific)
│   ├── shared/                         # Domain components
│   │   ├── status-badge.tsx            # Status indicators
│   │   └── type-icon.tsx               # Project type icons
│   ├── layout/                         # Layout components
│   │   ├── app-sidebar.tsx             # Sidebar for desktop
│   │   ├── sidebar-layout.tsx          # Sidebar wrapper
│   │   └── haptic-tab.tsx              # Bottom tabs with haptics
│   └── external-link.tsx               # External link helper
│
├── features/                           # Feature-specific components
│   ├── dashboard/                      # Dashboard feature
│   │   ├── stat-card.tsx               # Stat cards
│   │   ├── area-chart.tsx              # Chart component
│   │   ├── services-table.tsx          # Services data table
│   │   └── cost-breakdown.tsx          # Cost breakdown card
│   ├── projects/                       # Projects feature
│   │   ├── project-card.tsx            # Project card
│   │   ├── project-filters.tsx         # Filter tabs
│   │   └── project-empty-state.tsx     # Empty state
│   ├── project-detail/                 # Project detail feature
│   │   ├── project-header.tsx          # Header section
│   │   ├── project-nav.tsx             # Navigation tabs
│   │   ├── overview-section.tsx        # Overview tab
│   │   ├── deployments-section.tsx     # Deployments tab
│   │   ├── logs-section.tsx            # Logs tab
│   │   ├── environment-section.tsx     # Environment tab
│   │   └── settings-section.tsx        # Settings tab
│   ├── new-project/                    # New project creation feature
│   │   ├── project-details-form.tsx    # Details form
│   │   └── deployment-config-form.tsx  # Deployment config form
│   └── settings/                       # Settings feature
│       └── settings-cards.tsx          # Settings cards
│
├── hooks/                              # Custom React hooks
│   ├── use-color-scheme.ts             # Detect light/dark mode
│   ├── use-color-scheme.web.ts         # Web-specific detection
│   ├── use-theme-colors.ts             # Get theme colors
│   ├── use-theme-color.ts              # Get individual color
│   └── use-large-screen.ts             # Detect large screen (≥768px)
│
├── lib/                                # Core business logic
│   ├── types.ts                        # TypeScript types
│   ├── store.tsx                       # React Context store
│   ├── tailwind-utils.ts               # Tailwind utility functions
│   ├── data.ts                         # Data utilities
│   ├── seed-data.ts                    # Mock data
│   └── constants/
│       ├── theme.ts                    # Theme configuration
│       └── project.ts                  # Project constants
│
├── constants/                          # Application constants
│   ├── theme.ts                        # Colors & typography
│   └── project.ts                      # Project types & labels
│
└── assets/                             # Images, fonts, etc.
    └── images/
```

---

## 🎯 Key Components Explained

### UI Components

**Card** (`components/ui/card.tsx`)
```tsx
<Card>                                        {/* Container */}
  <CardHeader title="Title" subtitle="Sub" /> {/* Header with title */}
  <CardContent>                              {/* Content area */}
    {/* Child elements */}
  </CardContent>
</Card>
```

**Progress Bar** (`components/ui/progress-bar.tsx`)
```tsx
<ProgressBar label="CPU" value={75} />
{/* Renders labeled progress bar with color-coded percentage */}
```

**Badges** (`components/shared/status-badge.tsx`)
```tsx
<StatusBadge status="running" />     {/* Colored status indicator */}
<TypeBadge type="api" label="API" /> {/* Type indicator badge */}
```

### Feature Components

**StatCard** (`features/dashboard/stat-card.tsx`)
```tsx
<StatCard
  description="Active Services"
  Icon={Server}
  value="42"
  valueSuffix="/50"
  badgeText="50 total"
  badgeTrending="up"
  footerBold="42 running"
  footerMuted="Websites and APIs"
/>
```

**ProjectCard** (`features/projects/project-card.tsx`)
```tsx
{projects.map(project => (
  <ProjectCard key={project.id} project={project} />
))}
```

---

## 🎨 Tailwind Classes Quick Reference

### Layout
```tsx
// Flexbox
<View className="flex flex-row items-center justify-between gap-4" />

// Grid (responsive)
<View className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" />

// Spacing
<View className="px-4 py-3 gap-2" />

// Sizing
<View className="w-full h-12" />
```

### Colors
```tsx
// Text colors
<Text className="text-neutral-900 dark:text-white" />

// Background colors
<View className="bg-white dark:bg-neutral-900" />

// Border colors
<View className="border border-gray-200 dark:border-neutral-800" />

// Status colors
<View className="text-green-700 dark:text-green-400" /> {/* success */}
<View className="text-red-700 dark:text-red-400" />    {/* error */}
```

### Typography
```tsx
// Sizes
text-xs   {/* 12px - captions */}
text-sm   {/* 14px - small text */}
text-base {/* 14px - body text */}
text-lg   {/* 16px - heading 3 */}
text-xl   {/* 18px - heading 2 */}

// Weights
font-normal    {/* 400 */}
font-medium    {/* 500 */}
font-semibold  {/* 600 */}
font-bold      {/* 700 */}
```

### Interactive States
```tsx
// Hover
hover:bg-gray-100 dark:hover:bg-neutral-800

// Active
active:bg-gray-200 dark:active:bg-neutral-700

// Disabled
disabled:opacity-50 disabled:cursor-not-allowed
```

### Responsive
```tsx
// Mobile first
<View className="p-4 sm:p-6 md:p-8 lg:p-12" />

// Hide/show at breakpoints
<View className="hidden md:flex" /> {/* Hidden on mobile, shown on tablet+ */}

// Responsive columns
className="grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
```

---

## 🌓 Dark Mode

Dark mode is automatically applied based on system settings. All components include dark mode styles:

```tsx
// Every color should have a dark: variant
className="bg-white dark:bg-neutral-900 text-neutral-900 dark:text-white"
```

The app automatically detects dark mode using:
```tsx
const scheme = useColorScheme(); // 'light' | 'dark'
```

---

## 🚀 Development Workflow

### Adding a New Component

1. **Create the file** in `components/ui/` or `features/`
2. **Use className** instead of StyleSheet
3. **Use `cn()` utility** for conditional classes
```tsx
import { cn } from '@/lib/tailwind-utils';

export function MyComponent({ isActive, className }) {
  return (
    <View
      className={cn(
        'px-4 py-2 rounded-md',              // Base
        'bg-white dark:bg-neutral-900',      // Colors
        'border border-gray-200 dark:border-neutral-800', // Border
        isActive && 'bg-indigo-600 text-white', // Conditional
        className                             // Custom override
      )}
    >
      {/* Content */}
    </View>
  );
}
```

### Styling a Component

1. **Start with layout**: `flex`, `flex-row`, `gap-*`
2. **Add colors**: Text, background, border with dark: variants
3. **Apply spacing**: `px-*`, `py-*`, `mb-*`
4. **Add typography**: `text-*`, `font-*`
5. **Use utilities**: `rounded-*`, `shadow-*`

---

## 📱 Responsive Design

The app detects screen size and adjusts layout:

```tsx
// Breakpoint: 768px
const isLargeScreen = useLargeScreen(); // >= 768px

// Mobile: 1 column grid
// Tablet: 2 column grid (768px+)
// Desktop: 3 column grid (1024px+)

numColumns = width >= 1024 ? 3 : isLargeScreen ? 2 : 1;
```

---

## 🗂️ Type System

All domain types are in `lib/types.ts`:

```tsx
interface Project {
  id: string;
  name: string;
  description: string;
  type: ProjectType; // 'website' | 'api' | 'game-server' | 'worker' | 'cron'
  status: ProjectStatus; // 'running' | 'stopped' | 'deploying' | 'error'
  region: string;
  url: string;
  uptime: string; // e.g. "99.5%"
  lastDeployed: string;
  lastDeployedBy: string;
  cpu: number; // 0-100
  memory: number; // 0-100
  instances: number;
}

interface Deployment {
  id: string;
  projectId: string;
  commit: string;
  branch: string;
  message: string;
  status: DeploymentStatus; // 'success' | 'failed' | 'in-progress'
  createdAt: string;
  duration: string;
  deployedBy: string;
}
```

---

## 🏪 State Management

Using React Context (no Redux/Zustand):

```tsx
// In component
const { projects, deployments, addProject, updateProject } = useStore();

// Add project
addProject({...newProject});

// Update project
updateProject(projectId, updates);
```

See `lib/store.tsx` for implementation.

---

## 📚 Documentation Files

- **TAILWIND_STYLE_GUIDE.md** - Comprehensive styling guide with examples
- **CONVERSION_COMPLETE.md** - Migration report and remaining work
- **README.md** - This file

---

## 🔧 Configuration Files

### `tailwind.config.js`
Defines all design tokens:
- Colors (semantic + status colors)
- Spacing scale (8px base)
- Border radius values
- Typography sizes
- Shadow definitions

### `babel.config.js`
NativeWind preset configuration for class detection

### `metro.config.js`
Metro bundler config with NativeWind plugin, points to `./global.css`

### `app.json`
Expo app configuration, with web bundler set to `metro`

---

## ✨ Best Practices

### ✅ DO

- Use `className` with Tailwind classes
- Use `cn()` utility for conditional styling
- Add dark mode support with `dark:` prefix
- Keep responsive design in mind
- Follow the spacing scale (use Tailwind values, not custom px)

### ❌ DON'T

- Use inline `style=` props
- Use `StyleSheet.create()`
- Pass `colors` prop to styled components
- Create custom pixel values (use Tailwind scale)
- Forget dark mode on color classes

---

## 🐛 Debugging

### Component not styled?
1. Check if `className` is on the element
2. Verify Tailwind class syntax is correct
3. Check if `dark:` prefix needed for dark mode
4. Look for typos in utility names

### Colors not dark mode?
1. Ensure `dark:` variants are applied
2. Check system dark mode is enabled
3. Test in device settings or browser dev tools

### Layout not responsive?
1. Check breakpoint prefixes (sm:, md:, lg:)
2. Verify responsive values in `tailwind.config.js`
3. Test on different screen sizes

---

## 📖 Learning Resources

- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [NativeWind Documentation](https://www.nativewind.dev/)
- [React Native Docs](https://reactnative.dev/)
- [Expo Router Guide](https://docs.expo.dev/router/introduction/)

---

## 🎓 Code Examples

### Responsive Card Layout
```tsx
<View className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 p-4">
  {items.map(item => (
    <Card key={item.id}>
      {/* Content */}
    </Card>
  ))}
</View>
```

### Form Field with Label
```tsx
<View className="flex flex-col gap-2">
  <Text className="text-sm font-medium text-neutral-900 dark:text-white">
    Label
  </Text>
  <TextInput
    className="px-3 py-2 border border-gray-200 dark:border-neutral-800 rounded-md"
    placeholder="Enter value..."
  />
</View>
```

### Status Badge
```tsx
<View className="flex flex-row items-center gap-1.5 px-2 py-0.5 rounded-full bg-green-100 dark:bg-green-950">
  <View className="w-1.5 h-1.5 rounded-full bg-green-600 dark:bg-green-500" />
  <Text className="text-xs font-medium text-green-700 dark:text-green-400">
    Running
  </Text>
</View>
```

---

## 📋 Checklist for New Contributors

- [ ] Read this README
- [ ] Review `TAILWIND_STYLE_GUIDE.md`
- [ ] Check `CONVERSION_COMPLETE.md` for current status
- [ ] Use Tailwind classes, not StyleSheet
- [ ] Add dark mode variants to all colors
- [ ] Test on mobile, tablet, and desktop
- [ ] Test in both light and dark modes
- [ ] Use `cn()` utility for conditional classes
- [ ] Follow spacing scale (no custom px values)

---

## 📞 Questions?

Refer to the documentation files:
1. Style issues → `TAILWIND_STYLE_GUIDE.md`
2. Migration questions → `CONVERSION_COMPLETE.md`
3. Component examples → See components/ directory

---

**Last Updated**: March 5, 2026
**Styling**: Tailwind CSS + NativeWind
**Status**: 85% Converted to Tailwind (see CONVERSION_COMPLETE.md)
