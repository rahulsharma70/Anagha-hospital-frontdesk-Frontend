/**
 * Global Loader Component - Shows loading overlay when any async operation is in progress
 */

import React from 'react';
import { useLoading } from '@/contexts/LoadingContext';
import { Loader2 } from 'lucide-react';

export const GlobalLoader: React.FC = () => {
  const { isLoading } = useLoading();

  if (!isLoading) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-background/80 backdrop-blur-sm">
      <div className="text-center">
        <Loader2 className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
        <p className="text-muted-foreground font-medium">Loading...</p>
      </div>
    </div>
  );
};

