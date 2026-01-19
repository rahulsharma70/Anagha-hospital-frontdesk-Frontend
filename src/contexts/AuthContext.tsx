/**
 * Auth Context - Manages persistent authentication state
 */

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { getCurrentUser, login as authLogin, register as authRegister, logout as authLogout, type User } from '@/lib/auth';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  isAuthenticated: boolean;
  login: (mobile: string, password: string) => Promise<void>;
  register: (userData: {
    name: string;
    mobile: string;
    password: string;
    role?: string;
    email?: string;
  }) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  // Load user from localStorage and verify token on mount
  useEffect(() => {
    const loadUser = async () => {
      try {
        // Try to get user from localStorage first (for quick render)
        const storedUser = localStorage.getItem('user');
        if (storedUser) {
          try {
            const parsedUser = JSON.parse(storedUser);
            setUser(parsedUser);
          } catch {
            // Invalid stored user, clear it
            localStorage.removeItem('user');
          }
        }

        // Verify token with backend
        const currentUser = await getCurrentUser();
        if (currentUser) {
          setUser(currentUser);
          localStorage.setItem('user', JSON.stringify(currentUser));
        } else {
          setUser(null);
          localStorage.removeItem('user');
        }
      } catch (error) {
        console.error('Error loading user:', error);
        setUser(null);
        localStorage.removeItem('user');
      } finally {
        setLoading(false);
      }
    };

    loadUser();
  }, []);

  const login = async (mobile: string, password: string) => {
    const loggedInUser = await authLogin(mobile, password);
    setUser(loggedInUser);
    localStorage.setItem('user', JSON.stringify(loggedInUser));
  };

  const register = async (userData: {
    name: string;
    mobile: string;
    password: string;
    role?: string;
    email?: string;
    address_line1?: string;
    hospital_id?: number;
    degree?: string;
    institute_name?: string;
    company_name?: string;
    city?: string;
    state?: string;
    specialty?: string;
  }) => {
    const registeredUser = await authRegister(userData);
    setUser(registeredUser);
    localStorage.setItem('user', JSON.stringify(registeredUser));
  };

  const logout = () => {
    authLogout();
    setUser(null);
    localStorage.removeItem('user');
  };

  const refreshUser = async () => {
    try {
      const currentUser = await getCurrentUser();
      if (currentUser) {
        setUser(currentUser);
        localStorage.setItem('user', JSON.stringify(currentUser));
      } else {
        setUser(null);
        localStorage.removeItem('user');
      }
    } catch (error) {
      console.error('Error refreshing user:', error);
      setUser(null);
      localStorage.removeItem('user');
    }
  };

  const value: AuthContextType = {
    user,
    loading,
    isAuthenticated: !!user,
    login,
    register,
    logout,
    refreshUser,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

