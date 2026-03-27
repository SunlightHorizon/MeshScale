import React, { createContext, useContext, useCallback, useMemo, useEffect } from 'react';
import { View, Text, TouchableOpacity, ScrollView, Modal, Pressable } from 'react-native';
import { X } from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getIconColor, type ColorScheme } from '@/theme/tokens';
import { useColorScheme } from 'nativewind';

const SIDEBAR_COOKIE_NAME = 'sidebar_state';
const SIDEBAR_COOKIE_MAX_AGE = 60 * 60 * 24 * 7;
const SIDEBAR_WIDTH = 256;
const SIDEBAR_WIDTH_MOBILE = 288;

type SidebarContextProps = {
  state: 'expanded' | 'collapsed';
  open: boolean;
  setOpen: (open: boolean) => void;
  openMobile: boolean;
  setOpenMobile: (open: boolean) => void;
  isMobile: boolean;
  toggleSidebar: () => void;
};

const SidebarContext = createContext<SidebarContextProps | null>(null);

export function useSidebar() {
  const context = useContext(SidebarContext);
  if (!context) {
    throw new Error('useSidebar must be used within a SidebarProvider.');
  }
  return context;
}

export function SidebarProvider({
  defaultOpen = true,
  open: openProp,
  onOpenChange: setOpenProp,
  children,
  isMobile: isMobileProp,
}: {
  defaultOpen?: boolean;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  children: React.ReactNode;
  isMobile?: boolean;
}) {
  const { colorScheme } = useColorScheme();
  const [openMobile, setOpenMobile] = React.useState(false);
  const [_open, _setOpen] = React.useState(defaultOpen);

  const open = openProp ?? _open;
  const setOpen = useCallback(
    (value: boolean | ((value: boolean) => boolean)) => {
      const openState = typeof value === 'function' ? value(open) : value;
      if (setOpenProp) {
        setOpenProp(openState);
      } else {
        _setOpen(openState);
      }
    },
    [setOpenProp, open]
  );

  const toggleSidebar = useCallback(() => {
    return isMobileProp ? setOpenMobile((open) => !open) : setOpen((open) => !open);
  }, [isMobileProp, setOpen, setOpenMobile]);

  const state = open ? 'expanded' : 'collapsed';

  const contextValue = useMemo<SidebarContextProps>(
    () => ({
      state,
      open,
      setOpen,
      isMobile: isMobileProp ?? false,
      openMobile,
      setOpenMobile,
      toggleSidebar,
    }),
    [state, open, setOpen, isMobileProp, openMobile, setOpenMobile, toggleSidebar]
  );

  return (
    <SidebarContext.Provider value={contextValue}>
      {children}
    </SidebarContext.Provider>
  );
}

