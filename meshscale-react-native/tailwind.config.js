/** @type {import('tailwindcss').Config} */
module.exports = {
  presets: [require('nativewind/preset')],
  content: [
    './app/**/*.{js,jsx,ts,tsx}',
    './components/**/*.{js,jsx,ts,tsx}',
    './features/**/*.{js,jsx,ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Sidebar theme colors with light/dark mode support
        sidebar: 'var(--sidebar)',
        'sidebar-foreground': 'var(--sidebar-foreground)',
        'sidebar-primary': 'var(--sidebar-primary)',
        'sidebar-primary-foreground': 'var(--sidebar-primary-foreground)',
        'sidebar-accent': 'var(--sidebar-accent)',
        'sidebar-accent-foreground': 'var(--sidebar-accent-foreground)',
        'sidebar-border': 'var(--sidebar-border)',
        'sidebar-ring': 'var(--sidebar-ring)',
        'muted-foreground': 'var(--muted-foreground)',
        
        // Semantic color system that works with light/dark modes
        primary: 'rgb(79 70 229 / <alpha-value>)',        // indigo-600
        'primary-dark': 'rgb(99 102 241 / <alpha-value>)', // indigo-500
        
        // Status colors
        success: {
          50: '#dcfce7',
          DEFAULT: '#16a34a',
          text: '#15803d',
        },
        stopped: {
          50: '#f3f4f6',
          DEFAULT: '#9ca3af',
          text: '#6b7280',
        },
        deploying: {
          50: '#fef9c3',
          DEFAULT: '#ca8a04',
          text: '#a16207',
        },
        error: {
          50: '#fee2e2',
          DEFAULT: '#ef4444',
          text: '#dc2626',
        },
        failed: {
          50: '#fee2e2',
          DEFAULT: '#ef4444',
          text: '#dc2626',
        },
        
        // Type colors
        'type-website': {
          50: '#dbeafe',
          text: '#1d4ed8',
        },
        'type-game-server': {
          50: '#f3e8ff',
          text: '#7c3aed',
        },
        'type-api': {
          50: '#dcfce7',
          text: '#15803d',
        },
        'type-worker': {
          50: '#fff7ed',
          text: '#c2410c',
        },
        'type-cron': {
          50: '#fef9c3',
          text: '#a16207',
        },
      },
      spacing: {
        // 8px base unit system
        0: '0',
        px: '1px',
        1: '4px',
        2: '8px',
        3: '12px',
        4: '16px',
        5: '20px',
        6: '24px',
        7: '28px',
        8: '32px',
        9: '36px',
        10: '40px',
        11: '44px',
        12: '48px',
        14: '56px',
        16: '64px',
        18: '72px',
        20: '80px',
        24: '96px',
        28: '112px',
        32: '128px',
      },
      borderRadius: {
        none: '0',
        sm: '4px',
        md: '6px',
        lg: '8px',
        xl: '12px',
        '2xl': '16px',
        full: '9999px',
      },
      fontSize: {
        xs: ['12px', { lineHeight: '16px', fontWeight: '500' }],
        sm: ['14px', { lineHeight: '18px', fontWeight: '400' }],
        base: ['16px', { lineHeight: '24px', fontWeight: '400' }],
        lg: ['16px', { lineHeight: '20px', fontWeight: '600' }],
        xl: ['18px', { lineHeight: '24px', fontWeight: '600' }],
        '2xl': ['24px', { lineHeight: '32px', fontWeight: '600' }],
        '3xl': ['30px', { lineHeight: '36px', fontWeight: '600' }],
      },
      shadows: {
        subtle: {
          shadowColor: '#000',
          shadowOffset: { width: 0, height: 1 },
          shadowOpacity: 0.05,
          shadowRadius: 2,
          elevation: 1,
        },
        card: {
          shadowColor: '#000',
          shadowOffset: { width: 0, height: 2 },
          shadowOpacity: 0.08,
          shadowRadius: 4,
          elevation: 2,
        },
      },
      width: {
        sidebar: '256px',
      },
      minWidth: {
        sidebar: '256px',
      },
    },
  },
  plugins: [],
}

