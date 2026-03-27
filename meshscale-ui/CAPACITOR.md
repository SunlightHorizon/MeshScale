# Capacitor Integration Guide

This guide covers the Capacitor setup for the MeshScale UI project, enabling native iOS and Android mobile app development.

## Setup

### Configuration

The main Capacitor configuration is in `capacitor.config.ts`:

- **App ID**: `com.meshscale.ui`
- **App Name**: `MeshScale`
- **Web Directory**: `dist` (output of the web build)

### Installed Plugins

The following Capacitor plugins are installed and configured:

- **@capacitor/core** (v8.1.0) - Core Capacitor library
- **@capacitor/cli** (v8.1.0) - Command-line interface for Capacitor
- **@capacitor/app** (v8.0.1) - App lifecycle management
- **@capacitor/camera** (v8.0.1) - Camera and photo gallery access
- **@capacitor/device** (v8.0.1) - Device information
- **@capacitor/network** (v8.0.1) - Network connectivity detection
- **@capacitor/preferences** (v8.0.1) - Persistent storage (formerly storage)
- **@capacitor/splash-screen** (v8.0.1) - Native splash screen

## NPM Scripts

New Capacitor-specific scripts have been added to `package.json`:

```bash
# Build web app and sync native projects
pnpm cap:build

# Sync native projects with latest web build
pnpm cap:sync

# Open iOS project in Xcode
pnpm cap:ios

# Open Android project in Android Studio
pnpm cap:android

# Add iOS platform (run once)
pnpm cap:add:ios

# Add Android platform (run once)
pnpm cap:add:android
```

## Hooks

React hooks are provided in `src/hooks/` for common Capacitor operations:

### `useAppState()`

Monitors app foreground/background state:

```typescript
import { useAppState } from '@/hooks'

export function MyComponent() {
  const appState = useAppState() // 'foreground' | 'background'

  return <div>App is {appState}</div>
}
```

### `useHardwareBackButton(callback)`

Handles Android hardware back button:

```typescript
import { useHardwareBackButton } from '@/hooks'

export function MyComponent() {
  useHardwareBackButton(() => {
    console.log('Back button pressed')
  })
}
```

### `useCapacitorCamera(options?)`

Access device camera and photo gallery:

```typescript
import { useCapacitorCamera } from '@/hooks'
import { CameraSource } from '@capacitor/camera'

export function PhotoCapture() {
  const { takePicture, isLoading, error } = useCapacitorCamera({
    quality: 90,
    width: 800,
    height: 800,
  })

  const handleCapture = async () => {
    try {
      const image = await takePicture(CameraSource.Camera)
      console.log('Image captured:', image.dataUrl)
    } catch (err) {
      console.error('Capture failed:', err)
    }
  }

  return (
    <>
      <button onClick={handleCapture} disabled={isLoading}>
        {isLoading ? 'Capturing...' : 'Take Photo'}
      </button>
      {error && <div>Error: {error.message}</div>}
    </>
  )
}
```

### `useCapacitorStorage()`

Persistent key-value storage using platform-native systems:

```typescript
import { useCapacitorStorage } from '@/hooks'

export function StorageExample() {
  const { getItem, setItem, removeItem, clear, isLoading } = useCapacitorStorage()

  const handleSave = async () => {
    await setItem('myKey', 'myValue')
  }

  const handleLoad = async () => {
    const value = await getItem('myKey')
    console.log('Loaded:', value)
  }

  const handleDelete = async () => {
    await removeItem('myKey')
  }

  const handleClear = async () => {
    await clear()
  }

  return (
    <>
      <button onClick={handleSave} disabled={isLoading}>Save</button>
      <button onClick={handleLoad} disabled={isLoading}>Load</button>
      <button onClick={handleDelete} disabled={isLoading}>Delete</button>
      <button onClick={handleClear} disabled={isLoading}>Clear All</button>
    </>
  )
}
```

### `useNetworkStatus()`

Monitor device network connectivity:

