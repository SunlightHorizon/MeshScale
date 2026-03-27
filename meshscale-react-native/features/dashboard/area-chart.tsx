// ─── AreaChart ───────────────────────────────────────────────────────────
// Simple stacked bar chart for the "Total Visitors" card on the dashboard.
// Renders 7 days of desktop + mobile visitor data.

import React from 'react';
import { View, Text } from 'react-native';

const CHART_DATA = [
  { date: 'Jun 24', desktop: 132, mobile: 180 },
  { date: 'Jun 25', desktop: 141, mobile: 190 },
  { date: 'Jun 26', desktop: 434, mobile: 380 },
  { date: 'Jun 27', desktop: 448, mobile: 490 },
  { date: 'Jun 28', desktop: 149, mobile: 200 },
  { date: 'Jun 29', desktop: 103, mobile: 160 },
  { date: 'Jun 30', desktop: 446, mobile: 400 },
];

const CHART_HEIGHT = 250;
const PRIMARY_COLOR = '#4f46e5'; // indigo-600 (light mode)
const PRIMARY_COLOR_DARK = '#6366f1'; // indigo-500 (dark mode)

interface AreaChartProps {
  className?: string;
}

export function AreaChart({ className }: AreaChartProps) {
  const max = Math.max(...CHART_DATA.map(d => d.desktop + d.mobile));

  return (
    <View style={{ height: CHART_HEIGHT }} className={className}>
      <View className="flex-1 flex-row items-end gap-1">
        {CHART_DATA.map((d, i) => {
          const totalH = ((d.desktop + d.mobile) / max) * (CHART_HEIGHT - 28);
          const desktopH = (d.desktop / (d.desktop + d.mobile)) * totalH;
          const mobileH = totalH - desktopH;

          return (
            <View key={i} className="flex-1 items-center justify-end" style={{ height: CHART_HEIGHT - 28 }}>
              <View className="w-full">
                <View
                  style={{
                    height: desktopH,
                    backgroundColor: PRIMARY_COLOR,
                    opacity: 0.9,
                    borderTopLeftRadius: 3,
                    borderTopRightRadius: 3,
                  }}
                />
                <View
                  style={{
                    height: mobileH,
                    backgroundColor: PRIMARY_COLOR,
                    opacity: 0.45,
                  }}
                />
              </View>
            </View>
          );
        })}
      </View>

      {/* X-axis labels */}
      <View className="flex-row mt-2">
        {CHART_DATA.map((d, i) => (
          <Text key={i} className="flex-1 text-xs text-center text-neutral-500 dark:text-neutral-500">
            {d.date}
          </Text>
        ))}
      </View>
    </View>
  );
}
