// ─── Button ───────────────────────────────────────────────────────────────
// Versatile button component with multiple variants and sizes.
// Supports default, destructive, outline, secondary, ghost, and link variants.
// Uses Pressable for better touch control and haptic feedback.

import React from 'react';
import { Pressable, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { cn } from '@/lib/tailwind-utils';

type ButtonVariant = 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link';
type ButtonSize = 'default' | 'xs' | 'sm' | 'lg' | 'icon' | 'icon-xs' | 'icon-sm' | 'icon-lg';

interface ButtonProps {
  children: React.ReactNode;
  variant?: ButtonVariant;
  size?: ButtonSize;
  onPress?: () => void;
  disabled?: boolean;
  className?: string;
  hapticFeedback?: boolean;
}

const getVariantClasses = (variant: ButtonVariant): string => {
  const variants: Record<ButtonVariant, string> = {
    default: 'bg-primary dark:bg-indigo-600 active:bg-indigo-700 dark:active:bg-indigo-700',
    destructive: 'bg-red-600 dark:bg-red-600 active:bg-red-700 dark:active:bg-red-700',
    outline:
      'bg-white dark:bg-neutral-900 border border-gray-200 dark:border-neutral-800 active:bg-gray-100 dark:active:bg-neutral-800',
    secondary:
      'bg-gray-100 dark:bg-neutral-800 active:bg-gray-200 dark:active:bg-neutral-700',
    ghost: 'active:bg-gray-100 dark:active:bg-neutral-800',
    link: 'underline',
  };
  return variants[variant];
};

const getTextColorClasses = (variant: ButtonVariant): string => {
  const colors: Record<ButtonVariant, string> = {
    default: 'text-white',
    destructive: 'text-white',
    outline: 'text-neutral-900 dark:text-white',
    secondary: 'text-neutral-900 dark:text-white',
    ghost: 'text-neutral-900 dark:text-white',
    link: 'text-primary dark:text-indigo-400',
  };
  return colors[variant];
};

const getSizeClasses = (size: ButtonSize): string => {
  const sizes: Record<ButtonSize, string> = {
    default: 'h-9 px-4 py-2',
    xs: 'h-6 px-2 py-1',
    sm: 'h-8 px-3 py-1.5',
    lg: 'h-10 px-6 py-2',
    icon: 'h-9 w-9',
    'icon-xs': 'h-6 w-6',
    'icon-sm': 'h-8 w-8',
    'icon-lg': 'h-10 w-10',
  };
  return sizes[size];
};

const getTextSizeClasses = (size: ButtonSize): string => {
  const textSizes: Record<ButtonSize, string> = {
    default: 'text-sm',
    xs: 'text-xs',
    sm: 'text-xs',
    lg: 'text-base',
    icon: 'text-sm',
    'icon-xs': 'text-xs',
    'icon-sm': 'text-xs',
    'icon-lg': 'text-sm',
  };
  return textSizes[size];
};

export function Button({
  children,
  variant = 'default',
  size = 'default',
  onPress,
  disabled = false,
  className,
  hapticFeedback = true,
}: ButtonProps) {
  const handlePress = async () => {
    if (hapticFeedback && !disabled) {
      await Haptics.selectionAsync();
    }
    onPress?.();
  };

  const isIconOnly = size.startsWith('icon');

  return (
    <Pressable
      onPress={handlePress}
      disabled={disabled}
      className={cn(
        'flex items-center justify-center rounded-md font-medium transition-all',
        getSizeClasses(size),
        getVariantClasses(variant),
        disabled && 'opacity-50',
        className
      )}
    >
      {typeof children === 'string' ? (
        <Text
          className={cn(
            'font-semibold',
            getTextColorClasses(variant),
            getTextSizeClasses(size),
            disabled && 'opacity-50'
          )}
        >
          {children}
        </Text>
      ) : (
        children
      )}
    </Pressable>
  );
}

export { ButtonVariant, ButtonSize };
