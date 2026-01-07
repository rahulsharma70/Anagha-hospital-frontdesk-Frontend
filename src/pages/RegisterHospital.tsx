import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Heart, Mail, Phone, MapPin, Building2, Users, ArrowRight, Globe, FileText, Smartphone, Check, Star, ArrowLeft, Loader2 } from "lucide-react";
import { hospitalsAPI, adminAPI, paymentsAPI } from "@/lib/api";
import { useToast } from "@/hooks/use-toast";
import { z } from "zod";

const upiOptions = [
  { id: "default", name: "Default UPI" },
  { id: "gpay", name: "Google Pay" },
  { id: "paytm", name: "PayTM" },
  { id: "phonepe", name: "PhonePe" },
];

const hospitalSchema = z.object({
  hospitalName: z.string().trim().min(2, { message: "Hospital name is required" }).max(100),
  registrationNumber: z.string().trim().min(3, { message: "Registration number is required" }),
  email: z.string().trim().email({ message: "Please enter a valid email address" }),
  phone: z.string().trim().min(10, { message: "Please enter a valid phone number" }).max(15),
  address: z.string().trim().min(5, { message: "Address is required" }).max(200),
  city: z.string().trim().min(2, { message: "City is required" }),
  state: z.string().trim().min(2, { message: "State is required" }),
  pincode: z.string().trim().min(6, { message: "Valid pincode is required" }).max(6),
  totalDoctors: z.string().trim().min(1, { message: "Number of doctors is required" }),
  website: z.string().optional(),
  upiType: z.string().min(1, { message: "Please select a UPI type" }),
  upiId: z.string().trim().min(5, { message: "Please enter a valid UPI ID" }),
});

type FormErrors = Partial<Record<keyof z.infer<typeof hospitalSchema>, string>>;

interface PricingPlan {
  name: string;
  description: string;
  installationPrice: number;
  monthlyPrice: number;
  features: string[];
  popular: boolean;
}

