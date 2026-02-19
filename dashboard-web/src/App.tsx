import { useState } from 'react'
import { Toaster } from 'sonner'
import { AuthProvider, useAuth } from './AuthContext'
import { signOutUser } from './api'
import Dashboard from './components/Dashboard'
import Login from './components/Login'

function AppContent() {
  const { isLoggedIn, isLoading } = useAuth()
  const [error, setError] = useState<string | null>(null)

  const handleLogout = async () => {
    try {
      setError(null)
      await signOutUser()
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Logout failed'
      setError(message)
      console.error('Logout error:', err)
    }
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin h-12 w-12 border-4 border-slate-600 border-t-green-500 rounded-full mx-auto mb-4" />
          <p className="text-slate-300">Initializing...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800">
      {!isLoggedIn ? (
        <Login onLogin={() => {}} />
      ) : (
        <Dashboard onLogout={handleLogout} />
      )}
      {error && (
        <div className="fixed bottom-4 right-4 p-4 bg-red-500/20 border border-red-500 rounded text-red-300">
          {error}
        </div>
      )}
      <Toaster position="bottom-right" theme="dark" />
    </div>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
