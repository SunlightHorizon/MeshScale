import { useEffect, useState } from 'react'
import { App } from '@capacitor/app'

export function useAppState() {
  const [appState, setAppState] = useState<'foreground' | 'background'>(
    'foreground',
  )

  useEffect(() => {
    let unsubscribe: any = null

    const setupListener = async () => {
      const state = await App.getState()
      setAppState(state.isActive ? 'foreground' : 'background')

      const subscription = await App.addListener('appStateChange', (s: any) => {
        setAppState(s.isActive ? 'foreground' : 'background')
      })

      unsubscribe = subscription
    }

    setupListener()

    return () => {
      if (unsubscribe) {
        unsubscribe.remove()
      }
    }
  }, [])

  return appState
}

export function useHardwareBackButton(callback: () => void) {
  useEffect(() => {
    let unsubscribe: any = null

    const setupListener = async () => {
      const subscription = await App.addListener('backButton', () => {
        callback()
      })
      unsubscribe = subscription
    }

    setupListener()

    return () => {
      if (unsubscribe) {
        unsubscribe.remove()
      }
    }
  }, [callback])
}
