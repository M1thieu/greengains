import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { signInUser, signInAsDemo } from '../api'

interface LoginProps {
  onLogin: () => void
}

export default function Login({ onLogin }: LoginProps) {
  const { t } = useTranslation()
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
      <div className="w-full max-w-sm">
        <div className="bg-[#0d1821] border border-slate-800 rounded-lg p-8">
          {/* Header */}
          <div className="text-center mb-8">
            <div className="flex items-center justify-center gap-3 mb-4">
              <div className="flex h-10 w-10 items-center justify-center rounded bg-[#10b981] text-white font-bold text-xs tracking-tight">
                GG
              </div>
              <div className="text-left">
                <h1 className="text-lg font-semibold text-white">{t('login.title')}</h1>
                <p className="text-[10px] text-slate-500 uppercase tracking-wider">{t('nav.platform')}</p>
              </div>
            </div>
            <p className="text-sm text-slate-400">{t('login.subtitle')}</p>
          </div>

          {/* Error Message */}
          {error && (
            <div className="mb-5 p-3 bg-red-500/10 border border-red-500/30 rounded text-red-400 text-xs">
              {error}
            </div>
          )}

          {/* Google Sign-in Button */}
          <button
            onClick={handleFirebaseLogin}
            disabled={isLoading}
            className="w-full bg-[#10b981] hover:bg-[#059669] disabled:bg-slate-700 disabled:text-slate-500 text-white font-medium py-2.5 rounded transition-colors duration-200 flex items-center justify-center gap-2 text-sm"
          >
            {isLoading ? (
              <>
                <div className="animate-spin h-3.5 w-3.5 border-2 border-white/30 border-t-white rounded-full" />
                {t('login.signingIn')}
              </>
            ) : (
              <>
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                </svg>
                {t('login.signInGoogle')}
              </>
            )}
          </button>

          {/* Divider */}
          <div className="relative my-5">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-slate-800" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="px-2 bg-[#0d1821] text-slate-600">or</span>
            </div>
          </div>

          {/* Demo Button */}
          <button
            onClick={handleDemoAccess}
            disabled={isLoading}
            className="w-full border border-slate-700 hover:border-slate-600 hover:bg-slate-800/30 disabled:opacity-40 text-slate-400 hover:text-slate-200 font-medium py-2.5 rounded transition-all duration-200 text-sm"
          >
            {isLoading ? t('login.loading') : t('login.demoAccess')}
          </button>

          <p className="text-center text-slate-600 text-[10px] mt-6 uppercase tracking-wider">
            {t('login.tagline')}
          </p>
        </div>
      </div>
    </div>
  )
}
