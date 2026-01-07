import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useNavigate } from "react-router-dom";

const benefits = [
  {
    title: "Appointments Made Easy for You and Your Patients",
    description: "Simple, intuitive booking that works for everyone",
  },
  {
    title: "Book Care, Not Phone Calls",
    description: "Skip the wait. Book instantly, anytime, anywhere",
  },
  {
    title: "Healthcare That Fits Your Schedule",
    description: "Flexible scheduling that adapts to your life",
  },
];

const Benefits = () => {
  const navigate = useNavigate();
  
  return (
    <section className="py-16 lg:py-24 bg-card relative overflow-hidden">
      <div className="absolute top-0 right-0 w-96 h-96 bg-primary/5 rounded-full blur-3xl" />
      <div className="absolute bottom-0 left-0 w-80 h-80 bg-accent/5 rounded-full blur-3xl" />

      <div className="container mx-auto px-4 sm:px-6 lg:px-8 relative">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Visual Side */}
          <div className="relative order-2 lg:order-1">
            <div className="relative">
              {/* Main Image Placeholder */}
              <div className="bg-gradient-hero rounded-3xl p-8 lg:p-12 shadow-glow">
                <div className="flex flex-col items-center text-center space-y-6">
                  <div className="text-8xl lg:text-9xl">👨‍⚕️👩‍⚕️</div>
                  <h3 className="text-2xl lg:text-3xl font-bold text-primary-foreground">
                    Patient-First Care
                  </h3>
                  <p className="text-primary-foreground/80 text-lg">
                    Compassionate healthcare professionals
                  </p>
                </div>
              </div>

              {/* Floating Badge */}
              <div className="absolute -top-4 -right-4 bg-card rounded-2xl shadow-elevated p-4 border border-border/50 animate-float">
                <div className="flex items-center gap-2">
                  <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center">
                    <span className="text-xl">💚</span>
                  </div>
                  <span className="font-semibold text-foreground">Patient-First & Friendly</span>
                </div>
              </div>
            </div>
          </div>

          {/* Content Side */}
          <div className="order-1 lg:order-2 space-y-8">
            <div className="space-y-4">
              <span className="inline-block px-4 py-2 rounded-full bg-secondary text-secondary-foreground text-sm font-semibold">
                Why Choose Us
              </span>
              <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-foreground leading-tight">
                Effortless Doctor Appointments,{" "}
                <span className="text-gradient">Better Patient Care</span>
              </h2>
              <p className="text-lg text-muted-foreground">
                Manage schedules efficiently while putting patients first with a fast, secure, and easy-to-use appointment booking system.
              </p>
            </div>

            <div className="space-y-5">
              {benefits.map((benefit, index) => (
                <div
                  key={benefit.title}
                  className="flex gap-4 p-4 rounded-xl bg-secondary/50 hover:bg-secondary transition-colors duration-300"
                >
                  <div className="flex-shrink-0">
                    <CheckCircle2 className="w-6 h-6 text-primary" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">{benefit.title}</h4>
                    <p className="text-muted-foreground text-sm">{benefit.description}</p>
                  </div>
                </div>
              ))}
            </div>

            <Button 
              variant="hero" 
              size="lg"
              onClick={() => navigate("/register")}
            >
              Get Started Today
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Benefits;
