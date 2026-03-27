import { useState, useCallback } from 'react'
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera'

export interface UseCapacitorCameraOptions {
  quality?: number
  width?: number
  height?: number
  source?: CameraSource
}

export function useCapacitorCamera(options: UseCapacitorCameraOptions = {}) {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const takePicture = useCallback(
    async (source: CameraSource = CameraSource.Camera) => {
      try {
        setIsLoading(true)
        setError(null)

        const image = await Camera.getPhoto({
          quality: options.quality || 90,
          allowEditing: false,
          resultType: CameraResultType.DataUrl,
          source: source,
          width: options.width,
          height: options.height,
        })

        return image
      } catch (err) {
        const error = err instanceof Error ? err : new Error(String(err))
        setError(error)
        throw error
      } finally {
        setIsLoading(false)
      }
    },
    [options],
  )

  return {
    takePicture,
    isLoading,
    error,
  }
}
