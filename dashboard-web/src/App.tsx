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
      <div className="min-h-screen bg-[#0b111c] flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin h-8 w-8 border-2 border-slate-700 border-t-[#10b981] rounded-full mx-auto mb-3" />
          <p className="text-xs text-slate-500 uppercase tracking-wider">Initializing</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#0b111c]">
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
