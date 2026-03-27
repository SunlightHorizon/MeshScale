// ─── Card ────────────────────────────────────────────────────────────────────
// Reusable card shell matching shadcn Card: rounded-xl border py-6 gap-6.
// Used across dashboard, projects, settings, and project detail screens.

import React from 'react';
import { View, Text } from 'react-native';
import { cn } from '@/lib/tailwind-utils';

// ─── Card Container ──────────────────────────────────────────────────────────

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <View
      className={cn(
        'bg-white dark:bg-neutral-900',
        'border border-gray-200 dark:border-neutral-800',
        'rounded-lg',
        'px-6 py-6',
        'gap-6',
        'shadow-subtle',
        className
      )}
    >
      {children}
    </View>
  );
}

// ─── Card Header ─────────────────────────────────────────────────────────────

interface CardHeaderProps {
  title: string;
  subtitle?: string;
  children?: React.ReactNode; // For right-side actions
  className?: string;
}

export function CardHeader({ title, subtitle, children, className }: CardHeaderProps) {
  const hasActions = !!children;

  if (hasActions) {
    return (
      <View
        className={cn(
          'flex flex-row items-center justify-between gap-2 px-6',
          className
        )}
      >
        <View className="flex-1 gap-1">
          <Text className="text-base font-semibold text-neutral-900 dark:text-white">
            {title}
          </Text>
          {subtitle && (
            <Text className="text-sm text-neutral-600 dark:text-neutral-400">
              {subtitle}
            </Text>
          )}
        </View>
        {children}
      </View>
    );
  }

  return (
    <View className={cn('flex flex-col gap-1 px-6', className)}>
      <Text className="text-base font-semibold text-neutral-900 dark:text-white">
        {title}
      </Text>
      {subtitle && (
        <Text className="text-sm text-neutral-600 dark:text-neutral-400">
          {subtitle}
        </Text>
      )}
    </View>
  );
}

// ─── Card Content ────────────────────────────────────────────────────────────

interface CardContentProps {
  children: React.ReactNode;
  gap?: number;
  className?: string;
}

export function CardContent({ children, gap = 4, className }: CardContentProps) {
  const gapMap: Record<number, string> = {
    1: 'gap-1',
    2: 'gap-2',
    3: 'gap-3',
    4: 'gap-4',
    5: 'gap-5',
    6: 'gap-6',
    8: 'gap-8',
  };

  return (
    <View className={cn('flex flex-col px-6', gapMap[gap] || 'gap-4', className)}>
      {children}
    </View>
  );
}

// ─── Card Title ──────────────────────────────────────────────────────────

interface CardTitleProps {
  children: React.ReactNode;
  className?: string;
}

export function CardTitle({ children, className }: CardTitleProps) {
  return (
    <Text className={cn('text-base font-semibold text-neutral-900 dark:text-white', className)}>
      {children}
    </Text>
  );
}

// ─── Card Description ────────────────────────────────────────────────────

interface CardDescriptionProps {
  children: React.ReactNode;
  className?: string;
}

export function CardDescription({ children, className }: CardDescriptionProps) {
  return (
    <Text className={cn('text-sm text-neutral-600 dark:text-neutral-400', className)}>
      {children}
    </Text>
  );
}

// ─── Card Action ─────────────────────────────────────────────────────────

interface CardActionProps {
  children: React.ReactNode;
  className?: string;
}

export function CardAction({ children, className }: CardActionProps) {
  return (
    <View className={cn('flex items-center', className)}>
      {children}
    </View>
  );
}