export function Sidebar({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  const context = useContext(SidebarContext);
  const { colorScheme } = useColorScheme();
  const insets = useSafeAreaInsets();
  const scheme = (colorScheme === 'dark' ? 'dark' : 'light') as ColorScheme;

  // If no context, just render as static sidebar (not collapsible)
  if (!context) {
    return (
      <View
        className="bg-sidebar border-r border-sidebar-border flex-col"
        style={{
          width: SIDEBAR_WIDTH,
          paddingTop: insets.top,
          paddingBottom: insets.bottom,
        }}
      >
        <ScrollView className="flex-1" showsVerticalScrollIndicator={false}>
          {children}
        </ScrollView>
      </View>
    );
  }

  const { isMobile, openMobile, setOpenMobile } = context;

  if (isMobile) {
    return (
      <Modal
        visible={openMobile}
        transparent
        animationType="fade"
        onRequestClose={() => setOpenMobile(false)}
      >
        <View className="flex-1 flex-row">
          {/* Overlay */}
          <Pressable
            className="flex-1 bg-black/50"
            onPress={() => setOpenMobile(false)}
          />

          {/* Mobile Sidebar */}
          <View
            className="bg-sidebar border-r border-sidebar-border flex-col"
            style={{
              width: SIDEBAR_WIDTH_MOBILE,
              paddingTop: insets.top,
              paddingBottom: insets.bottom,
            }}
          >
            {/* Close button */}
            <View className="px-4 py-3 border-b border-sidebar-border">
              <TouchableOpacity
                onPress={() => setOpenMobile(false)}
                className="w-8 h-8 items-center justify-center"
              >
                <X
                  size={20}
                  color={getIconColor('sidebar', scheme)}
                  strokeWidth={2}
                />
              </TouchableOpacity>
            </View>

            {/* Content */}
            <ScrollView className="flex-1" showsVerticalScrollIndicator={false}>
              {children}
            </ScrollView>
          </View>
        </View>
      </Modal>
    );
  }

  return (
    <View
      className="bg-sidebar border-r border-sidebar-border flex-col"
      style={{
        width: SIDEBAR_WIDTH,
        paddingTop: insets.top,
        paddingBottom: insets.bottom,
      }}
    >
      <ScrollView className="flex-1" showsVerticalScrollIndicator={false}>
        {children}
      </ScrollView>
    </View>
  );
}

export function SidebarTrigger({
  className,
  onPress,
}: {
  className?: string;
  onPress?: () => void;
}) {
  const { toggleSidebar } = useSidebar();
  const { colorScheme } = useColorScheme();
  const scheme = (colorScheme === 'dark' ? 'dark' : 'light') as ColorScheme;

  return (
    <TouchableOpacity
      onPress={() => {
        onPress?.();
        toggleSidebar();
      }}
      className={`p-2 ${className}`}
    >
      <View className="w-6 h-6 items-center justify-center">
        <Text className="text-sidebar-foreground text-lg">☰</Text>
      </View>
    </TouchableOpacity>
  );
}

export function SidebarContent({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View className={`flex-1 gap-2 ${className}`}>
      {children}
    </View>
  );
}

export function SidebarGroup({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View className={`py-2 gap-1 ${className}`}>
      {children}
    </View>
  );
}

export function SidebarGroupLabel({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <Text
      className={`text-xs font-medium tracking-wide px-4 py-2 uppercase text-muted-foreground ${className}`}
    >
      {children}
    </Text>
  );
}

export function SidebarMenu({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View className={`gap-0.5 ${className}`}>
      {children}
    </View>
  );
}

export function SidebarMenuItem({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View className={`${className}`}>
      {children}
    </View>
  );
}

export function SidebarMenuButton({
  children,
  onPress,
  isActive = false,
  disabled = false,
  className,
}: {
  children: React.ReactNode;
  onPress?: () => void;
  isActive?: boolean;
  disabled?: boolean;
  className?: string;
}) {
  const { colorScheme } = useColorScheme();
  const scheme = (colorScheme === 'dark' ? 'dark' : 'light') as ColorScheme;

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.6}
      className={`flex-row items-center gap-2 px-3 py-1.5 mx-1 rounded-md border border-transparent ${
        isActive ? 'bg-sidebar-accent border-sidebar-border' : ''
      } ${disabled ? 'opacity-50' : ''} ${className}`}
    >
      {children}
    </TouchableOpacity>
  );
}

export function SidebarMenuBadge({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View
      className={`bg-sidebar-accent px-2 py-1 rounded items-center justify-center ${className}`}
    >
      <Text className="text-xs font-semibold text-sidebar-accent-foreground">
        {children}
      </Text>
    </View>
  );
}

export function SidebarHeader({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View
      className={`border-b border-sidebar-border px-4 py-2 gap-2 flex-row items-center ${className}`}
    >
      {children}
    </View>
  );
}

export function SidebarFooter({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <View
      className={`border-t border-sidebar-border px-4 py-2 gap-2 ${className}`}
    >
      {children}
    </View>
  );
}

export function SidebarSeparator({
  className,
}: {
  className?: string;
}) {
  return (
    <View className={`h-px bg-sidebar-border mx-2 ${className}`} />
  );
}
