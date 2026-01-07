/**
 * API Service Layer
 * Handles all communication with the backend FastAPI server using axios
 */

import axios, { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from 'axios';

// API Base URL - use environment variable for production API domain
// Set VITE_API_BASE_URL in .env file: VITE_API_BASE_URL=https://api.anaghahealthconnect.com
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "";

// Create axios instance
const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000, // 30 seconds timeout
});

// Request interceptor - Add auth token from localStorage
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = localStorage.getItem('authToken');
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// Response interceptor - Handle auth errors globally
apiClient.interceptors.response.use(
  (response) => {
    return response;
  },
  (error: AxiosError) => {
    // Handle 401 Unauthorized - token expired or invalid
    if (error.response?.status === 401) {
      localStorage.removeItem('authToken');
      localStorage.removeItem('user');
      
      // Redirect to login if not already there
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }
    
    // Transform error to consistent format
    if (error.response) {
      const errorData = error.response.data as any;
      const errorMessage = errorData?.detail || errorData?.message || `HTTP error! status: ${error.response.status}`;
      return Promise.reject(new Error(errorMessage));
    }
    
    // Handle network errors
    if (error.message.includes('ECONNREFUSED') || error.message.includes('Network Error')) {
      return Promise.reject(new Error('Cannot connect to server. Please ensure the backend server is running.'));
    }
    
    return Promise.reject(error);
  }
);

// Helper function to get auth token from localStorage
export const getAuthToken = (): string | null => {
  return localStorage.getItem('authToken');
};

// Helper function to set auth token
export const setAuthToken = (token: string): void => {
  localStorage.setItem('authToken', token);
};

// Helper function to remove auth token
export const removeAuthToken = (): void => {
  localStorage.removeItem('authToken');
  localStorage.removeItem('user');
};

// Generic API request function (for backward compatibility)
export async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getAuthToken();
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      let errorData;
      try {
        errorData = await response.json();
      } catch {
        errorData = { detail: `HTTP error! status: ${response.status}` };
      }
      throw new Error(errorData.detail || errorData.message || `HTTP error! status: ${response.status}`);
    }

    // Handle empty responses
    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      return response.json();
    } else {
      return response.text() as any;
    }
  } catch (error) {
    // Re-throw if it's already an Error with a message
    if (error instanceof Error) {
      // Handle specific network errors
      if (error.message.includes('ECONNREFUSED') || error.message.includes('Failed to fetch')) {
        throw new Error('Cannot connect to server. Please ensure the backend server is running on port 3000.');
      }
      throw error;
    }
    // Handle network errors
    throw new Error('Failed to fetch. Please check your connection and ensure the server is running.');
  }
}

// Authentication API
export const authAPI = {
  // Login with mobile and password
  login: async (mobile: string, password: string) => {
    const response = await apiClient.post<{ access_token: string; token_type: string; user: any }>('/api/users/login', {
      mobile,
      password,
    });
    return response.data;
  },

  // Register new user
  register: async (userData: {
    name: string;
    mobile: string;
    password: string;
    role?: string;
    email?: string;
    city?: string;
    state?: string;
    specialty?: string;
  }) => {
    const response = await apiClient.post<{ access_token: string; token_type: string; user: any; message?: string }>('/api/users/register', userData);
    return response.data;
  },

  // Get current user info
  getCurrentUser: async () => {
    const response = await apiClient.get<any>('/api/users/me');
    return response.data;
  },
};

// Hospitals API
export const hospitalsAPI = {
  // Get all approved hospitals
  getApproved: async () => {
    const response = await apiClient.get<any[]>('/api/hospitals/approved');
    return response.data;
  },

  // Register new hospital
  register: async (hospitalData: any) => {
    const response = await apiClient.post<any>('/api/hospitals/register', hospitalData);
    return response.data;
  },

  // Get hospital by ID
  getById: async (id: number) => {
    const response = await apiClient.get<any>(`/api/hospitals/${id}`);
    return response.data;
  },
};

// Doctors API
export const doctorsAPI = {
  // Get all doctors (public endpoint - no auth required)
  getAll: async () => {
    try {
      // Try public endpoint first (for booking pages)
      const response = await apiClient.get<any[]>('/api/users/doctors/public');
      return response.data;
    } catch (error) {
      // Fallback to authenticated endpoint if public fails
      try {
        const response = await apiClient.get<any[]>('/api/users/doctors');
        return response.data;
      } catch (fallbackError) {
        // If both fail, return empty array
        console.error("Error fetching doctors:", fallbackError);
        return [];
      }
    }
  },
};

