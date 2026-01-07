/**
 * Authentication utilities
 */
import { authAPI, setAuthToken, removeAuthToken } from './api';

// Exporting as an interface is correct
export interface User {
  id: number;
  name: string;
  mobile: string;
  email?: string;
  role: string;
  [key: string]: any;
}

// Check if user is authenticated (Check for token existence)
export const isAuthenticated = (): boolean => {
  return !!localStorage.getItem('authToken');
};

// Login function
export const login = async (mobile: string, password: string): Promise<User> => {
  try {
    const response = await authAPI.login(mobile, password);
    // Assuming response contains { access_token: string, user: User }
    setAuthToken(response.access_token);
    // Store user in localStorage for quick access
    if (response.user) {
      localStorage.setItem('user', JSON.stringify(response.user));
    }
    return response.user;
  } catch (error) {
    console.error("Login error:", error);
    throw error;
  }
};

// Register function
export const register = async (userData: {
  name: string;
  mobile: string;
  password: string;
  role?: string;
  email?: string;
}): Promise<User> => {
  try {
    const response = await authAPI.register(userData);
    setAuthToken(response.access_token);
    // Store user in localStorage for quick access
    if (response.user) {
      localStorage.setItem('user', JSON.stringify(response.user));
    }
    return response.user;
  } catch (error) {
    console.error("Registration error:", error);
    throw error;
  }
};

// Logout function
export const logout = (): void => {
  removeAuthToken();
  localStorage.removeItem('user');
  // Using window.location.href ensures a clean state wipe on logout
  window.location.href = '/login';
};

// Get current user from API
export const getCurrentUser = async (): Promise<User | null> => {
  try {
    if (!isAuthenticated()) {
      return null;
    }
    const user = await authAPI.getCurrentUser();
    // Update localStorage with fresh user data
    if (user) {
      localStorage.setItem('user', JSON.stringify(user));
    }
    return user;
  } catch (error) {
    // If the token is invalid/expired, clear it
    removeAuthToken();
    localStorage.removeItem('user');
    return null;
  }
};