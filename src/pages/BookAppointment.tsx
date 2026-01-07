import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Heart, User, Phone, Calendar, Clock, MapPin, Stethoscope, FileText, ArrowRight, CreditCard, Loader2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { z } from "zod";
import { hospitalsAPI, doctorsAPI, appointmentsAPI, operationsAPI, paymentsAPI, apiRequest } from "@/lib/api";
import { getCurrentUser } from "@/lib/auth";
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

type PaymentMethod = "upi" | "card";

const BookAppointment = () => {
  const [bookingType, setBookingType] = useState<BookingType>("appointment");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("upi");
  const [selectedUpi, setSelectedUpi] = useState("default");
  const [upiId, setUpiId] = useState("");
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
  const [isLoading, setIsLoading] = useState(false);
  const [paymentOrder, setPaymentOrder] = useState<any>(null);
  const [bookingData, setBookingData] = useState<{id: number; type: "appointment" | "operation"} | null>(null);
  const [paymentStatus, setPaymentStatus] = useState<"pending" | "processing" | "completed" | "failed">("pending");
  const { toast } = useToast();
  const navigate = useNavigate();

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

  useEffect(() => {
    const fetchData = async () => {
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
        } else if (!hospitalsData || hospitalsData.length === 0) {
          toast({
            title: "Warning",
            description: "No hospitals available. Please contact support.",
            variant: "destructive",
          });
        } else if (!doctorsData || doctorsData.length === 0) {
          toast({
            title: "Warning",
            description: "No doctors available. Please contact support.",
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
      }
    };
    fetchData();
  }, [toast]);

  const handleChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setFormData((prev) => ({ ...prev, [field]: e.target.value }));
    if (errors[field as keyof FormErrors]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrors({});

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

    setIsLoading(true);
    
    try {
      const currentUser = await getCurrentUser();
      if (!currentUser) {
        toast({
          title: "Authentication Required",
          description: "Please login to book an appointment.",
          variant: "destructive",
        });
        navigate("/login");
        return;
      }

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
        setBookingData({ id: bookingResult.id, type: "appointment" });
      } else {
        bookingResult = await operationsAPI.book({
          hospital_id: selectedHospital.id,
          doctor_id: selectedDoctor.id,
          date: formData.date,
          specialty: formData.specialty,
          notes: formData.notes || undefined,
        });
        setBookingData({ id: bookingResult.id, type: "operation" });
      }

      // Step 2: Create Cashfree payment order
      // TODO: Fetch consultation fee from hospital settings when endpoint is available
      // For now, using default amount. In future, fetch from: hospitalsAPI.getById(selectedHospital.id).consultation_fee
      const defaultAmount = 500; // Default consultation fee
      
      const orderData = await apiRequest<any>('/api/payments/create-order', {
        method: 'POST',
        body: JSON.stringify({
          appointment_id: bookingType === "appointment" ? bookingResult.id : null,
          operation_id: bookingType === "operation" ? bookingResult.id : null,
          amount: defaultAmount,
          currency: "INR",
        }),
      });

      if (!orderData || !orderData.payment_session_id) {
        throw new Error("Failed to create payment order");
      }

      setPaymentOrder(orderData);
      setIsLoading(false);

      // Step 3: Open Cashfree payment checkout
      try {
        const cashfree = await load();
        
        const checkoutOptions = {
          paymentSessionId: orderData.payment_session_id,
          redirectTarget: "_self" as const
        };

        cashfree.checkout(checkoutOptions);
        
        // Cashfree will handle the payment flow and redirect
        // Payment status will be updated via webhook
        setPaymentStatus("processing");
      } catch (error: any) {
        setPaymentStatus("failed");
        setIsLoading(false);
        toast({
          title: "Payment Error",
          description: error.message || "Failed to initialize payment. Please try again.",
          variant: "destructive",
        });
      }
    } catch (error: any) {
      console.error("Booking error:", error);
      toast({
        title: "Booking Failed",
        description: error.message || "Failed to book appointment. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const filteredDoctors = formData.specialty && doctors.length > 0
    ? doctors.filter(d => {
        // Since doctors from API might not have specialty, we can't filter by it
        // Just return all doctors for now
        return true;
      })
    : doctors;

  if (loadingData) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
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

          {/* Booking Type Toggle */}
          <div className="flex gap-4 mb-8">
            <button
              type="button"
              onClick={() => setBookingType("appointment")}
              className={`flex-1 flex items-center justify-center gap-3 p-4 rounded-xl border-2 transition-all ${
                bookingType === "appointment"
                  ? "border-primary bg-primary/5 text-primary"
                  : "border-border bg-card hover:border-primary/50 text-muted-foreground"
              }`}
            >
              <Calendar className="w-6 h-6" />
              <span className="font-medium">Book Appointment</span>
            </button>
            <button
              type="button"
              onClick={() => setBookingType("operation")}
              className={`flex-1 flex items-center justify-center gap-3 p-4 rounded-xl border-2 transition-all ${
                bookingType === "operation"
                  ? "border-primary bg-primary/5 text-primary"
                  : "border-border bg-card hover:border-primary/50 text-muted-foreground"
              }`}
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
                  className={`w-full h-12 rounded-md border bg-background px-3 text-foreground ${errors.specialty ? "border-destructive" : "border-input"}`}
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
                  className={`w-full h-12 rounded-md border bg-background px-3 text-foreground ${errors.doctor ? "border-destructive" : "border-input"}`}
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
                    className={`w-full h-12 rounded-md border bg-background px-10 text-foreground ${errors.hospital ? "border-destructive" : "border-input"}`}
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
                    className={`w-full rounded-md border bg-background px-10 py-3 text-foreground ${errors.notes ? "border-destructive" : "border-input"}`}
                  />
                </div>
              </div>

              {/* Payment Status Indicator */}
              {paymentStatus === "processing" && (
                <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 flex items-center gap-3">
                  <Loader2 className="w-5 h-5 text-blue-600 dark:text-blue-400 animate-spin" />
                  <div>
                    <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
                      Verifying Payment...
                    </p>
                    <p className="text-xs text-blue-700 dark:text-blue-300">
                      Please wait while we confirm your payment.
                    </p>
                  </div>
                </div>
              )}

              {paymentStatus === "completed" && (
                <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 flex items-center gap-3">
                  <div className="w-5 h-5 rounded-full bg-green-600 flex items-center justify-center">
                    <span className="text-white text-xs">✓</span>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-green-900 dark:text-green-100">
                      Payment Successful!
                    </p>
                    <p className="text-xs text-green-700 dark:text-green-300">
                      Your booking is being confirmed...
                    </p>
                  </div>
                </div>
              )}

              {paymentStatus === "failed" && (
                <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
                  <p className="text-sm font-medium text-red-900 dark:text-red-100">
                    Payment Failed
                  </p>
                  <p className="text-xs text-red-700 dark:text-red-300 mt-1">
                    Please try again or contact support.
                  </p>
                </div>
              )}

              {/* Submit Button */}
              <Button
                type="submit"
                variant="hero"
                className="w-full h-12"
                disabled={isLoading || paymentStatus === "processing" || paymentStatus === "completed"}
              >
                {isLoading || paymentStatus === "processing" ? (
                  <span className="flex items-center gap-2">
                    <span className="w-5 h-5 border-2 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin" />
                    {paymentStatus === "processing" ? "Processing Payment..." : "Booking..."}
                  </span>
                ) : paymentStatus === "completed" ? (
                  <span className="flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-primary-foreground/20 flex items-center justify-center">
                      <span className="text-primary-foreground text-xs">✓</span>
                    </span>
                    Redirecting...
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