// Appointments API
export const appointmentsAPI = {
  // Book appointment
  book: async (appointmentData: {
    doctor_id: number;
    date: string;
    time_slot: string;
    reason?: string;
  }) => {
    const response = await apiClient.post<any>('/api/appointments/book', appointmentData);
    return response.data;
  },

  // Get my appointments
  getMyAppointments: async () => {
    const response = await apiClient.get<any[]>('/api/appointments/my-appointments');
    return response.data;
  },

  // Get doctor appointments
  getDoctorAppointments: async () => {
    const response = await apiClient.get<any[]>('/api/appointments/doctor-appointments');
    return response.data;
  },

  // Get available slots
  getAvailableSlots: async (doctorId: number, date: string) => {
    const response = await apiClient.get<{
      doctor_id: number;
      doctor_name: string;
      date: string;
      available_slots: string[];
      booked_slots: string[];
    }>(`/api/appointments/available-slots?doctor_id=${doctorId}&date=${date}`);
    return response.data;
  },

  // Confirm appointment
  confirm: async (appointmentId: number) => {
    const response = await apiClient.put<any>(`/api/appointments/${appointmentId}/confirm`);
    return response.data;
  },

  // Cancel appointment
  cancel: async (appointmentId: number) => {
    const response = await apiClient.put<any>(`/api/appointments/${appointmentId}/cancel`);
    return response.data;
  },

  // Mark as visited
  markVisited: async (appointmentId: number) => {
    const response = await apiClient.put<any>(`/api/appointments/${appointmentId}/mark-visited`);
    return response.data;
  },
};

// Operations API
export const operationsAPI = {
  // Book operation
  book: async (operationData: {
    hospital_id: number;
    doctor_id: number;
    date: string;  // Fixed: was 'operation_date', matches actual usage and backend
    specialty: string;
    notes?: string;  // Fixed: was 'reason', matches backend schema
  }) => {
    const response = await apiClient.post<any>('/api/operations/book', operationData);
    return response.data;
  },

  // Get my operations
  getMyOperations: async () => {
    const response = await apiClient.get<any[]>('/api/operations/my-operations');
    return response.data;
  },

  // Get doctor operations
  getDoctorOperations: async () => {
    const response = await apiClient.get<any[]>('/api/operations/doctor-operations');
    return response.data;
  },

  // Confirm operation
  confirm: async (operationId: number) => {
    const response = await apiClient.put<any>(`/api/operations/${operationId}/confirm`);
    return response.data;
  },

  // Cancel operation
  cancel: async (operationId: number) => {
    const response = await apiClient.put<any>(`/api/operations/${operationId}/cancel`);
    return response.data;
  },
};

// Payments API
export const paymentsAPI = {
  // Create payment order for appointments/operations
  createOrder: async (orderData: {
    appointment_id?: number;
    operation_id?: number;
    amount: number;
    currency?: string;
  }) => {
    const response = await apiClient.post<any>('/api/payments/create-order', {
      appointment_id: orderData.appointment_id || null,
      operation_id: orderData.operation_id || null,
      amount: orderData.amount,
      currency: orderData.currency || 'INR',
    });
    return response.data;
  },

  // Create hospital registration payment order
  createHospitalRegistrationOrder: async (planName: string, amount: number) => {
    const response = await apiClient.post<any>('/api/payments/create-order-hospital', {
      hospital_registration: true,
      plan_name: planName,
      amount: amount,
      currency: 'INR',
    });
    return response.data;
  },

  // Verify payment - ALWAYS verify via backend before confirming booking
  verifyPayment: async (paymentId: number) => {
    const response = await apiClient.post<any>(`/api/payments/verify/${paymentId}`);
    return response.data;
  },

  // Get payment status (for polling/resume)
  getPaymentStatus: async (paymentId: number) => {
    const response = await apiClient.get<any>(`/api/payments/${paymentId}/status`);
    return response.data;
  },

  // Get payment details
  getPayment: async (paymentId: number) => {
    const response = await apiClient.get<any>(`/api/payments/${paymentId}`);
    return response.data;
  },
};

// Admin API
export const adminAPI = {
  // Get pricing (admin only)
  getPricing: async () => {
    const response = await apiClient.get<any>('/api/admin/pricing');
    return response.data;
  },

  // Get public pricing (for hospital registration)
  getPublicPricing: async () => {
    const response = await apiClient.get<any>('/api/admin/pricing/public');
    return response.data;
  },

  // Update pricing
  updatePricing: async (pricingData: any) => {
    const response = await apiClient.post<any>('/api/admin/update-pricing', pricingData);
    return response.data;
  },
};

// Export axios instance for direct use if needed
export { apiClient };
