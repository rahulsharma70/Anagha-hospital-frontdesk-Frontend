import { useState, useEffect } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Heart, Check, CreditCard, Smartphone, ArrowRight, Loader2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { paymentsAPI, apiRequest } from "@/lib/api";
import { load } from "@cashfreepayments/cashfree-js";

// Cashfree SDK instance (singleton pattern)
let cashfreeInstance: any = null;

// Get Cashfree SDK instance with proper mode configuration
// IMPORTANT: Mode must match backend CASHFREE_API_URL:
// - "sandbox" for https://sandbox.cashfree.com/pg
// - "production" for https://api.cashfree.com/pg
const getCashfree = async () => {
  if (!cashfreeInstance) {
    // Default to production to match backend default (https://api.cashfree.com/pg)
    const mode = import.meta.env.VITE_CASHFREE_MODE || "production"; // "sandbox" | "production"
    console.log("🔵 DEBUG: Loading Cashfree SDK with mode:", mode);
    console.log("🔵 DEBUG: Backend should use:", mode === "sandbox" ? "https://sandbox.cashfree.com/pg" : "https://api.cashfree.com/pg");
    cashfreeInstance = await load({
      mode: mode as "sandbox" | "production",
    });
    console.log("✅ DEBUG: Cashfree SDK loaded successfully", cashfreeInstance);
  }
  return cashfreeInstance;
};

type PaymentMethod = "upi" | "card";

const packages = [
  {
    id: "small-clinic",
    name: "Small Clinic",
    installation: 5001,
    monthly: 1111,
    features: ["Basic Appointment System", "Up to 5 Doctors", "Email Support", "Basic Analytics"],
    popular: false,
  },
  {
    id: "medium",
    name: "Medium (≤5 Drs)",
    installation: 11000,
    monthly: 2111,
    features: ["Advanced Booking System", "Up to 25 Doctors", "Priority Support", "Advanced Analytics", "Payment Integration"],
    popular: true,
  },
  {
    id: "corporate",
    name: "Corporate",
    installation: 21000,
    monthly: 5111,
    features: ["Unlimited Doctors", "24/7 Dedicated Support", "Custom Integrations", "White-label Solution", "Multi-branch Support"],
    popular: false,
  },
];

const upiOptions = [
  { id: "default", name: "Default UPI", icon: "📱" },
  { id: "gpay", name: "Google Pay", icon: "🔵" },
  { id: "paytm", name: "PayTM", icon: "🔷" },
  { id: "phonepe", name: "PhonePe", icon: "💜" },
];