const RegisterHospital = () => {
  const [currentStep, setCurrentStep] = useState<1 | 2 | 3>(1);
  const [formData, setFormData] = useState({
    hospitalName: "",
    registrationNumber: "",
    email: "",
    phone: "",
    address: "",
    city: "",
    state: "",
    pincode: "",
    totalDoctors: "",
    website: "",
    upiType: "",
    upiId: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});
  const [isLoading, setIsLoading] = useState(false);
  const [pricingPlans, setPricingPlans] = useState<PricingPlan[]>([]);
  const [selectedPlan, setSelectedPlan] = useState<PricingPlan | null>(null);
  const [paymentId, setPaymentId] = useState<number | null>(null);
  const { toast } = useToast();
  const navigate = useNavigate();

  // Check for plan from URL params (coming from home page) or payment_id (returned from payments page)
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    
    // Check for payment_id first (returned from payments page)
    const paymentIdParam = urlParams.get('payment_id');
    if (paymentIdParam) {
      const id = parseInt(paymentIdParam, 10);
      if (!isNaN(id)) {
        setPaymentId(id);
        
        // Restore form data from localStorage
        const stored = localStorage.getItem('hospitalRegistrationData');
        if (stored) {
          try {
            const data = JSON.parse(stored);
            setFormData(data.formData);
            setSelectedPlan(data.selectedPlan);
          } catch (error) {
            console.error("Error restoring form data:", error);
          }
        }
        
        setCurrentStep(3); // Move to final step
        // Clear URL params
        window.history.replaceState({}, '', window.location.pathname);
        return;
      }
    }
    
    // Check for plan from URL (coming from home page)
    const planName = urlParams.get('plan');
    const planAmount = urlParams.get('amount');
    
    if (planName && planAmount) {
      // Find matching plan from pricing plans
      const matchingPlan = pricingPlans.find(p => p.name === planName);
      if (matchingPlan) {
        setSelectedPlan(matchingPlan);
      } else {
        // If plan not found in pricing plans, create a temporary plan object
        const tempPlan: PricingPlan = {
          name: planName,
          description: `${planName} Package`,
          installationPrice: parseFloat(planAmount),
          monthlyPrice: 0,
          features: [],
          popular: false,
        };
        setSelectedPlan(tempPlan);
      }
      // Clear URL params
      window.history.replaceState({}, '', window.location.pathname);
    }
  }, [pricingPlans]);

  // Load pricing plans on mount
  useEffect(() => {
    const loadPricing = async () => {
      try {
        const pricing = await adminAPI.getPublicPricing();
        if (pricing?.plans && Array.isArray(pricing.plans) && pricing.plans.length > 0) {
          // Transform backend pricing to frontend format
          // Handle both formats: new format (price/period) and old format (installationPrice/monthlyPrice)
          const transformedPlans = pricing.plans.map((plan: any) => {
            // Check if it's the new format (has 'price' field)
            if (plan.price !== undefined) {
              // New format: price is monthly, need to calculate installation and monthly
              const monthlyPrice = typeof plan.price === 'string' ? parseFloat(plan.price) : plan.price;
              // For installation, use a multiplier (e.g., 5x monthly) or set a default
              const installationPrice = monthlyPrice * 5; // 5 months worth as installation
              
              return {
                name: plan.name || "Plan",
                description: plan.description || `${plan.name} Package`,
                installationPrice: installationPrice,
                monthlyPrice: monthlyPrice,
                features: Array.isArray(plan.features) ? plan.features : [],
                popular: plan.popular || false,
              };
            } else {
              // Old format: has installationPrice and monthlyPrice
              return {
                name: plan.name || "Plan",
                description: plan.description || `${plan.name} Package`,
                installationPrice: plan.installationPrice || plan.installation || plan.installation_price || 0,
                monthlyPrice: plan.monthlyPrice || plan.monthly || plan.monthly_price || 0,
                features: Array.isArray(plan.features) ? plan.features : [],
                popular: plan.popular || false,
              };
            }
          });
          
          // Only update if we got valid plans with prices > 0
          if (transformedPlans.length > 0 && transformedPlans.every((p: any) => p.installationPrice > 0 && p.monthlyPrice > 0)) {
            setPricingPlans(transformedPlans);
          } else {
            console.warn("Invalid pricing data received, using defaults");
            // Use default plans below
          }
        } else {
          // Fallback to default plans
          setPricingPlans([
            {
              name: "Starter",
              description: "For 1 Doctor / 1 Hospital",
              installationPrice: 5000,
              monthlyPrice: 1000,
              features: [
                "1 Doctor profile",
                "1 Hospital",
                "Appointment management",
                "Email reminders",
                "Basic analytics",
                "Email support",
              ],
              popular: false,
            },
            {
              name: "Professional",
              description: "For 5 Doctors in 1 Hospital",
              installationPrice: 10000,
              monthlyPrice: 2000,
              features: [
                "Up to 5 Doctor profiles",
                "1 Hospital",
                "SMS & Email reminders",
                "Advanced analytics",
                "Custom booking page",
                "Payment integration",
                "Priority support",
              ],
              popular: true,
            },
            {
              name: "Enterprise",
              description: "For 10 Doctors & 5 Hospitals",
              installationPrice: 20000,
              monthlyPrice: 5000,
              features: [
                "Up to 10 Doctor profiles",
                "Up to 5 Hospitals (same ownership)",
                "Multi-location support",
                "Custom integrations",
                "Dedicated account manager",
                "24/7 phone support",
                "White-label option",
              ],
              popular: false,
            },
          ]);
        }
      } catch (error) {
        console.error("Error loading pricing:", error);
        // Use default plans on error
        setPricingPlans([
          {
            name: "Starter",
            description: "For 1 Doctor / 1 Hospital",
            installationPrice: 5000,
            monthlyPrice: 1000,
            features: [
              "1 Doctor profile",
              "1 Hospital",
              "Appointment management",
              "Email reminders",
              "Basic analytics",
              "Email support",
            ],
            popular: false,
          },
          {
            name: "Professional",
            description: "For 5 Doctors in 1 Hospital",
            installationPrice: 10000,
            monthlyPrice: 2000,
            features: [
              "Up to 5 Doctor profiles",
              "1 Hospital",
              "SMS & Email reminders",
              "Advanced analytics",
              "Custom booking page",
              "Payment integration",
              "Priority support",
            ],
            popular: true,
          },
          {
            name: "Enterprise",
            description: "For 10 Doctors & 5 Hospitals",
            installationPrice: 20000,
            monthlyPrice: 5000,
            features: [
              "Up to 10 Doctor profiles",
              "Up to 5 Hospitals (same ownership)",
              "Multi-location support",
              "Custom integrations",
              "Dedicated account manager",
              "24/7 phone support",
              "White-label option",
            ],
            popular: false,
          },
        ]);
      }
    };
    loadPricing();
  }, []);


  const handleChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setFormData((prev) => ({ ...prev, [field]: e.target.value }));
    if (errors[field as keyof FormErrors]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  const handleStep1Submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrors({});

    const result = hospitalSchema.safeParse(formData);
    
    if (!result.success) {
      const fieldErrors: FormErrors = {};
      result.error.errors.forEach((err) => {
        const field = err.path[0] as keyof FormErrors;
        fieldErrors[field] = err.message;
      });
      setErrors(fieldErrors);
      return;
    }

    // If plan is already selected (from URL), go directly to payments
    if (selectedPlan) {
      // Store form data and plan in localStorage for Payments page
      localStorage.setItem('hospitalRegistrationData', JSON.stringify({
        formData,
        selectedPlan,
        timestamp: Date.now()
      }));

      // Navigate to payments page
      const paymentUrl = `/payments?type=hospital_registration&plan=${encodeURIComponent(selectedPlan.name)}&amount=${selectedPlan.installationPrice}`;
      window.location.href = paymentUrl;
    } else {
      // Move to package selection if no plan selected
      setCurrentStep(2);
    }
  };

  const handlePlanSelect = (plan: PricingPlan) => {
    setSelectedPlan(plan);
  };

  const handleStep2Next = () => {
    if (!selectedPlan) {
      toast({
        title: "Please Select a Plan",
        description: "You must select a package to continue.",
        variant: "destructive",
      });
      return;
    }

    // Store form data and plan in localStorage for Payments page
    localStorage.setItem('hospitalRegistrationData', JSON.stringify({
      formData,
      selectedPlan,
      timestamp: Date.now()
    }));

    // Navigate to payments page - use window.location for reliable navigation
    const paymentUrl = `/payments?type=hospital_registration&plan=${encodeURIComponent(selectedPlan.name)}&amount=${selectedPlan.installationPrice}`;
    window.location.href = paymentUrl;
  };


  const handleFinalSubmit = async () => {
    if (!paymentId) {
      toast({
        title: "Payment Required",
        description: "Please complete payment before submitting registration.",
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);
    
    try {
      // Verify payment is completed
      const paymentStatus = await paymentsAPI.getPaymentStatus(paymentId);
      if (paymentStatus.status !== "COMPLETED") {
        throw new Error(`Payment not completed. Current status: ${paymentStatus.status}`);
      }

      // Map frontend form fields to backend API format
      const hospitalData: any = {
        name: formData.hospitalName,
        email: formData.email,
        mobile: formData.phone,
        address_line1: formData.address,
        city: formData.city,
        state: formData.state,
        pincode: formData.pincode,
        payment_id: paymentId,
        plan_name: selectedPlan?.name,
      };

      // Map UPI ID based on selected type
      if (formData.upiType === "default") {
        hospitalData.upi_id = formData.upiId;
      } else if (formData.upiType === "gpay") {
        hospitalData.gpay_upi_id = formData.upiId;
        hospitalData.upi_id = formData.upiId;
      } else if (formData.upiType === "paytm") {
        hospitalData.paytm_upi_id = formData.upiId;
        hospitalData.upi_id = formData.upiId;
      } else if (formData.upiType === "phonepe") {
        hospitalData.phonepay_upi_id = formData.upiId;
        hospitalData.upi_id = formData.upiId;
      }

      // Submit registration
      const result = await hospitalsAPI.register(hospitalData);
      
      // Clear stored data
      localStorage.removeItem('hospitalRegistrationData');
      
      setIsLoading(false);
      toast({
        title: "Hospital Registration Successful",
        description: "Your hospital registration is under review. We will contact you within 24-48 hours.",
      });
      
      // Navigate to home after successful registration
      setTimeout(() => {
        navigate("/");
      }, 2000);
    } catch (error: any) {
      setIsLoading(false);
      toast({
        title: "Registration Failed",
        description: error.message || "Failed to register hospital. Please try again.",
        variant: "destructive",
      });
    }
  };

  // Helper function for API requests (since we're not importing it)
  const apiRequest = async <T,>(endpoint: string, options: RequestInit = {}): Promise<T> => {
    const API_BASE_URL = import.meta.env.VITE_API_URL || window.location.origin;
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ detail: `HTTP error! status: ${response.status}` }));
      throw new Error(errorData.detail || errorData.message || `HTTP error! status: ${response.status}`);
    }

    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      return response.json();
    }
    return response.text() as any;
  };

  return (
    <div className="min-h-screen bg-background flex">
      {/* Left Side - Visual */}
      <div className="hidden lg:flex flex-1 bg-gradient-hero items-center justify-center p-12 relative overflow-hidden">
        <div className="absolute inset-0 bg-primary/10" />
        <div className="absolute top-20 left-20 w-64 h-64 bg-primary-foreground/10 rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-20 w-48 h-48 bg-accent/20 rounded-full blur-3xl" />
        
        <div className="relative z-10 text-center text-primary-foreground max-w-md">
          <div className="text-6xl mb-6">🏨</div>
          <h3 className="text-3xl font-bold mb-4">
            Register Your Hospital
          </h3>
          <p className="text-primary-foreground/80 text-lg">
            Join our network of healthcare providers and connect with thousands of patients
          </p>
          
          {/* Step Indicator */}
          <div className="mt-8 flex items-center justify-center gap-2">
            {[1, 2, 3].map((step) => (
              <div
                key={step}
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all ${
                  currentStep >= step
                    ? "bg-primary-foreground text-primary"
                    : "bg-primary-foreground/20 text-primary-foreground/50"
                }`}
              >
                {step}
            </div>
            ))}
          </div>
        </div>
      </div>

      {/* Right Side - Form */}
      <div className="flex-1 flex flex-col justify-center px-6 py-12 lg:px-8 overflow-y-auto">
        <div className="sm:mx-auto sm:w-full sm:max-w-lg">
          {/* Logo */}
          <Link to="/" className="flex items-center justify-center gap-2 mb-8">
            <div className="w-12 h-12 rounded-xl bg-gradient-hero flex items-center justify-center shadow-soft">
              <Heart className="w-6 h-6 text-primary-foreground" />
            </div>
            <span className="font-bold text-2xl text-foreground">Anagha Health</span>
          </Link>

          <h2 className="text-center text-3xl font-bold text-foreground mb-2">
            Hospital Registration
          </h2>
          <p className="text-center text-muted-foreground mb-6">
            {currentStep === 1 && "Step 1: Hospital Details"}
            {currentStep === 2 && "Step 2: Select Package"}
            {currentStep === 3 && "Step 3: Complete Registration"}
          </p>
        </div>

        <div className="sm:mx-auto sm:w-full sm:max-w-lg">
          <div className="bg-card rounded-2xl shadow-elevated border border-border/50 p-8">
            {/* Step 1: Hospital Details */}
            {currentStep === 1 && (
              <form onSubmit={handleStep1Submit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="hospitalName" className="text-foreground font-medium">
                  Hospital Name
                </Label>
                <div className="relative">
                  <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="hospitalName"
                    type="text"
                    placeholder="City General Hospital"
                    value={formData.hospitalName}
                    onChange={handleChange("hospitalName")}
                    className={`pl-10 h-12 ${errors.hospitalName ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.hospitalName && <p className="text-sm text-destructive">{errors.hospitalName}</p>}
              </div>

              <div className="space-y-2">
                <Label htmlFor="registrationNumber" className="text-foreground font-medium">
                  Registration Number
                </Label>
                <div className="relative">
                  <FileText className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="registrationNumber"
                    type="text"
                    placeholder="REG-XXXX-XXXX"
                    value={formData.registrationNumber}
                    onChange={handleChange("registrationNumber")}
                    className={`pl-10 h-12 ${errors.registrationNumber ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.registrationNumber && <p className="text-sm text-destructive">{errors.registrationNumber}</p>}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                    <Label htmlFor="email" className="text-foreground font-medium">Email</Label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="email"
                      type="email"
                      placeholder="hospital@email.com"
                      value={formData.email}
                      onChange={handleChange("email")}
                      className={`pl-10 h-12 ${errors.email ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.email && <p className="text-sm text-destructive">{errors.email}</p>}
                </div>

                <div className="space-y-2">
                    <Label htmlFor="phone" className="text-foreground font-medium">Phone</Label>
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

              <div className="space-y-2">
                  <Label htmlFor="address" className="text-foreground font-medium">Full Address</Label>
                <div className="relative">
                  <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="address"
                    type="text"
                    placeholder="Street address"
                    value={formData.address}
                    onChange={handleChange("address")}
                    className={`pl-10 h-12 ${errors.address ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.address && <p className="text-sm text-destructive">{errors.address}</p>}
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2">
                    <Label htmlFor="city" className="text-foreground font-medium">City</Label>
                  <Input
                    id="city"
                    type="text"
                    placeholder="Gwalior"
                    value={formData.city}
                    onChange={handleChange("city")}
                    className={`h-12 ${errors.city ? "border-destructive" : ""}`}
                  />
                  {errors.city && <p className="text-sm text-destructive">{errors.city}</p>}
                </div>

                <div className="space-y-2">
                    <Label htmlFor="state" className="text-foreground font-medium">State</Label>
                  <Input
                    id="state"
                    type="text"
                    placeholder="MP"
                    value={formData.state}
                    onChange={handleChange("state")}
                    className={`h-12 ${errors.state ? "border-destructive" : ""}`}
                  />
                  {errors.state && <p className="text-sm text-destructive">{errors.state}</p>}
                </div>

                <div className="space-y-2">
                    <Label htmlFor="pincode" className="text-foreground font-medium">Pincode</Label>
                  <Input
                    id="pincode"
                    type="text"
                    placeholder="474001"
                    value={formData.pincode}
                    onChange={handleChange("pincode")}
                    className={`h-12 ${errors.pincode ? "border-destructive" : ""}`}
                  />
                  {errors.pincode && <p className="text-sm text-destructive">{errors.pincode}</p>}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                    <Label htmlFor="totalDoctors" className="text-foreground font-medium">Total Doctors</Label>
                  <div className="relative">
                    <Users className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="totalDoctors"
                      type="number"
                      placeholder="10"
                      value={formData.totalDoctors}
                      onChange={handleChange("totalDoctors")}
                      className={`pl-10 h-12 ${errors.totalDoctors ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.totalDoctors && <p className="text-sm text-destructive">{errors.totalDoctors}</p>}
                </div>

                <div className="space-y-2">
                    <Label htmlFor="website" className="text-foreground font-medium">Website (Optional)</Label>
                  <div className="relative">
                    <Globe className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="website"
                      type="url"
                      placeholder="https://..."
                      value={formData.website}
                      onChange={handleChange("website")}
                      className="pl-10 h-12"
                    />
                  </div>
                </div>
              </div>

              <div className="border-t border-border pt-6 mt-2">
                <h3 className="font-semibold text-foreground mb-4 flex items-center gap-2">
                  <Smartphone className="w-5 h-5 text-primary" />
                  Payment Details (UPI)
                </h3>
                
                <div className="space-y-2 mb-4">
                    <Label htmlFor="upiType" className="text-foreground font-medium">Select UPI App</Label>
                  <select
                    id="upiType"
                    value={formData.upiType}
                    onChange={handleChange("upiType")}
                    className={`w-full h-12 rounded-md border bg-background px-3 text-foreground ${errors.upiType ? "border-destructive" : "border-input"}`}
                  >
                    <option value="">Select UPI type</option>
                    {upiOptions.map((option) => (
                      <option key={option.id} value={option.id}>{option.name}</option>
                    ))}
                  </select>
                  {errors.upiType && <p className="text-sm text-destructive">{errors.upiType}</p>}
                </div>

                <div className="space-y-2">
                    <Label htmlFor="upiId" className="text-foreground font-medium">UPI ID</Label>
                  <div className="relative">
                    <Smartphone className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="upiId"
                      type="text"
                      placeholder="hospital@upi"
                      value={formData.upiId}
                      onChange={handleChange("upiId")}
                      className={`pl-10 h-12 ${errors.upiId ? "border-destructive" : ""}`}
                    />
                  </div>
                  {errors.upiId && <p className="text-sm text-destructive">{errors.upiId}</p>}
                </div>
              </div>

                <Button type="submit" variant="hero" className="w-full h-12 mt-6">
                  Continue to Package Selection
                  <ArrowRight className="w-5 h-5 ml-2" />
                </Button>
              </form>
            )}

            {/* Step 2: Package Selection */}
            {currentStep === 2 && (
              <div className="space-y-6">
                <div className="grid md:grid-cols-3 gap-4">
                  {pricingPlans.map((plan) => (
                    <div
                      key={plan.name}
                      onClick={() => handlePlanSelect(plan)}
                      className={`relative bg-card rounded-xl p-6 border-2 transition-all cursor-pointer hover:shadow-lg ${
                        selectedPlan?.name === plan.name
                          ? "border-primary shadow-glow"
                          : "border-border hover:border-primary/50"
                      }`}
                    >
                      {plan.popular && (
                        <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                          <div className="flex items-center gap-1 px-3 py-1 bg-gradient-hero rounded-full text-primary-foreground text-xs font-semibold">
                            <Star className="w-3 h-3" />
                            Most Popular
                          </div>
                        </div>
                      )}

                      <div className="text-center mb-4">
                        <h3 className="text-lg font-bold text-foreground mb-1">{plan.name}</h3>
                        <p className="text-muted-foreground text-sm">{plan.description}</p>
                      </div>

                      <div className="text-center mb-4">
                        <div className="flex items-baseline justify-center gap-1">
                          <span className="text-2xl font-bold text-foreground">
                            ₹{plan.installationPrice.toLocaleString('en-IN')}
                          </span>
                        </div>
                        <p className="text-muted-foreground text-xs mt-1">
                          + ₹{plan.monthlyPrice.toLocaleString('en-IN')}/month
                        </p>
                      </div>

                      <ul className="space-y-2 mb-4">
                        {plan.features.map((feature) => (
                          <li key={feature} className="flex items-start gap-2">
                            <Check className="w-4 h-4 text-primary flex-shrink-0 mt-0.5" />
                            <span className="text-muted-foreground text-sm">{feature}</span>
                          </li>
                        ))}
                      </ul>

                      {selectedPlan?.name === plan.name && (
                        <div className="text-center text-primary font-semibold text-sm">
                          ✓ Selected
                        </div>
                      )}
                    </div>
                  ))}
                </div>

                <div className="flex gap-4">
                  <Button
                    variant="outline"
                    className="flex-1"
                    onClick={() => setCurrentStep(1)}
                  >
                    <ArrowLeft className="w-4 h-4 mr-2" />
                    Back
                  </Button>
                  <Button
                    type="button"
                    variant="hero"
                    className="flex-1"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      handleStep2Next();
                    }}
                    disabled={!selectedPlan || isLoading}
                  >
                    {isLoading ? (
                      <>
                        <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                        Processing...
                      </>
                    ) : (
                      <>
                        Proceed to Payment
                        <ArrowRight className="w-4 h-4 ml-2" />
                      </>
                    )}
                  </Button>
                </div>
              </div>
            )}

            {/* Step 3: Complete Registration */}
            {currentStep === 3 && (
              <div className="space-y-6">
                {paymentId ? (
                  <>
                    <div className="text-center">
                      <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
                        <Check className="w-8 h-8 text-green-600" />
                      </div>
                      <h3 className="text-xl font-bold text-foreground mb-2">Payment Successful!</h3>
                      <p className="text-muted-foreground">
                        Your payment has been verified. Click below to complete your hospital registration.
                      </p>
                    </div>

              <Button
                variant="hero"
                      className="w-full h-12"
                      onClick={handleFinalSubmit}
                disabled={isLoading}
              >
                {isLoading ? (
                        <>
                          <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                          Submitting Registration...
                        </>
                      ) : (
                        <>
                          Complete Registration
                          <ArrowRight className="w-5 h-5 ml-2" />
                        </>
                      )}
                    </Button>
                  </>
                ) : (
                  <div className="text-center space-y-4">
                    <div className="bg-amber-50 border border-amber-200 rounded-xl p-6">
                      <p className="text-amber-800 font-semibold mb-2">Payment Not Found</p>
                      <p className="text-amber-700 text-sm mb-4">
                        Please complete payment first before proceeding with registration.
                      </p>
                      <Button
                        variant="outline"
                        onClick={() => {
                          // Restore form data and navigate to payments
                          const stored = localStorage.getItem('hospitalRegistrationData');
                          if (stored) {
                            const data = JSON.parse(stored);
                            setFormData(data.formData);
                            setSelectedPlan(data.selectedPlan);
                            navigate(`/payments?type=hospital_registration&plan=${encodeURIComponent(data.selectedPlan.name)}&amount=${data.selectedPlan.installationPrice}`);
                          } else {
                            setCurrentStep(2);
                          }
                        }}
                      >
                        Go to Payment
                        <ArrowRight className="w-4 h-4 ml-2" />
                      </Button>
                    </div>
                    <Button
                      variant="outline"
                      className="w-full"
                      onClick={() => setCurrentStep(2)}
                    >
                      <ArrowLeft className="w-4 h-4 mr-2" />
                      Back to Package Selection
                    </Button>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Back to Home */}
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

export default RegisterHospital;
