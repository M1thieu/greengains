import { useState } from 'react'
import { signInUser, signInAsDemo } from '../api'

interface LoginProps {
  onLogin: () => void
}

export default function Login({ onLogin }: LoginProps) {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleFirebaseLogin = async () => {
    setIsLoading(true)
    setError(null)
    try {
      await signInUser()
      onLogin()
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Sign in failed'
      setError(message)
      console.error('Login error:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const handleDemoAccess = async () => {
    setIsLoading(true)
    setError(null)
    try {
      // Demo access uses anonymous auth (no Google required)
      await signInAsDemo()
      onLogin()
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Demo access failed'
      setError(message)
      console.error('Demo login error:', err)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="w-full max-w-md">
        <div className="bg-slate-800 border border-slate-700 rounded-lg p-8 shadow-2xl">
          {/* Header */}
          <div className="text-center mb-8">
            <div className="flex items-center justify-center gap-3 mb-4">
              <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-gradient-to-br from-green-400 to-emerald-600 text-white font-bold">
                GG
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">GreenGains</h1>
                <p className="text-xs text-slate-400 uppercase tracking-wide">Analytics Platform</p>
              </div>
            </div>
          </div>

          {/* Description */}
          <div className="text-center mb-8">
            <h2 className="text-xl font-semibold text-white mb-2">Welcome Back</h2>
            <p className="text-slate-400 text-sm">Sign in to your account to access real-time environmental data analytics</p>
          </div>

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-3 bg-red-500/20 border border-red-500/50 rounded text-red-300 text-sm">
              {error}
            </div>
          )}

          {/* Login Button */}
          <button
            onClick={handleFirebaseLogin}
            disabled={isLoading}
            className="w-full bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 disabled:from-slate-600 disabled:to-slate-700 text-white font-semibold py-3 rounded-lg transition-all duration-200 flex items-center justify-center gap-2"
          >
            {isLoading ? (
              <>
                <div className="animate-spin h-4 w-4 border-2 border-white border-t-transparent rounded-full" />
                Signing in...
              </>
            ) : (
              <>
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="currentColor"/>
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="currentColor"/>
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="currentColor"/>
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="currentColor"/>
                </svg>
                Sign in with Google
              </>
            )}
          </button>

          {/* Divider */}
          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-slate-600" />
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-2 bg-slate-800 text-slate-400">Or continue as demo</span>
            </div>
          </div>

          {/* Demo Button */}
          <button
            onClick={handleDemoAccess}
            disabled={isLoading}
            className="w-full border border-slate-600 hover:bg-slate-700/50 disabled:opacity-50 text-white font-semibold py-3 rounded-lg transition-all duration-200"
          >
            {isLoading ? 'Loading...' : 'Demo Access'}
          </button>

          {/* Footer */}
          <p className="text-center text-slate-500 text-xs mt-6">
            Enterprise-grade environmental monitoring platform
          </p>
        </div>
      </div>
    </div>
  )
}