const Payments = () => {
  const [searchParams] = useSearchParams();
  const paymentType = searchParams.get("type"); // "hospital_registration" or null
  const planName = searchParams.get("plan");
  const amountParam = searchParams.get("amount");
  const appointmentId = searchParams.get("appointment");
  const paymentId = searchParams.get("payment");
  const paymentSessionId = searchParams.get("session");
  
  const [selectedPackage, setSelectedPackage] = useState<string | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("upi");
  const [selectedUpi, setSelectedUpi] = useState("default");
  const [upiId, setUpiId] = useState("");
  const [cardDetails, setCardDetails] = useState({
    number: "",
    expiry: "",
    cvv: "",
    name: "",
  });
  const [isProcessing, setIsProcessing] = useState(false);
  const [paymentOrder, setPaymentOrder] = useState<any>(null);
  const [hospitalData, setHospitalData] = useState<any>(null);
  const [appointmentPaymentData, setAppointmentPaymentData] = useState<{
    appointmentId: string;
    paymentId: string;
    paymentSessionId: string;
  } | null>(null);
  const { toast } = useToast();
  const navigate = useNavigate();

  // Helper function to open Cashfree checkout
  const openCashfreeCheckout = async (paymentSessionId: string) => {
    try {
      console.log("🚀 Opening Cashfree checkout", paymentSessionId);
      console.log("🔵 DEBUG: Payment session ID:", paymentSessionId);
      setIsProcessing(true);

      const cashfree = await getCashfree();
      console.log("✅ DEBUG: Cashfree instance:", cashfree);
      console.log("✅ DEBUG: Available methods:", Object.keys(cashfree || {}));
      
      // Check which methods are available
      const hasPay = typeof cashfree?.pay === 'function';
      const hasCheckout = typeof cashfree?.checkout === 'function';
      console.log("✅ DEBUG: pay method exists:", hasPay);
      console.log("✅ DEBUG: checkout method exists:", hasCheckout);

      const checkoutOptions = {
        paymentSessionId,
        redirectTarget: "_self" as const,
      };
      console.log("🔵 DEBUG: Checkout options:", checkoutOptions);

      // Use checkout() method (standard Cashfree JS SDK method)
      if (hasCheckout) {
        console.log("🔵 DEBUG: Using cashfree.checkout() method");
        cashfree.checkout(checkoutOptions);
        console.log("✅ cashfree.checkout() called successfully");
        // checkout() is synchronous and will redirect, so don't reset isProcessing
      } else if (hasPay) {
        console.log("🔵 DEBUG: Using cashfree.pay() method (checkout not available)");
        // pay() might return a promise or need different handling
        const result = await cashfree.pay(checkoutOptions);
        console.log("✅ cashfree.pay() result:", result);
      } else {
        throw new Error("Neither pay() nor checkout() method available on Cashfree SDK");
      }
    } catch (err: any) {
      console.error("❌ Cashfree payment failed:", err);
      console.error("❌ Error details:", err?.message, err?.stack);
      setIsProcessing(false);
      toast({
        title: "Payment Error",
        description: err?.message || "Unable to open payment gateway. Please try again.",
        variant: "destructive",
      });
    }
  };

  // Handle appointment payment - check URL params or localStorage (DO NOT AUTO-OPEN)
  useEffect(() => {
    if (appointmentId && paymentId && paymentSessionId) {
      setAppointmentPaymentData({
        appointmentId,
        paymentId,
        paymentSessionId,
      });
      // Don't auto-open - show "Resume Payment" button instead
      console.log("🔵 DEBUG: Payment session found in URL - showing resume button");
    } else {
      // Check localStorage for pending payment
      const stored = localStorage.getItem('pending_payment_info');
      if (stored) {
        try {
          const paymentInfo = JSON.parse(stored);
          if (paymentInfo.booking_type === 'appointment' && paymentInfo.payment_session_id) {
            setAppointmentPaymentData({
              appointmentId: String(paymentInfo.booking_id),
              paymentId: String(paymentInfo.payment_id),
              paymentSessionId: paymentInfo.payment_session_id,
            });
            console.log("🔵 DEBUG: Payment session found in localStorage - showing resume button");
          }
        } catch (error) {
          console.error("Error loading payment info:", error);
        }
      }
    }
  }, [appointmentId, paymentId, paymentSessionId]);

  // Load hospital registration data if coming from registration
  useEffect(() => {
    if (paymentType === "hospital_registration") {
      const stored = localStorage.getItem('hospitalRegistrationData');
      if (stored) {
        try {
          const data = JSON.parse(stored);
          setHospitalData(data);
          // Auto-select package if plan name matches
          if (planName) {
            const matchingPkg = packages.find(p => p.name.toLowerCase() === planName.toLowerCase());
            if (matchingPkg) {
              setSelectedPackage(matchingPkg.id);
            }
          }
        } catch (error) {
          console.error("Error loading hospital registration data:", error);
        }
      }
    }
  }, [paymentType, planName]);

  const selectedPkg = packages.find((p) => p.id === selectedPackage);

  const handlePayment = async () => {
    if (paymentType === "hospital_registration") {
      // Hospital registration payment flow
      if (!hospitalData || !hospitalData.selectedPlan) {
        toast({
          title: "Error",
          description: "Hospital registration data not found. Please start registration again.",
          variant: "destructive",
        });
        navigate("/register-hospital");
        return;
      }

      setIsProcessing(true);
      try {
        // Create payment order for hospital registration
        console.log("🔵 FRONTEND DEBUG: Creating payment order with hospital data", hospitalData);
        const orderData = await paymentsAPI.createHospitalRegistrationOrder(
          hospitalData.selectedPlan.name,
          hospitalData.selectedPlan.installationPrice,
          hospitalData.formData?.hospitalName || hospitalData.formData?.name,
          hospitalData.formData?.phone || hospitalData.formData?.mobile,
          hospitalData.formData?.email
        );
        console.log("🔵 FRONTEND DEBUG: Payment order created", orderData);

        if (!orderData || !orderData.payment_session_id) {
          throw new Error("Invalid payment order response. Missing payment_session_id.");
        }

        setPaymentOrder(orderData);

        // Open Cashfree checkout using cashfree.pay()
        await openCashfreeCheckout(orderData.payment_session_id);
      } catch (error: any) {
        console.error("❌ DEBUG: Error creating payment order:", error);
        setIsProcessing(false);
        toast({
          title: "Payment Error",
          description: error.message || "Failed to create payment order. Please try again.",
          variant: "destructive",
        });
      }
    } else {
      // Regular payment flow (for standalone package purchases from home page)
    if (!selectedPackage) {
      toast({
        title: "Please select a package",
        description: "Choose a package to proceed with payment.",
        variant: "destructive",
      });
      return;
    }

    setIsProcessing(true);
    try {
      const totalAmount = (selectedPkg?.installation || 0) + (selectedPkg?.monthly || 0);
      
        // Create Razorpay order for standalone package purchase
        // Use the same endpoint but without hospital_registration flag
        const orderData = await apiRequest<any>('/api/payments/create-order-hospital', {
          method: 'POST',
          body: JSON.stringify({
            hospital_registration: false,
            plan_name: selectedPkg.name,
            amount: totalAmount,
            currency: 'INR',
          }),
        });

        if (!orderData || !orderData.payment_session_id) {
          throw new Error("Invalid payment order response. Missing payment_session_id.");
        }

        setPaymentOrder(orderData);

        // Open Cashfree checkout using cashfree.pay()
        await openCashfreeCheckout(orderData.payment_session_id);
    } catch (error: any) {
      console.error("❌ DEBUG: Payment error:", error);
        setIsProcessing(false);
      toast({
        title: "Payment Failed",
        description: error.message || "Failed to process payment. Please try again.",
        variant: "destructive",
      });
      }
    }
  };

  // Calculate amount based on payment type
  const getAmount = () => {
    if (paymentType === "hospital_registration" && hospitalData?.selectedPlan) {
      return hospitalData.selectedPlan.installationPrice;
    }
    if (selectedPkg) {
      return (selectedPkg.installation || 0) + (selectedPkg.monthly || 0);
    }
    if (amountParam) {
      return parseFloat(amountParam);
    }
    return 0;
  };

  const displayAmount = getAmount();

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
        <div className="text-center mb-12">
          <h1 className="text-3xl font-bold text-foreground mb-2">
            {appointmentPaymentData 
              ? "Complete Payment" 
              : paymentType === "hospital_registration" 
                ? "Complete Payment" 
                : "Choose Your Plan"}
          </h1>
          <p className="text-muted-foreground">
            {appointmentPaymentData
              ? "Please complete payment to confirm your appointment"
              : paymentType === "hospital_registration" 
              ? "Complete payment to proceed with hospital registration"
              : "Select a package and complete payment"}
          </p>
        </div>
        
        {/* Resume Payment Button - Show if appointment payment session exists */}
        {appointmentPaymentData && !isProcessing && (
          <div className="max-w-xl mx-auto mb-8">
            <div className="bg-card rounded-2xl shadow-elevated border border-border/50 p-8 text-center">
              <h2 className="text-xl font-bold text-foreground mb-4">Complete Your Payment</h2>
              <p className="text-muted-foreground mb-6">
                Click the button below to resume your payment and complete your appointment booking.
              </p>
              <Button
                onClick={() => openCashfreeCheckout(appointmentPaymentData.paymentSessionId)}
                variant="hero"
                size="lg"
                className="w-full h-12"
              >
                <span className="flex items-center gap-2">
                  <CreditCard className="w-5 h-5" />
                  Resume Payment
                </span>
              </Button>
            </div>
          </div>
        )}

        {/* Payment Processing State */}
        {isProcessing && (
          <div className="max-w-xl mx-auto mb-8">
            <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-xl p-6 text-center">
              <Loader2 className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
              <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
                Opening Payment Gateway...
              </p>
              <p className="text-xs text-blue-700 dark:text-blue-300 mt-1">
                Please wait while we redirect you to complete your payment.
              </p>
            </div>
          </div>
        )}

        {/* Package Selection - Only show if not hospital registration */}
        {paymentType !== "hospital_registration" && (
        <div className="grid md:grid-cols-3 gap-6 max-w-5xl mx-auto mb-12">
          {packages.map((pkg) => (
            <button
              key={pkg.id}
              type="button"
              onClick={() => setSelectedPackage(pkg.id)}
              className={`relative p-6 rounded-2xl border-2 text-left transition-all ${
                selectedPackage === pkg.id
                  ? "border-primary bg-primary/5"
                  : "border-border bg-card hover:border-primary/50"
              } ${pkg.popular ? "ring-2 ring-accent ring-offset-2 ring-offset-background" : ""}`}
            >
              {pkg.popular && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-gradient-cta text-accent-foreground text-xs font-medium rounded-full">
                  Most Popular
                </span>
              )}
              <div className="mb-4">
                <h3 className="text-xl font-bold text-foreground">{pkg.name}</h3>
              </div>
              <div className="mb-4">
                <div className="text-2xl font-bold text-foreground">₹{pkg.installation.toLocaleString()}</div>
                <div className="text-sm text-muted-foreground">One-Time Software Activation & License Fee</div>
                <div className="mt-2 text-lg font-semibold text-primary">+ ₹{pkg.monthly.toLocaleString()}/month</div>
                <div className="text-sm text-muted-foreground">Monthly Technical Support & Maintenance Charges</div>
              </div>
              <ul className="space-y-2">
                {pkg.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Check className="w-4 h-4 text-primary" />
                    {feature}
                  </li>
                ))}
              </ul>
              {selectedPackage === pkg.id && (
                <div className="absolute top-4 right-4">
                  <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center">
                    <Check className="w-4 h-4 text-primary-foreground" />
                  </div>
                </div>
              )}
            </button>
          ))}
        </div>
        )}

        {/* Payment Summary for Hospital Registration */}
        {paymentType === "hospital_registration" && hospitalData?.selectedPlan && (
          <div className="max-w-xl mx-auto mb-8">
            <div className="bg-card rounded-2xl shadow-elevated border border-border/50 p-6">
              <h2 className="text-xl font-bold text-foreground mb-4">Payment Summary</h2>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Package:</span>
                  <span className="font-medium text-foreground">{hospitalData.selectedPlan.name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">One-Time Software Activation & License Fee:</span>
                  <span className="font-medium text-foreground">
                    ₹{hospitalData.selectedPlan.installationPrice.toLocaleString('en-IN')}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Monthly Technical Support & Maintenance Charges:</span>
                  <span className="font-medium text-foreground">
                    ₹{hospitalData.selectedPlan.monthlyPrice.toLocaleString('en-IN')}/month
                  </span>
                </div>
                <div className="border-t border-border pt-2 mt-2">
                  <div className="flex justify-between">
                    <span className="font-semibold text-foreground">Total (Installation):</span>
                    <span className="font-bold text-primary text-lg">
                      ₹{hospitalData.selectedPlan.installationPrice.toLocaleString('en-IN')}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Payment Section */}
        {(selectedPackage || paymentType === "hospital_registration") && (
          <div className="max-w-xl mx-auto">
            <div className="bg-card rounded-2xl shadow-elevated border border-border/50 p-8">
              <h2 className="text-xl font-bold text-foreground mb-6">Payment Details</h2>

              {/* Payment Method Toggle */}
              <div className="flex gap-4 mb-6">
                <button
                  type="button"
                  onClick={() => setPaymentMethod("upi")}
                  className={`flex-1 flex items-center justify-center gap-2 p-4 rounded-xl border-2 transition-all ${
                    paymentMethod === "upi"
                      ? "border-primary bg-primary/5 text-primary"
                      : "border-border bg-card hover:border-primary/50 text-muted-foreground"
                  }`}
                >
                  <Smartphone className="w-5 h-5" />
                  <span className="font-medium">UPI</span>
                </button>
                <button
                  type="button"
                  onClick={() => setPaymentMethod("card")}
                  className={`flex-1 flex items-center justify-center gap-2 p-4 rounded-xl border-2 transition-all ${
                    paymentMethod === "card"
                      ? "border-primary bg-primary/5 text-primary"
                      : "border-border bg-card hover:border-primary/50 text-muted-foreground"
                  }`}
                >
                  <CreditCard className="w-5 h-5" />
                  <span className="font-medium">Card</span>
                </button>
              </div>

              {paymentMethod === "upi" ? (
                <div className="space-y-4">
                  {/* UPI Type Selection */}
                  <div className="grid grid-cols-4 gap-3">
                    {upiOptions.map((option) => (
                      <button
                        key={option.id}
                        type="button"
                        onClick={() => setSelectedUpi(option.id)}
                        className={`p-3 rounded-xl border-2 text-center transition-all ${
                          selectedUpi === option.id
                            ? "border-primary bg-primary/5"
                            : "border-border hover:border-primary/50"
                        }`}
                      >
                        <div className="text-2xl mb-1">{option.icon}</div>
                        <div className="text-xs font-medium text-foreground">{option.name}</div>
                      </button>
                    ))}
                  </div>

                  {/* UPI ID Input */}
                  <div className="space-y-2">
                    <Label htmlFor="upiId" className="text-foreground font-medium">
                      UPI ID
                    </Label>
                    <Input
                      id="upiId"
                      type="text"
                      placeholder="yourname@upi"
                      value={upiId}
                      onChange={(e) => setUpiId(e.target.value)}
                      className="h-12"
                    />
                  </div>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="cardNumber" className="text-foreground font-medium">
                      Card Number
                    </Label>
                    <Input
                      id="cardNumber"
                      type="text"
                      placeholder="1234 5678 9012 3456"
                      value={cardDetails.number}
                      onChange={(e) => setCardDetails({ ...cardDetails, number: e.target.value })}
                      className="h-12"
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="expiry" className="text-foreground font-medium">
                        Expiry Date
                      </Label>
                      <Input
                        id="expiry"
                        type="text"
                        placeholder="MM/YY"
                        value={cardDetails.expiry}
                        onChange={(e) => setCardDetails({ ...cardDetails, expiry: e.target.value })}
                        className="h-12"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="cvv" className="text-foreground font-medium">
                        CVV
                      </Label>
                      <Input
                        id="cvv"
                        type="text"
                        placeholder="123"
                        value={cardDetails.cvv}
                        onChange={(e) => setCardDetails({ ...cardDetails, cvv: e.target.value })}
                        className="h-12"
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="cardName" className="text-foreground font-medium">
                      Cardholder Name
                    </Label>
                    <Input
                      id="cardName"
                      type="text"
                      placeholder="Name on card"
                      value={cardDetails.name}
                      onChange={(e) => setCardDetails({ ...cardDetails, name: e.target.value })}
                      className="h-12"
                    />
                  </div>
                </div>
              )}

              {/* Order Summary */}
              {paymentType !== "hospital_registration" && (
              <div className="mt-6 p-4 bg-muted rounded-xl">
                <div className="flex justify-between mb-2">
                  <span className="text-muted-foreground">One-Time Software Activation & License Fee</span>
                  <span className="font-semibold text-foreground">₹{selectedPkg?.installation.toLocaleString()}</span>
                </div>
                <div className="flex justify-between mb-2">
                  <span className="text-muted-foreground">First Month Technical Support & Maintenance Charges</span>
                  <span className="font-semibold text-foreground">₹{selectedPkg?.monthly.toLocaleString()}</span>
                </div>
                <div className="border-t border-border pt-2 mt-2 flex justify-between">
                  <span className="font-bold text-foreground">Total</span>
                  <span className="font-bold text-primary text-lg">
                    ₹{((selectedPkg?.installation || 0) + (selectedPkg?.monthly || 0)).toLocaleString()}
                  </span>
                </div>
              </div>
              )}

              {/* Pay Button */}
              <Button
                onClick={handlePayment}
                variant="hero"
                className="w-full h-12 mt-6"
                disabled={isProcessing || (!selectedPackage && paymentType !== "hospital_registration")}
              >
                {isProcessing ? (
                  <span className="flex items-center gap-2">
                    <Loader2 className="w-5 h-5 animate-spin" />
                    Processing...
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    Pay ₹{displayAmount.toLocaleString('en-IN')}
                    <ArrowRight className="w-5 h-5" />
                  </span>
                )}
              </Button>
            </div>

            {/* Back to Home or Registration */}
            <p className="text-center mt-6">
              {paymentType === "hospital_registration" ? (
                <Link to="/register-hospital" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
                  ← Back to Registration
                </Link>
              ) : (
              <Link to="/" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
                ← Back to Home
              </Link>
              )}
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default Payments;
