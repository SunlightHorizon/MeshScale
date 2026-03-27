// ─── Settings Screen ─────────────────────────────────────────────────────────
// Account settings with profile, preferences, and security cards.

import React, { useState } from 'react';
import { View, Text, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useLargeScreen } from '@/hooks/use-large-screen';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { ProfileCard, PreferencesCard, SecurityCard } from '@/features/settings/settings-cards';

export default function SettingsScreen() {
  const colorScheme = useColorScheme();
  const isLargeScreen = useLargeScreen();

  const [name, setName] = useState('shadcn');
  const [email, setEmail] = useState('m@example.com');
  const [emailNotifs, setEmailNotifs] = useState(true);
  const [marketingEmails, setMarketingEmails] = useState(false);
  const [darkMode, setDarkMode] = useState(colorScheme === 'dark');

  return (
    <SafeAreaView className="flex-1 bg-white dark:bg-neutral-900">
      {/* Header */}
      <View className="border-b border-gray-200 px-4 py-3 dark:border-neutral-800">
        <Text className="text-base font-medium text-neutral-900 dark:text-white">Settings</Text>
      </View>

      <ScrollView contentContainerStyle={{ padding: 16, gap: 24 }} showsVerticalScrollIndicator={false}>
        {/* Page heading */}
        <View className="gap-2">
          <Text className="text-2xl font-semibold text-neutral-900 dark:text-white">Settings</Text>
          <Text className="text-sm leading-5 text-neutral-500 dark:text-neutral-400">
            Manage your account settings and preferences
          </Text>
        </View>

        <View className="h-px bg-gray-200 dark:bg-neutral-800" />

        {isLargeScreen ? (
          <View className="flex flex-row gap-6 items-start">
            <View className="flex-1">
              <ProfileCard
                name={name}
                onNameChange={setName}
                email={email}
                onEmailChange={setEmail}
              />
            </View>
            <View className="flex-1 gap-6">
              <PreferencesCard
                emailNotifs={emailNotifs}
                onEmailNotifsChange={setEmailNotifs}
                marketingEmails={marketingEmails}
                onMarketingEmailsChange={setMarketingEmails}
                darkMode={darkMode}
                onDarkModeChange={setDarkMode}
              />
              <SecurityCard />
            </View>
          </View>
        ) : (
          <>
            <ProfileCard
              name={name}
              onNameChange={setName}
              email={email}
              onEmailChange={setEmail}
            />
            <PreferencesCard
              emailNotifs={emailNotifs}
              onEmailNotifsChange={setEmailNotifs}
              marketingEmails={marketingEmails}
              onMarketingEmailsChange={setMarketingEmails}
              darkMode={darkMode}
              onDarkModeChange={setDarkMode}
            />
            <SecurityCard />
          </>
        )}

        <View style={{ height: 20 }} />
      </ScrollView>
    </SafeAreaView>
  );
}
