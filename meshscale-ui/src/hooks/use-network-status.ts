import { useEffect, useState } from 'react'
import { Network, ConnectionStatus } from '@capacitor/network'

export interface NetworkState {
  isConnected: boolean
  connectionType: string
}

export function useNetworkStatus() {
  const [networkState, setNetworkState] = useState<NetworkState>({
    isConnected: true,
    connectionType: 'wifi',
  })
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    let unsubscribe: any = null

    const setupListener = async () => {
      try {
        // Get initial network status
        const status = await Network.getStatus()
        setNetworkState({
          isConnected: status.connected,
          connectionType: status.connectionType,
        })
        setIsLoading(false)

        // Listen for network changes
        const subscription = await Network.addListener(
          'networkStatusChange',
          (status: ConnectionStatus) => {
            setNetworkState({
              isConnected: status.connected,
              connectionType: status.connectionType,
            })
          },
        )

        unsubscribe = subscription
      } catch (error) {
        console.error('Error setting up network listener:', error)
        setIsLoading(false)
      }
    }

    setupListener()

    return () => {
      if (unsubscribe) {
        unsubscribe.remove()
      }
    }
  }, [])

  return {
    ...networkState,
    isLoading,
  }
}
