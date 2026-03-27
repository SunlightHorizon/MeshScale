import { useState } from 'react'
import { CameraSource } from '@capacitor/camera'
import {
  useCapacitorCamera,
  useCapacitorStorage,
  useNetworkStatus,
  useAppState,
} from '@/hooks'
import { isNative } from '@/lib/capacitor'

/**
 * Example component demonstrating Capacitor integration
 * Shows how to use camera, storage, and network detection
 */
export function CapacitorExample() {
  const [savedImage, setSavedImage] = useState<string | null>(null)
  const [savedText, setSavedText] = useState<string>('')
  const [textInput, setTextInput] = useState<string>('')

  const {
    takePicture,
    isLoading: isCameraLoading,
    error: cameraError,
  } = useCapacitorCamera()
  const {
    getItem,
    setItem,
    isLoading: isStorageLoading,
  } = useCapacitorStorage()
  const { isConnected, connectionType } = useNetworkStatus()
  const appState = useAppState()

  const handleTakePicture = async () => {
    try {
      const image = await takePicture(CameraSource.Camera)
      setSavedImage(image.dataUrl || null)
    } catch (error) {
      console.error('Failed to take picture:', error)
    }
  }

  const handlePickPhoto = async () => {
    try {
      const image = await takePicture(CameraSource.Photos)
      setSavedImage(image.dataUrl || null)
    } catch (error) {
      console.error('Failed to pick photo:', error)
    }
  }

  const handleSaveText = async () => {
    try {
      await setItem('example_text', textInput)
      setTextInput('')
      const saved = await getItem('example_text')
      setSavedText(saved || '')
    } catch (error) {
      console.error('Failed to save text:', error)
    }
  }

  const handleLoadText = async () => {
    try {
      const loaded = await getItem('example_text')
      setSavedText(loaded || '')
    } catch (error) {
      console.error('Failed to load text:', error)
    }
  }

  if (!isNative()) {
    return (
      <div className="p-4 text-yellow-600 bg-yellow-50 rounded-lg border border-yellow-200">
        <p>
          Capacitor features are only available on native platforms
          (iOS/Android)
        </p>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto p-6 space-y-6">
      <div className="rounded-lg border border-gray-200 p-4 space-y-2">
        <h2 className="text-lg font-semibold">App State</h2>
        <p className="text-sm text-gray-600">
          App is currently: <span className="font-medium">{appState}</span>
        </p>
      </div>

      <div className="rounded-lg border border-gray-200 p-4 space-y-2">
        <h2 className="text-lg font-semibold">Network Status</h2>
        <p className="text-sm text-gray-600">
          Connected:{' '}
          <span className="font-medium">{isConnected ? 'Yes' : 'No'}</span>
        </p>
        <p className="text-sm text-gray-600">
          Connection Type: <span className="font-medium">{connectionType}</span>
        </p>
      </div>

      <div className="rounded-lg border border-gray-200 p-4 space-y-4">
        <h2 className="text-lg font-semibold">Camera</h2>
        <div className="flex gap-2">
          <button
            onClick={handleTakePicture}
            disabled={isCameraLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {isCameraLoading ? 'Loading...' : 'Take Photo'}
          </button>
          <button
            onClick={handlePickPhoto}
            disabled={isCameraLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {isCameraLoading ? 'Loading...' : 'Pick Photo'}
          </button>
        </div>
        {cameraError && (
          <p className="text-sm text-red-600">Error: {cameraError.message}</p>
        )}
        {savedImage && (
          <div className="mt-4">
            <img
              src={savedImage}
              alt="Captured"
              className="max-w-full h-auto rounded-md"
            />
          </div>
        )}
      </div>

      <div className="rounded-lg border border-gray-200 p-4 space-y-4">
        <h2 className="text-lg font-semibold">Storage</h2>
        <div className="space-y-2">
          <input
            type="text"
            value={textInput}
            onChange={(e) => setTextInput(e.target.value)}
            placeholder="Enter text to save"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSaveText}
            disabled={isStorageLoading}
            className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"
          >
            {isStorageLoading ? 'Saving...' : 'Save Text'}
          </button>
          <button
            onClick={handleLoadText}
            disabled={isStorageLoading}
            className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"
          >
            {isStorageLoading ? 'Loading...' : 'Load Text'}
          </button>
        </div>
        {savedText && (
          <div className="mt-4 p-3 bg-gray-100 rounded-md">
            <p className="text-sm font-medium">Saved Text:</p>
            <p className="text-sm text-gray-700 mt-1">{savedText}</p>
          </div>
        )}
      </div>
    </div>
  )
}
