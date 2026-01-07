import { useState, useEffect, useRef } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Heart, User, Phone, Calendar, Clock, MapPin, Stethoscope, FileText, ArrowRight, CreditCard, Loader2, CheckCircle, XCircle, AlertCircle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { z } from "zod";
import { hospitalsAPI, doctorsAPI, appointmentsAPI, operationsAPI, paymentsAPI } from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { useLoading } from "@/contexts/LoadingContext";
import { load } from "@cashfreepayments/cashfree-js";

type BookingType = "appointment" | "operation";

const bookingSchema = z.object({
  patientName: z.string().trim().min(2, { message: "Name is required" }),
  phone: z.string().trim().min(10, { message: "Valid phone number is required" }),
  date: z.string().min(1, { message: "Date is required" }),
  time: z.string().min(1, { message: "Time is required" }),
  specialty: z.string().min(1, { message: "Specialty is required" }),
  doctor: z.string().min(1, { message: "Doctor is required" }),
  hospital: z.string().min(1, { message: "Hospital is required" }),
  notes: z.string().optional(),
});

type FormErrors = Partial<Record<keyof z.infer<typeof bookingSchema>, string>>;

const specialties = [
  "General Medicine",
  "Cardiology",
  "Orthopedics",
  "Neurology",
  "Dermatology",
  "Pediatrics",
  "Gynecology",
  "Ophthalmology",
  "ENT",
  "Dentistry",
];

// Payment state persistence key
const PAYMENT_STATE_KEY = "pending_payment_state";

interface PendingPaymentState {
  bookingId: number;
  bookingType: "appointment" | "operation";
  paymentId: number;
  paymentSessionId: string;
  timestamp: number;
}

