import { createContext, useContext, useEffect, useState, ReactNode } from 'react'
import { User } from 'firebase/auth'
import { onAuthStateChange } from './api'

interface AuthContextType {
  user: User | null
  isLoading: boolean
  isLoggedIn: boolean
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    // Listen to auth state changes
    const unsubscribe = onAuthStateChange((authUser) => {
      setUser(authUser)
      setIsLoading(false)
    })

    return unsubscribe
  }, [])

  const value: AuthContextType = {
    user,
    isLoading,
    // Anonymous users (PublicLanding signInAsDemo) must NOT count as logged-in
    isLoggedIn: !!(user && !user.isAnonymous),
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
