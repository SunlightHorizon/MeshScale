import { useCallback, useState } from 'react'
import { Preferences } from '@capacitor/preferences'

export function useCapacitorStorage() {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const getItem = useCallback(async (key: string) => {
    try {
      setIsLoading(true)
      setError(null)

      const { value } = await Preferences.get({ key })
      return value
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      setError(error)
      throw error
    } finally {
      setIsLoading(false)
    }
  }, [])

  const setItem = useCallback(async (key: string, value: string) => {
    try {
      setIsLoading(true)
      setError(null)

      await Preferences.set({ key, value })
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      setError(error)
      throw error
    } finally {
      setIsLoading(false)
    }
  }, [])

  const removeItem = useCallback(async (key: string) => {
    try {
      setIsLoading(true)
      setError(null)

      await Preferences.remove({ key })
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      setError(error)
      throw error
    } finally {
      setIsLoading(false)
    }
  }, [])

  const clear = useCallback(async () => {
    try {
      setIsLoading(true)
      setError(null)

      await Preferences.clear()
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      setError(error)
      throw error
    } finally {
      setIsLoading(false)
    }
  }, [])

  return {
    getItem,
    setItem,
    removeItem,
    clear,
    isLoading,
    error,
  }
}