const BookAppointment = () => {
  const [bookingType, setBookingType] = useState<BookingType>("appointment");
  const [hospitals, setHospitals] = useState<any[]>([]);
  const [doctors, setDoctors] = useState<any[]>([]);
  const [loadingData, setLoadingData] = useState(true);
  const [formData, setFormData] = useState({
    patientName: "",
    phone: "",
    date: "",
    time: "",
    specialty: "",
    doctor: "",
    hospital: "",
    notes: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  // Payment state
  const [paymentState, setPaymentState] = useState<PendingPaymentState | null>(null);
  const [paymentStatus, setPaymentStatus] = useState<"idle" | "pending" | "verifying" | "success" | "failed">("idle");
  const [verificationError, setVerificationError] = useState<string | null>(null);
  
  const { toast } = useToast();
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();
  const { setLoading } = useLoading();
  const [searchParams] = useSearchParams();
  
  const verificationPollIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const hasCheckedPaymentOnMountRef = useRef(false);

  // Load Cashfree SDK
  useEffect(() => {
    const loadCashfree = async () => {
      try {
        await load();
        console.log("Cashfree SDK loaded successfully");
      } catch (error) {
        console.error("Failed to load Cashfree SDK:", error);
      }
    };
    loadCashfree();
  }, []);

  // Check for pending payment on mount (resume payment after refresh)
  useEffect(() => {
    if (hasCheckedPaymentOnMountRef.current) return;
    hasCheckedPaymentOnMountRef.current = true;

    const checkPendingPayment = async () => {
      try {
        const storedState = localStorage.getItem(PAYMENT_STATE_KEY);
        if (!storedState) return;

        const pendingState: PendingPaymentState = JSON.parse(storedState);
        
        // Check if payment state is less than 24 hours old
        const stateAge = Date.now() - pendingState.timestamp;
        if (stateAge > 24 * 60 * 60 * 1000) {
          // Clear stale state
          localStorage.removeItem(PAYMENT_STATE_KEY);
          return;
        }

        // Check payment status from backend
        setPaymentState(pendingState);
        setPaymentStatus("verifying");
        await verifyPaymentStatus(pendingState.paymentId);
      } catch (error) {
        console.error("Error checking pending payment:", error);
        // Clear invalid state
        localStorage.removeItem(PAYMENT_STATE_KEY);
      }
    };

    checkPendingPayment();
  }, []);

  // Verify payment status with backend (NEVER trust client-side callback)
  const verifyPaymentStatus = async (paymentId: number): Promise<boolean> => {
    try {
      setPaymentStatus("verifying");
      setVerificationError(null);

      // ALWAYS verify via backend before confirming booking
      const statusResponse = await paymentsAPI.getPaymentStatus(paymentId);
      
      if (statusResponse.status === "COMPLETED") {
        // Payment verified - booking is confirmed by webhook
        setPaymentStatus("success");
        clearPaymentState();
        
        toast({
          title: "Payment Successful",
          description: "Your booking has been confirmed!",
        });

        // Redirect to appointments page after short delay
        setTimeout(() => {
          navigate("/my-appointments");
        }, 2000);
        
        return true;
      } else if (statusResponse.status === "FAILED") {
        setPaymentStatus("failed");
        setVerificationError("Payment failed. Please try again.");
        clearPaymentState();
        
        toast({
          title: "Payment Failed",
          description: "Your payment could not be processed. Please try again.",
          variant: "destructive",
        });
        
        return false;
      } else {
        // Still pending - continue polling
        setPaymentStatus("pending");
        return false;
      }
    } catch (error: any) {
      console.error("Error verifying payment:", error);
      setVerificationError(error.message || "Failed to verify payment status");
      setPaymentStatus("failed");
      return false;
    }
  };

  // Poll payment status (with exponential backoff)
  const startPaymentVerification = (paymentId: number) => {
    // Clear any existing interval
    if (verificationPollIntervalRef.current) {
      clearInterval(verificationPollIntervalRef.current);
    }

    let pollCount = 0;
    const maxPolls = 30; // Poll for up to 5 minutes (30 * 10s)
    
    verificationPollIntervalRef.current = setInterval(async () => {
      pollCount++;
      
      if (pollCount >= maxPolls) {
        // Stop polling after max attempts
        if (verificationPollIntervalRef.current) {
          clearInterval(verificationPollIntervalRef.current);
          verificationPollIntervalRef.current = null;
        }
        
        // Final verification attempt
        const verified = await verifyPaymentStatus(paymentId);
        if (!verified) {
          setVerificationError("Payment verification timed out. Please check your booking status manually.");
        }
        return;
      }

      const verified = await verifyPaymentStatus(paymentId);
      if (verified) {
        // Stop polling on success
        if (verificationPollIntervalRef.current) {
          clearInterval(verificationPollIntervalRef.current);
          verificationPollIntervalRef.current = null;
        }
      }
    }, 10000); // Poll every 10 seconds
  };

  const clearPaymentState = () => {
    localStorage.removeItem(PAYMENT_STATE_KEY);
    setPaymentState(null);
    if (verificationPollIntervalRef.current) {
      clearInterval(verificationPollIntervalRef.current);
      verificationPollIntervalRef.current = null;
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (verificationPollIntervalRef.current) {
        clearInterval(verificationPollIntervalRef.current);
      }
    };
  }, []);

  // Load hospitals and doctors
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const [hospitalsData, doctorsData] = await Promise.all([
          hospitalsAPI.getApproved().catch((err) => {
            console.error("Error fetching hospitals:", err);
            return [];
          }),
          doctorsAPI.getAll().catch((err) => {
            console.error("Error fetching doctors:", err);
            return [];
          }),
        ]);
        
        setHospitals(hospitalsData || []);
        setDoctors(doctorsData || []);
        
        if ((!hospitalsData || hospitalsData.length === 0) && (!doctorsData || doctorsData.length === 0)) {
          toast({
            title: "No Data Available",
            description: "Unable to load hospitals and doctors. Please check your connection and try again.",
            variant: "destructive",
          });
        }
      } catch (error: any) {
        console.error("Error fetching data:", error);
        toast({
          title: "Error",
          description: error.message || "Failed to load hospitals and doctors. Please refresh the page.",
          variant: "destructive",
        });
      } finally {
        setLoadingData(false);
        setLoading(false);
      }
    };
    fetchData();
  }, [toast, setLoading]);

  const handleChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setFormData((prev) => ({ ...prev, [field]: e.target.value }));
    if (errors[field as keyof FormErrors]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrors({});
    setVerificationError(null);

    const result = bookingSchema.safeParse(formData);
    
    if (!result.success) {
      const fieldErrors: FormErrors = {};
      result.error.errors.forEach((err) => {
        const field = err.path[0] as keyof FormErrors;
        fieldErrors[field] = err.message;
      });
      setErrors(fieldErrors);
      return;
    }

    // Check authentication
    if (!isAuthenticated) {
      toast({
        title: "Authentication Required",
        description: "Please login to book an appointment.",
        variant: "destructive",
      });
      navigate("/login", { state: { from: "/book-appointment" } });
      return;
    }

    setIsSubmitting(true);
    setLoading(true);

    try {
      const selectedHospital = hospitals.find(h => h.name === formData.hospital || h.id.toString() === formData.hospital);
      const selectedDoctor = doctors.find(d => d.name === formData.doctor || d.id.toString() === formData.doctor);
      
      if (!selectedHospital || !selectedDoctor) {
        throw new Error("Please select valid hospital and doctor");
      }

      // Convert time to time_slot format (HH:MM)
      const timeSlot = formData.time.includes(":") ? formData.time.substring(0, 5) : formData.time;

      // Step 1: Create booking (status: pending)
      let bookingResult: any;
      if (bookingType === "appointment") {
        bookingResult = await appointmentsAPI.book({
          doctor_id: selectedDoctor.id,
          date: formData.date,
          time_slot: timeSlot,
          reason: formData.notes || undefined,
        });
      } else {
        bookingResult = await operationsAPI.book({
          hospital_id: selectedHospital.id,
          doctor_id: selectedDoctor.id,
          date: formData.date,
          specialty: formData.specialty,
          notes: formData.notes || undefined,
        });
      }

      // Step 2: Create Cashfree payment order
      // TODO: Fetch consultation fee from hospital settings when endpoint is available
      const defaultAmount = 500; // Default consultation fee
      
      const orderData = await paymentsAPI.createOrder({
        appointment_id: bookingType === "appointment" ? bookingResult.id : undefined,
        operation_id: bookingType === "operation" ? bookingResult.id : undefined,
        amount: defaultAmount,
        currency: "INR",
      });

      if (!orderData || !orderData.payment_session_id) {
        throw new Error("Failed to create payment order");
      }

      // Step 3: Store payment state for resume after refresh
      const pendingState: PendingPaymentState = {
        bookingId: bookingResult.id,
        bookingType: bookingType,
        paymentId: orderData.payment_id,
        paymentSessionId: orderData.payment_session_id,
        timestamp: Date.now(),
      };
      
      setPaymentState(pendingState);
      localStorage.setItem(PAYMENT_STATE_KEY, JSON.stringify(pendingState));

      // Step 4: Open Cashfree payment checkout
      try {
        const cashfree = await load();
        
        const checkoutOptions = {
          paymentSessionId: orderData.payment_session_id,
          redirectTarget: "_self" as const,
        };

        // Open Cashfree checkout
        cashfree.checkout(checkoutOptions);
        
        // Set status to pending - we'll verify via backend after redirect
        setPaymentStatus("pending");
        
        // Start polling for payment status
        startPaymentVerification(orderData.payment_id);
        
      } catch (error: any) {
        setPaymentStatus("failed");
        setVerificationError(error.message || "Failed to initialize payment. Please try again.");
        clearPaymentState();
        
        toast({
          title: "Payment Error",
          description: error.message || "Failed to initialize payment. Please try again.",
          variant: "destructive",
        });
      }
    } catch (error: any) {
      console.error("Booking error:", error);
      setPaymentStatus("failed");
      clearPaymentState();
      
      toast({
        title: "Booking Failed",
        description: error.message || "Failed to book appointment. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
      setLoading(false);
    }
  };

  // Retry payment
  const handleRetryPayment = async () => {
    if (!paymentState) return;

    setVerificationError(null);
    setPaymentStatus("verifying");
    
    try {
      // Re-verify payment status
      const verified = await verifyPaymentStatus(paymentState.paymentId);
      
      if (!verified && paymentStatus !== "success") {
        // If still pending, resume polling
        startPaymentVerification(paymentState.paymentId);
      }
    } catch (error: any) {
      setVerificationError(error.message || "Failed to verify payment");
      setPaymentStatus("failed");
    }
  };

  const filteredDoctors = formData.specialty && doctors.length > 0
    ? doctors.filter(d => true) // Filter logic can be added here
    : doctors;

  if (loadingData) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-muted-foreground">Loading hospitals and doctors...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border">
        <div className="container mx-auto px-4 py-4">
          <Link to="/" className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-gradient-hero flex items-center justify-center shadow-soft">
              <Heart className="w-5 h-5 text-primary-foreground" />
            </div>
            <span className="font-bold text-xl text-foreground">Anagha Health</span>
          </Link>
        </div>
      </header>

      <div className="container mx-auto px-4 py-12">
        <div className="max-w-2xl mx-auto">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-foreground mb-2">
              Book Your {bookingType === "appointment" ? "Appointment" : "Operation"}
            </h1>
            <p className="text-muted-foreground">
              Schedule your healthcare visit with ease
            </p>
          </div>

          {/* Payment Status Banner */}
          {paymentStatus !== "idle" && (
            <div className={`mb-6 rounded-xl border p-4 ${
              paymentStatus === "success" 
                ? "bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800"
                : paymentStatus === "failed"
                ? "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800"
                : "bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800"
            }`}>
              <div className="flex items-start gap-3">
                {paymentStatus === "success" && <CheckCircle className="w-5 h-5 text-green-600 dark:text-green-400 mt-0.5" />}
                {paymentStatus === "failed" && <XCircle className="w-5 h-5 text-red-600 dark:text-red-400 mt-0.5" />}
                {(paymentStatus === "pending" || paymentStatus === "verifying") && (
                  <Loader2 className="w-5 h-5 text-blue-600 dark:text-blue-400 animate-spin mt-0.5" />
                )}
                
                <div className="flex-1">
                  {paymentStatus === "success" && (
                    <div>
                      <p className="text-sm font-medium text-green-900 dark:text-green-100">
                        Payment Successful!
                      </p>
                      <p className="text-xs text-green-700 dark:text-green-300 mt-1">
                        Your booking has been confirmed. Redirecting to appointments...
                      </p>
                    </div>
                  )}
                  
                  {paymentStatus === "failed" && (
                    <div>
                      <p className="text-sm font-medium text-red-900 dark:text-red-100">
                        Payment {verificationError ? "Verification Failed" : "Failed"}
                      </p>
                      <p className="text-xs text-red-700 dark:text-red-300 mt-1">
                        {verificationError || "Your payment could not be processed. Please try again."}
                      </p>
                      {paymentState && (
                        <Button
                          onClick={handleRetryPayment}
                          variant="outline"
                          size="sm"
                          className="mt-2"
                        >
                          Retry Payment Verification
                        </Button>
                      )}
                    </div>
                  )}
                  
                  {(paymentStatus === "pending" || paymentStatus === "verifying") && (
                    <div>
                      <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
                        {paymentStatus === "verifying" ? "Verifying Payment..." : "Payment Pending"}
                      </p>
                      <p className="text-xs text-blue-700 dark:text-blue-300 mt-1">
                        {paymentStatus === "verifying" 
                          ? "Please wait while we verify your payment with the payment gateway."
                          : "Please complete the payment or wait while we verify your payment status."}
                      </p>
                      {paymentState && paymentStatus === "pending" && (
                        <Button
                          onClick={handleRetryPayment}
                          variant="outline"
                          size="sm"
                          className="mt-2"
                        >
                          Check Payment Status
                        </Button>
                      )}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Booking Type Toggle */}
          <div className="flex gap-4 mb-8">
            <button
              type="button"
              onClick={() => setBookingType("appointment")}
              disabled={isSubmitting || paymentStatus === "verifying"}
              className={`flex-1 flex items-center justify-center gap-3 p-4 rounded-xl border-2 transition-all ${
                bookingType === "appointment"
                  ? "border-primary bg-primary/5 text-primary"
                  : "border-border bg-card hover:border-primary/50 text-muted-foreground"
              } disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              <Calendar className="w-6 h-6" />
              <span className="font-medium">Book Appointment</span>
            </button>
            <button
              type="button"
              onClick={() => setBookingType("operation")}
              disabled={isSubmitting || paymentStatus === "verifying"}
              className={`flex-1 flex items-center justify-center gap-3 p-4 rounded-xl border-2 transition-all ${
                bookingType === "operation"
                  ? "border-primary bg-primary/5 text-primary"
                  : "border-border bg-card hover:border-primary/50 text-muted-foreground"
              } disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              <Stethoscope className="w-6 h-6" />
              <span className="font-medium">Schedule Operation</span>
            </button>
          </div>

          {/* Form */}
          <div className="bg-card rounded-2xl shadow-elevated border border-border/50 p-8">
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="grid grid-cols-2 gap-4">
                {/* Patient Name */}
                <div className="space-y-2">
                  <Label htmlFor="patientName" className="text-foreground font-medium">
                    Patient Name
                  </Label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="patientName"
                      type="text"
                      placeholder="Full name"
                      value={formData.patientName}
                      onChange={handleChange("patientName")}
                      disabled={isSubmitting || paymentStatus === "verifying"}
                      className={`pl-10 h-12 ${errors.patientName ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.patientName && <p className="text-sm text-destructive">{errors.patientName}</p>}
                </div>

                {/* Phone */}
                <div className="space-y-2">
                  <Label htmlFor="phone" className="text-foreground font-medium">
                    Phone Number
                  </Label>
                  <div className="relative">
                    <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="phone"
                      type="tel"
                      placeholder="+91-XXXXXXXXXX"
                      value={formData.phone}
                      onChange={handleChange("phone")}
                      disabled={isSubmitting || paymentStatus === "verifying"}
                      className={`pl-10 h-12 ${errors.phone ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.phone && <p className="text-sm text-destructive">{errors.phone}</p>}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                {/* Date */}
                <div className="space-y-2">
                  <Label htmlFor="date" className="text-foreground font-medium">
                    Preferred Date
                  </Label>
                  <div className="relative">
                    <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="date"
                      type="date"
                      value={formData.date}
                      onChange={handleChange("date")}
                      disabled={isSubmitting || paymentStatus === "verifying"}
                      className={`pl-10 h-12 ${errors.date ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.date && <p className="text-sm text-destructive">{errors.date}</p>}
                </div>

                {/* Time */}
                <div className="space-y-2">
                  <Label htmlFor="time" className="text-foreground font-medium">
                    Preferred Time
                  </Label>
                  <div className="relative">
                    <Clock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="time"
                      type="time"
                      value={formData.time}
                      onChange={handleChange("time")}
                      disabled={isSubmitting || paymentStatus === "verifying"}
                      className={`pl-10 h-12 ${errors.time ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.time && <p className="text-sm text-destructive">{errors.time}</p>}
                </div>
              </div>

              {/* Specialty */}
              <div className="space-y-2">
                <Label htmlFor="specialty" className="text-foreground font-medium">
                  Specialty
                </Label>
                <select
                  id="specialty"
                  value={formData.specialty}
                  onChange={handleChange("specialty")}
                  disabled={isSubmitting || paymentStatus === "verifying"}
                  className={`w-full h-12 rounded-md border bg-background px-3 text-foreground ${errors.specialty ? "border-destructive" : "border-input"} disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  <option value="">Select specialty</option>
                  {specialties.map((s) => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
                {errors.specialty && <p className="text-sm text-destructive">{errors.specialty}</p>}
              </div>

              {/* Doctor */}
              <div className="space-y-2">
                <Label htmlFor="doctor" className="text-foreground font-medium">
                  Select Doctor
                </Label>
                <select
                  id="doctor"
                  value={formData.doctor}
                  onChange={handleChange("doctor")}
                  disabled={isSubmitting || paymentStatus === "verifying"}
                  className={`w-full h-12 rounded-md border bg-background px-3 text-foreground ${errors.doctor ? "border-destructive" : "border-input"} disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  <option value="">Select doctor</option>
                  {filteredDoctors.map((d) => (
                    <option key={d.id} value={d.id}>{d.name} {d.degree ? `- ${d.degree}` : ''}</option>
                  ))}
                </select>
                {errors.doctor && <p className="text-sm text-destructive">{errors.doctor}</p>}
              </div>

              {/* Hospital */}
              <div className="space-y-2">
                <Label htmlFor="hospital" className="text-foreground font-medium">
                  Select Hospital
                </Label>
                <div className="relative">
                  <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground pointer-events-none" />
                  <select
                    id="hospital"
                    value={formData.hospital}
                    onChange={handleChange("hospital")}
                    disabled={isSubmitting || paymentStatus === "verifying"}
                    className={`w-full h-12 rounded-md border bg-background px-10 text-foreground ${errors.hospital ? "border-destructive" : "border-input"} disabled:opacity-50 disabled:cursor-not-allowed`}
                  >
                    <option value="">Select hospital</option>
                    {hospitals.map((h) => (
                      <option key={h.id} value={h.id}>{h.name}</option>
                    ))}
                  </select>
                </div>
                {errors.hospital && <p className="text-sm text-destructive">{errors.hospital}</p>}
              </div>

              {/* Notes */}
              <div className="space-y-2">
                <Label htmlFor="notes" className="text-foreground font-medium">
                  Additional Notes (Optional)
                </Label>
                <div className="relative">
                  <FileText className="absolute left-3 top-3 w-5 h-5 text-muted-foreground" />
                  <textarea
                    id="notes"
                    value={formData.notes}
                    onChange={handleChange("notes")}
                    placeholder="Any special requirements or notes..."
                    rows={3}
                    disabled={isSubmitting || paymentStatus === "verifying"}
                    className={`w-full rounded-md border bg-background px-10 py-3 text-foreground ${errors.notes ? "border-destructive" : "border-input"} disabled:opacity-50 disabled:cursor-not-allowed`}
                  />
                </div>
              </div>

              {/* Submit Button */}
              <Button
                type="submit"
                variant="hero"
                className="w-full h-12"
                disabled={isSubmitting || paymentStatus === "verifying" || paymentStatus === "success"}
              >
                {isSubmitting || paymentStatus === "verifying" ? (
                  <span className="flex items-center gap-2">
                    <Loader2 className="w-5 h-5 animate-spin" />
                    {paymentStatus === "verifying" ? "Verifying Payment..." : "Processing..."}
                  </span>
                ) : paymentStatus === "success" ? (
                  <span className="flex items-center gap-2">
                    <CheckCircle className="w-5 h-5" />
                    Payment Successful
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    <CreditCard className="w-5 h-5" />
                    Proceed to Payment
                  </span>
                )}
              </Button>
            </form>
          </div>

          {/* Back Link */}
          <p className="text-center mt-6">
            <Link to="/" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
              ← Back to Home
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default BookAppointment;
