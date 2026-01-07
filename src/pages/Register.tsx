import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Heart, Mail, Lock, Eye, EyeOff, ArrowRight, User, Phone, MapPin, GraduationCap, Briefcase, Building2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { z } from "zod";
import { register } from "@/lib/auth";
import { hospitalsAPI } from "@/lib/api";

type UserType = "patient" | "doctor" | "pharma";

const baseSchema = z.object({
  name: z.string().trim().min(2, { message: "Name must be at least 2 characters" }).max(100),
  mobile: z.string().trim().min(10, { message: "Please enter a valid mobile number" }).max(15),
  password: z.string().min(8, { message: "Password must be at least 8 characters" }),
  confirmPassword: z.string(),
  email: z.string().optional(),
  address: z.string().optional(),
});

const doctorSchema = baseSchema.extend({
  degree: z.string().trim().min(2, { message: "Degree is required" }),
  institute_name: z.string().trim().min(2, { message: "Institute name is required" }),
});

const pharmaSchema = baseSchema.extend({
  hospital_id: z.string().trim().min(1, { message: "Hospital selection is required" }),
  company_name: z.string().trim().min(2, { message: "Company name is required" }),
});

type FormErrors = {
  name?: string;
  mobile?: string;
  email?: string;
  address?: string;
  password?: string;
  confirmPassword?: string;
  degree?: string;
  institute_name?: string;
  hospital_id?: string;
  company_name?: string;
};

