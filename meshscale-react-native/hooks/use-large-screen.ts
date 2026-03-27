import { useWindowDimensions } from 'react-native';

/**
 * Returns true when the window width is >= 768px.
 * Used to switch between bottom-tab navigation (phones)
 * and persistent sidebar navigation (iPads / large screens).
 * Mirrors the web app's useIsMobile() breakpoint of 768px.
 */
export function useLargeScreen(): boolean {
  const { width } = useWindowDimensions();
  return width >= 768;
}
