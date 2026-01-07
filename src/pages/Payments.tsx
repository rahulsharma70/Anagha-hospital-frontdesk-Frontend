import { useState, useEffect } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Heart, Check, CreditCard, Smartphone, ArrowRight, Loader2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { paymentsAPI, apiRequest } from "@/lib/api";
import { load } from "@cashfreepayments/cashfree-js";

type PaymentMethod = "upi" | "card";

const packages = [
  {
    id: "starter",
    name: "Starter",
    installation: 5000,
    monthly: 1000,
    features: ["Basic Appointment System", "Up to 5 Doctors", "Email Support", "Basic Analytics"],
    popular: false,
  },
  {
    id: "professional",
    name: "Professional",
    installation: 10000,
    monthly: 2000,
    features: ["Advanced Booking System", "Up to 25 Doctors", "Priority Support", "Advanced Analytics", "Payment Integration"],
    popular: true,
  },
  {
    id: "enterprise",
    name: "Enterprise",
    installation: 20000,
    monthly: 5000,
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
        const orderData = await paymentsAPI.createHospitalRegistrationOrder(
          hospitalData.selectedPlan.name,
          hospitalData.selectedPlan.installationPrice
        );

        if (!orderData || !orderData.payment_session_id) {
          throw new Error("Invalid payment order response. Missing payment_session_id.");
        }

        setPaymentOrder(orderData);

        // Open Cashfree checkout
        try {
          const cashfree = await load();
          
          const checkoutOptions = {
            paymentSessionId: orderData.payment_session_id,
            redirectTarget: "_self" as const
          };

          cashfree.checkout(checkoutOptions);
          
          // Cashfree will handle the payment flow and redirect
          // Payment status will be updated via webhook
          setIsProcessing(true);
        } catch (error: any) {
          setIsProcessing(false);
          toast({
            title: "Payment Error",
            description: error.message || "Failed to initialize payment. Please try again.",
            variant: "destructive",
          });
        }
      } catch (error: any) {
        console.error("Error creating payment order:", error);
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

        // Open Cashfree checkout
        try {
          const cashfree = await load();
          
          const checkoutOptions = {
            paymentSessionId: orderData.payment_session_id,
            redirectTarget: "_self" as const
          };

          cashfree.checkout(checkoutOptions);
          
          // Cashfree will handle the payment flow and redirect
          // Payment status will be updated via webhook
          setIsProcessing(true);
        } catch (error: any) {
          setIsProcessing(false);
          toast({
            title: "Payment Error",
            description: error.message || "Failed to initialize payment. Please try again.",
            variant: "destructive",
          });
        }
    } catch (error: any) {
      console.error("Payment error:", error);
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
            {paymentType === "hospital_registration" ? "Complete Payment" : "Choose Your Plan"}
          </h1>
          <p className="text-muted-foreground">
            {paymentType === "hospital_registration" 
              ? "Complete payment to proceed with hospital registration"
              : "Select a package and complete payment"}
          </p>
        </div>

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
                <div className="text-sm text-muted-foreground">Installation Fee</div>
                <div className="mt-2 text-lg font-semibold text-primary">+ ₹{pkg.monthly.toLocaleString()}/month</div>
                <div className="text-sm text-muted-foreground">Maintenance</div>
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
                  <span className="text-muted-foreground">Installation Fee:</span>
                  <span className="font-medium text-foreground">
                    ₹{hospitalData.selectedPlan.installationPrice.toLocaleString('en-IN')}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Monthly Fee:</span>
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
                  <span className="text-muted-foreground">Installation Fee</span>
                  <span className="font-semibold text-foreground">₹{selectedPkg?.installation.toLocaleString()}</span>
                </div>
                <div className="flex justify-between mb-2">
                  <span className="text-muted-foreground">First Month Maintenance</span>
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