const Register = () => {
  const [userType, setUserType] = useState<UserType>("patient");
  const [formData, setFormData] = useState({
    name: "",
    mobile: "",
    email: "",
    address: "",
    password: "",
    confirmPassword: "",
    degree: "",
    institute_name: "",
    hospital_id: "",
    company_name: "",
  });
  const [hospitals, setHospitals] = useState<any[]>([]);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [errors, setErrors] = useState<FormErrors>({});
  const [isLoading, setIsLoading] = useState(false);
  const { toast } = useToast();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchHospitals = async () => {
      try {
        const hospitalsData = await hospitalsAPI.getApproved();
        setHospitals(hospitalsData || []);
      } catch (error) {
        console.error("Error fetching hospitals:", error);
      }
    };
    if (userType === "patient" || userType === "pharma") {
      fetchHospitals();
    }
  }, [userType]);

  const handleChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setFormData((prev) => ({ ...prev, [field]: e.target.value }));
    if (errors[field as keyof FormErrors]) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrors({});

    let schema;
    if (userType === "doctor") {
      schema = doctorSchema;
    } else if (userType === "pharma") {
      schema = pharmaSchema;
    } else {
      schema = baseSchema;
    }

    const dataToValidate = {
      ...formData,
      ...(userType === "doctor" ? { degree: formData.degree, institute_name: formData.institute_name } : {}),
      ...(userType === "pharma" ? { hospital_id: formData.hospital_id, company_name: formData.company_name } : {}),
    };

    const result = schema.safeParse(dataToValidate);
    
    if (!result.success) {
      const fieldErrors: FormErrors = {};
      result.error.errors.forEach((err) => {
        const field = err.path[0] as keyof FormErrors;
        fieldErrors[field] = err.message;
      });
      setErrors(fieldErrors);
      return;
    }

    if (formData.password !== formData.confirmPassword) {
      setErrors({ confirmPassword: "Passwords don't match" });
      return;
    }

    setIsLoading(true);
    
    try {
      const role = userType === "patient" ? "patient" : userType === "doctor" ? "doctor" : "pharma";
      const registerData: any = {
        name: formData.name,
        mobile: formData.mobile,
        password: formData.password,
        role: role,
      };

      if (formData.email) {
        registerData.email = formData.email;
      }
      if (formData.address) {
        registerData.address_line1 = formData.address;
      }

      if (userType === "doctor") {
        registerData.degree = formData.degree;
        registerData.institute_name = formData.institute_name;
      }

      if (userType === "pharma") {
        registerData.hospital_id = parseInt(formData.hospital_id);
        registerData.company_name = formData.company_name;
      }

      if (userType === "patient" && formData.hospital_id) {
        registerData.hospital_id = parseInt(formData.hospital_id);
      }

      await register(registerData);
      toast({
        title: "Registration Successful",
        description: `Welcome to Anagha Health Connect! Your ${userType} account has been created.`,
      });
      navigate("/dashboard");
    } catch (error: any) {
      setIsLoading(false);
      toast({
        title: "Registration Failed",
        description: error.message || "Failed to create account. Please try again.",
        variant: "destructive",
      });
    }
  };

  const userTypes = [
    { value: "patient" as UserType, label: "Patient", icon: User },
    { value: "doctor" as UserType, label: "Doctor", icon: GraduationCap },
    { value: "pharma" as UserType, label: "Pharma Professional", icon: Building2 },
  ];

  return (
    <div className="min-h-screen bg-background flex">
      {/* Left Side - Visual */}
      <div className="hidden lg:flex flex-1 bg-gradient-hero items-center justify-center p-12 relative overflow-hidden">
        <div className="absolute inset-0 bg-primary/10" />
        <div className="absolute top-20 left-20 w-64 h-64 bg-primary-foreground/10 rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-20 w-48 h-48 bg-accent/20 rounded-full blur-3xl" />
        
        <div className="relative z-10 text-center text-primary-foreground max-w-md">
          <div className="text-6xl mb-6">🏥</div>
          <h3 className="text-3xl font-bold mb-4">
            Start Your Healthcare Journey
          </h3>
          <p className="text-primary-foreground/80 text-lg">
            Create an account to manage appointments, connect with patients, and grow your practice
          </p>
          
          <div className="mt-8 space-y-4 text-left bg-primary-foreground/10 rounded-2xl p-6 backdrop-blur-sm">
            <div className="flex items-center gap-3">
              <span className="w-8 h-8 rounded-full bg-primary-foreground/20 flex items-center justify-center text-sm">✓</span>
              <span>Easy appointment scheduling</span>
            </div>
            <div className="flex items-center gap-3">
              <span className="w-8 h-8 rounded-full bg-primary-foreground/20 flex items-center justify-center text-sm">✓</span>
              <span>Automated reminders</span>
            </div>
            <div className="flex items-center gap-3">
              <span className="w-8 h-8 rounded-full bg-primary-foreground/20 flex items-center justify-center text-sm">✓</span>
              <span>Secure patient data</span>
            </div>
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
            Create Your Account
          </h2>
          <p className="text-center text-muted-foreground mb-6">
            Join Anagha Health Connect today
          </p>

          {/* User Type Selection */}
          <div className="flex gap-2 mb-6">
            {userTypes.map((type) => (
              <button
                key={type.value}
                type="button"
                onClick={() => setUserType(type.value)}
                className={`flex-1 flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all ${
                  userType === type.value
                    ? "border-primary bg-primary/5 text-primary"
                    : "border-border bg-card hover:border-primary/50 text-muted-foreground"
                }`}
              >
                <type.icon className="w-6 h-6" />
                <span className="text-sm font-medium">{type.label}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="sm:mx-auto sm:w-full sm:max-w-lg">
          <div className="bg-card rounded-2xl shadow-elevated border border-border/50 p-8">
            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Name Field */}
              <div className="space-y-2">
                <Label htmlFor="name" className="text-foreground font-medium">
                  Full Name
                </Label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="name"
                    type="text"
                    placeholder={userType === "doctor" ? "Dr. John Smith" : "John Smith"}
                    value={formData.name}
                    onChange={handleChange("name")}
                    className={`pl-10 h-12 ${errors.name ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.name && <p className="text-sm text-destructive">{errors.name}</p>}
              </div>

              {/* Mobile Field */}
              <div className="space-y-2">
                <Label htmlFor="mobile" className="text-foreground font-medium">
                  Mobile Number <span className="text-destructive">*</span>
                </Label>
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="mobile"
                    type="tel"
                    placeholder="+91-9876543210"
                    value={formData.mobile}
                    onChange={handleChange("mobile")}
                    className={`pl-10 h-12 ${errors.mobile ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.mobile && <p className="text-sm text-destructive">{errors.mobile}</p>}
              </div>

              {/* Email Field (Optional) */}
              <div className="space-y-2">
                <Label htmlFor="email" className="text-foreground font-medium">
                  Email Address (Optional)
                </Label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="email"
                    type="email"
                    placeholder="you@example.com"
                    value={formData.email}
                    onChange={handleChange("email")}
                    className={`pl-10 h-12 ${errors.email ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.email && <p className="text-sm text-destructive">{errors.email}</p>}
              </div>

              {/* Address Field (Optional) */}
              <div className="space-y-2">
                <Label htmlFor="address" className="text-foreground font-medium">
                  Address (Optional)
                </Label>
                <div className="relative">
                  <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="address"
                    type="text"
                    placeholder="Your full address"
                    value={formData.address}
                    onChange={handleChange("address")}
                    className={`pl-10 h-12 ${errors.address ? "border-destructive" : ""}`}
                  />
                </div>
                {errors.address && <p className="text-sm text-destructive">{errors.address}</p>}
              </div>

              {/* Doctor-specific fields */}
              {userType === "doctor" && (
                <>
                  <div className="space-y-2">
                    <Label htmlFor="degree" className="text-foreground font-medium">
                      Degree / Qualification <span className="text-destructive">*</span>
                    </Label>
                    <div className="relative">
                      <GraduationCap className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                      <Input
                        id="degree"
                        type="text"
                        placeholder="MBBS, MD, etc."
                        value={formData.degree}
                        onChange={handleChange("degree")}
                        className={`pl-10 h-12 ${errors.degree ? "border-destructive" : ""}`}
                      />
                    </div>
                    {errors.degree && <p className="text-sm text-destructive">{errors.degree}</p>}
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="institute_name" className="text-foreground font-medium">
                      Institute Name <span className="text-destructive">*</span>
                    </Label>
                    <div className="relative">
                      <Briefcase className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                      <Input
                        id="institute_name"
                        type="text"
                        placeholder="Medical college or institute"
                        value={formData.institute_name}
                        onChange={handleChange("institute_name")}
                        className={`pl-10 h-12 ${errors.institute_name ? "border-destructive" : ""}`}
                      />
                    </div>
                    {errors.institute_name && <p className="text-sm text-destructive">{errors.institute_name}</p>}
                  </div>
                </>
              )}

              {/* Pharma-specific fields */}
              {userType === "pharma" && (
                <>
                  <div className="space-y-2">
                    <Label htmlFor="company_name" className="text-foreground font-medium">
                      Company Name <span className="text-destructive">*</span>
                    </Label>
                    <div className="relative">
                      <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                      <Input
                        id="company_name"
                        type="text"
                        placeholder="Your pharma company"
                        value={formData.company_name}
                        onChange={handleChange("company_name")}
                        className={`pl-10 h-12 ${errors.company_name ? "border-destructive" : ""}`}
                      />
                    </div>
                    {errors.company_name && <p className="text-sm text-destructive">{errors.company_name}</p>}
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="hospital_id" className="text-foreground font-medium">
                      Hospital <span className="text-destructive">*</span>
                    </Label>
                    <select
                      id="hospital_id"
                      value={formData.hospital_id}
                      onChange={handleChange("hospital_id")}
                      className={`w-full h-12 rounded-md border bg-background px-3 text-foreground ${errors.hospital_id ? "border-destructive" : "border-input"}`}
                    >
                      <option value="">Select hospital</option>
                      {hospitals.map((h) => (
                        <option key={h.id} value={h.id}>{h.name}</option>
                      ))}
                    </select>
                    {errors.hospital_id && <p className="text-sm text-destructive">{errors.hospital_id}</p>}
                  </div>
                </>
              )}

              {/* Patient Hospital Selection (Optional) */}
              {userType === "patient" && hospitals.length > 0 && (
                <div className="space-y-2">
                  <Label htmlFor="hospital_id" className="text-foreground font-medium">
                    Preferred Hospital (Optional)
                  </Label>
                  <select
                    id="hospital_id"
                    value={formData.hospital_id}
                    onChange={handleChange("hospital_id")}
                    className="w-full h-12 rounded-md border bg-background px-3 text-foreground border-input"
                  >
                    <option value="">Select hospital (optional)</option>
                    {hospitals.map((h) => (
                      <option key={h.id} value={h.id}>{h.name}</option>
                    ))}
                  </select>
                </div>
              )}

              {/* Password Field */}
              <div className="space-y-2">
                <Label htmlFor="password" className="text-foreground font-medium">
                  Password <span className="text-destructive">*</span>
                </Label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="password"
                    type={showPassword ? "text" : "password"}
                    placeholder="••••••••"
                    value={formData.password}
                    onChange={handleChange("password")}
                    className={`pl-10 pr-10 h-12 ${errors.password ? "border-destructive" : ""}`}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                {errors.password && <p className="text-sm text-destructive">{errors.password}</p>}
              </div>

              {/* Confirm Password Field */}
              <div className="space-y-2">
                <Label htmlFor="confirmPassword" className="text-foreground font-medium">
                  Confirm Password <span className="text-destructive">*</span>
                </Label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                  <Input
                    id="confirmPassword"
                    type={showConfirmPassword ? "text" : "password"}
                    placeholder="••••••••"
                    value={formData.confirmPassword}
                    onChange={handleChange("confirmPassword")}
                    className={`pl-10 pr-10 h-12 ${errors.confirmPassword ? "border-destructive" : ""}`}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {showConfirmPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                {errors.confirmPassword && <p className="text-sm text-destructive">{errors.confirmPassword}</p>}
              </div>

              {/* Terms */}
              <p className="text-sm text-muted-foreground">
                By creating an account, you agree to our{" "}
                <a href="#" className="text-primary hover:underline">Terms of Service</a>
                {" "}and{" "}
                <a href="#" className="text-primary hover:underline">Privacy Policy</a>
              </p>

              {/* Submit Button */}
              <Button
                type="submit"
                variant="hero"
                className="w-full h-12"
                disabled={isLoading}
              >
                {isLoading ? (
                  <span className="flex items-center gap-2">
                    <span className="w-5 h-5 border-2 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin" />
                    Creating Account...
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    Create Account
                    <ArrowRight className="w-5 h-5" />
                  </span>
                )}
              </Button>
            </form>

            {/* Divider */}
            <div className="relative my-6">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-border" />
              </div>
              <div className="relative flex justify-center text-sm">
                <span className="px-4 bg-card text-muted-foreground">
                  Already have an account?
                </span>
              </div>
            </div>

            {/* Login Link */}
            <Link to="/login">
              <Button variant="outline" className="w-full h-12">
                Sign In Instead
              </Button>
            </Link>
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

export default Register;
