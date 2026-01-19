/**
 * Loading Context - Manages global loading states to prevent UI flicker
 */

import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';

interface LoadingContextType {
  isLoading: boolean;
  setLoading: (loading: boolean) => void;
  withLoading: <T>(promise: Promise<T>) => Promise<T>;
}

const LoadingContext = createContext<LoadingContextType | undefined>(undefined);

export const useLoading = () => {
  const context = useContext(LoadingContext);
  if (context === undefined) {
    throw new Error('useLoading must be used within a LoadingProvider');
  }
  return context;
};

interface LoadingProviderProps {
  children: ReactNode;
}

export const LoadingProvider: React.FC<LoadingProviderProps> = ({ children }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [loadingCount, setLoadingCount] = useState(0);

  // Memoize setLoading to prevent infinite loops in useEffect dependencies
  const setLoading = useCallback((loading: boolean) => {
    setLoadingCount((prev) => {
      const newCount = loading ? prev + 1 : Math.max(0, prev - 1);
      setIsLoading(newCount > 0);
      return newCount;
    });
  }, []);

  const withLoading = useCallback(async <T,>(promise: Promise<T>): Promise<T> => {
    setLoading(true);
    try {
      const result = await promise;
      return result;
    } finally {
      setLoading(false);
    }
  }, [setLoading]);

  const value: LoadingContextType = {
    isLoading,
    setLoading,
    withLoading,
  };

  return <LoadingContext.Provider value={value}>{children}</LoadingContext.Provider>;
};

