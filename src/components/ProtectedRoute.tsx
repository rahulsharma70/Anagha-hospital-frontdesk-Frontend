/**
 * Protected Route Component - Route guard for authenticated pages
 */

import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { Loader2 } from 'lucide-react';

interface ProtectedRouteProps {
  children: React.ReactElement;
  requireAuth?: boolean;
  allowedRoles?: string[];
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requireAuth = true,
  allowedRoles = [],
}) => {
  const { isAuthenticated, user, loading } = useAuth();
  const location = useLocation();

  // Show loading state while checking auth
  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  // Redirect to login if auth required but not authenticated
  if (requireAuth && !isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Check role-based access
  if (requireAuth && allowedRoles.length > 0 && user) {
    const userRole = user.role?.toLowerCase();
    const hasAccess = allowedRoles.some((role) => role.toLowerCase() === userRole);

    if (!hasAccess) {
      // Redirect to appropriate dashboard based on role
      if (userRole === 'doctor') {
        return <Navigate to="/doctor-dashboard" replace />;
      } else if (userRole === 'patient') {
        return <Navigate to="/patient-dashboard" replace />;
      } else if (userRole === 'pharma') {
        return <Navigate to="/pharma-dashboard" replace />;
      }
      return <Navigate to="/dashboard" replace />;
    }
  }

  // Render protected content
  return children;
};

