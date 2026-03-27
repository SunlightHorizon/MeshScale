import ReactDOM from 'react-dom/client'
import { RouterProvider } from '@tanstack/react-router'

import './styles.css'
import { getRouter } from './router'

// Initialize Capacitor plugins if available
async function initializeCapacitor() {
  try {
    const { App } = await import('@capacitor/app')
    console.log('Capacitor initialized')

    // Handle back button
    App.addListener('backButton', ({ canGoBack }) => {
      if (!canGoBack) {
        App.exitApp()
      } else {
        window.history.back()
      }
    })
  } catch (error) {
    console.log('Capacitor not available or app plugin not initialized', error)
  }
}

// Polyfill for process if not available
if (typeof (window as any).process === 'undefined') {
  ;(window as any).process = {
    env: {
      NODE_ENV: import.meta.env.MODE,
    },
  }
}

async function main() {
  await initializeCapacitor()

  const router = getRouter()

  const rootElement = document.getElementById('root')
  if (!rootElement) {
    throw new Error('Root element not found')
  }

  const root = ReactDOM.createRoot(rootElement)
  root.render(<RouterProvider router={router} />)
}

main().catch(console.error)