```typescript
import { useNetworkStatus } from '@/hooks'

export function NetworkStatus() {
  const { isConnected, connectionType, isLoading } = useNetworkStatus()

  if (isLoading) return <div>Checking network...</div>

  return (
    <>
      <div>Connected: {isConnected ? 'Yes' : 'No'}</div>
      <div>Type: {connectionType}</div>
    </>
  )
}
```

## Utility Functions

The `src/lib/capacitor.ts` module provides utility functions for platform detection:

```typescript
import { isCapacitorApp, getPlatform, isNative } from '@/lib/capacitor'

// Check if running in Capacitor
if (isCapacitorApp()) {
  console.log('Running on native platform')
}

// Get current platform
const platform = getPlatform() // 'ios' | 'android' | 'web'

// Check if on native (not web)
if (isNative()) {
  // Show native-only features
}
```

## Getting Started with Native Platforms

### Prerequisites

**For iOS:**

- macOS with Xcode installed
- iOS deployment target 13.0+

**For Android:**

- Android Studio
- Android SDK
- Java Development Kit (JDK)

### Initial Setup

The iOS and Android platforms have already been added to your project! The native project directories are:

- **iOS:** `ios/` (Xcode workspace ready)
- **Android:** `android/` (Android Studio project ready)

### Next Steps

1. **Build and sync the web app:**

   ```bash
   pnpm cap:build
   ```

2. **Open in Xcode:**

   ```bash
   npx cap open ios
   ```

3. **Open in Android Studio:**
   ```bash
   npx cap open android
   ```

### After Making Changes

Always sync changes to native projects:

```bash
pnpm cap:build    # Build web + sync all
# or
pnpm cap:sync     # Just sync without rebuilding
```

2. Add iOS platform:

   ```bash
   pnpm cap:add:ios
   ```

3. Add Android platform:

   ```bash
   pnpm cap:add:android
   ```

4. Open in native IDEs:
   ```bash
   pnpm cap:ios    # Opens Xcode
   pnpm cap:android # Opens Android Studio
   ```

### After Making Changes

Always sync changes to native projects:

```bash
pnpm cap:build    # Build web + sync all
# or
pnpm cap:sync     # Just sync without rebuilding
```

## Platform-Specific Configuration

### iOS (Info.plist)

Camera and photo permissions are required:

- `NSCameraUsageDescription` - Camera access
- `NSPhotoLibraryUsageDescription` - Photo library access

These should be automatically configured, but can be customized in Xcode.

### Android (AndroidManifest.xml)

Similar permissions are required:

- `android.permission.CAMERA`
- `android.permission.READ_EXTERNAL_STORAGE`

## Example Component

See `src/components/capacitor-example.tsx` for a complete working example that demonstrates:

- Camera/photo capture
- Storage operations
- Network status monitoring
- App state tracking

Import and use it:

```typescript
import { CapacitorExample } from '@/components/capacitor-example'

export function MyPage() {
  return <CapacitorExample />
}
```

## Common Issues

### Build Issues

If you encounter build issues, ensure:

1. Web app builds successfully: `pnpm build`
2. Native projects are synced: `pnpm cap:sync`
3. Clean and rebuild native projects in Xcode/Android Studio

### Plugin Not Found Errors

If a plugin isn't working:

1. Make sure it's installed: `pnpm add @capacitor/plugin-name`
2. Rebuild and sync: `pnpm cap:build`
3. Clean and rebuild native projects

### TypeScript Errors

All plugins include type definitions. If you see type errors:

1. Clear node_modules: `rm -rf node_modules && pnpm install`
2. Rebuild: `pnpm build`

## Resources

- [Capacitor Documentation](https://capacitorjs.com/docs)
- [Capacitor Plugins](https://capacitorjs.com/docs/plugins)
- [Capacitor iOS Guide](https://capacitorjs.com/docs/ios)
- [Capacitor Android Guide](https://capacitorjs.com/docs/android)
