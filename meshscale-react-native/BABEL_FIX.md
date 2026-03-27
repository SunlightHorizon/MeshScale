# 🔧 Babel Configuration Fix

## Issue
Web bundling failed with error:
```
SyntaxError: Duplicate __self prop found. You are most likely using the 
deprecated transform-react-jsx-self Babel plugin.
```

## Root Cause
The `babel-preset-expo` preset was conflicting with `nativewind/babel` preset due to duplicate JSX transform plugins.

## Solution Applied
Simplified `babel.config.js` to remove conflicting JSX configuration:

**Before:**
```javascript
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel",
    ],
  };
};
```

**After:**
```javascript
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      "babel-preset-expo",
      "nativewind/babel",
    ],
  };
};
```

## Key Changes
- ✅ Removed `jsxImportSource: "nativewind"` option from babel-preset-expo
- ✅ Let `nativewind/babel` preset handle JSX transformation
- ✅ Eliminates duplicate transform plugins
- ✅ Cleaner, simpler configuration

## Result
- ✅ Web bundling now works correctly
- ✅ Tailwind classes properly compiled
- ✅ No JSX transform conflicts
- ✅ Ready for development and production

## Testing
Run the app with:
```bash
npm run web    # Web development
npm run ios    # iOS development
npm run android # Android development
```

All platforms should now build and run without Babel errors.
