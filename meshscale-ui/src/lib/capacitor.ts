/**
 * Capacitor Integration Types
 * Provides type definitions and utilities for Capacitor native functionality
 */

export type { CameraResultType, CameraSource } from '@capacitor/camera'
export type { ConnectionStatus } from '@capacitor/network'
export type { PluginListenerHandle } from '@capacitor/core'

/**
 * Capacitor environment detection
 */
export function isCapacitorApp(): boolean {
  return (
    typeof window !== 'undefined' && (window as any).Capacitor !== undefined
  )
}

export function getPlatform(): 'ios' | 'android' | 'web' {
  if (!isCapacitorApp()) {
    return 'web'
  }

  const capacitor = (window as any).Capacitor
  return capacitor.getPlatform()
}

export function isNative(): boolean {
  const platform = getPlatform()
  return platform === 'ios' || platform === 'android'
}
