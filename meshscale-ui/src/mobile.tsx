import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import './styles.css'

// Polyfill for process
if (typeof (window as any).process === 'undefined') {
  ;(window as any).process = {
    env: {
      NODE_ENV: 'production',
    },
  }
}

console.log('[mobile.tsx] Starting app initialization')

// Define the component inline - no async imports
function MobileApp() {
  console.log('[mobile.tsx] MobileApp component rendering')
  return (
    <div
      style={{
        padding: '20px',
        fontFamily: 'system-ui',
        backgroundColor: '#f0f0f0',
        minHeight: '100vh',
      }}
    >
      <h1 style={{ color: '#333', marginBottom: '20px' }}>
        ✅ MeshScale Mobile App
      </h1>
      <div
        style={{
          backgroundColor: 'white',
          padding: '20px',
          borderRadius: '8px',
          marginBottom: '20px',
        }}
      >
        <p style={{ margin: '10px 0', color: '#666' }}>
          <strong>Status:</strong> React app is running!
        </p>
        <p style={{ margin: '10px 0', color: '#666', fontSize: '12px' }}>
          If you see this message, Capacitor and React are working correctly.
        </p>
      </div>

      <div
        style={{
          backgroundColor: '#e8f4f8',
          padding: '20px',
          borderRadius: '8px',
          marginTop: '20px',
        }}
      >
        <h3 style={{ margin: '0 0 10px 0', color: '#0066cc' }}>Next Steps:</h3>
        <ul
          style={{
            margin: '0',
            paddingLeft: '20px',
            color: '#333',
            textAlign: 'left',
          }}
        >
          <li>Add your dashboard components here</li>
          <li>Integrate the TanStack Router when ready</li>
          <li>Use Capacitor plugins for native features</li>
        </ul>
      </div>
    </div>
  )
}

console.log('[mobile.tsx] About to create React root')

const rootElement = document.getElementById('root')
console.log('[mobile.tsx] Root element found:', !!rootElement)

if (rootElement) {
  console.log('[mobile.tsx] Creating React root...')
  const root = createRoot(rootElement)

  console.log('[mobile.tsx] Rendering app...')
  root.render(
    <StrictMode>
      <MobileApp />
    </StrictMode>,
  )
  console.log('[mobile.tsx] App rendered successfully!')
} else {
  console.error('[mobile.tsx] Root element not found!')
}
