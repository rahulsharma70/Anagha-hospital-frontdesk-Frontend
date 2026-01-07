import { Button } from "@/components/ui/button";
import { ArrowRight, Play, Shield, Clock, Users } from "lucide-react";
import { useNavigate } from "react-router-dom";

const Hero = () => {
  const navigate = useNavigate();
  return (
    <section className="relative pt-24 lg:pt-32 pb-16 lg:pb-24 overflow-hidden">
      {/* Background Elements */}
      <div className="absolute inset-0 bg-gradient-subtle" />
      <div className="absolute top-20 right-0 w-96 h-96 bg-primary/5 rounded-full blur-3xl" />
      <div className="absolute bottom-0 left-0 w-80 h-80 bg-accent/5 rounded-full blur-3xl" />

      <div className="container mx-auto px-4 sm:px-6 lg:px-8 relative">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Content */}
          <div className="text-center lg:text-left space-y-8 animate-fade-up">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-secondary text-secondary-foreground text-sm font-medium">
              <Shield className="w-4 h-4" />
              Connecting Care, Empowering Health
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold leading-tight">
              <span className="text-foreground">Online Doctor</span>
              <br />
              <span className="text-gradient">Appointment</span>
              <br />
              <span className="text-foreground">Scheduling Software</span>
            </h1>

            <p className="text-lg lg:text-xl text-muted-foreground max-w-xl mx-auto lg:mx-0 leading-relaxed">
              Increase efficiency and keep patients at the heart of your practice. 
              Manage schedules effortlessly while putting patients first.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <Button 
                variant="hero" 
                size="xl" 
                className="group"
                onClick={() => navigate("/register")}
              >
                Sign Up FREE Today
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </Button>
              <Button 
                variant="hero-outline" 
                size="xl" 
                className="group"
                onClick={() => navigate("/book-appointment")}
              >
                <Play className="w-5 h-5" />
                Watch Demo
              </Button>
            </div>

            {/* Trust Badges */}
            <div className="flex flex-wrap justify-center lg:justify-start gap-6 pt-4">
              <div className="flex items-center gap-2 text-muted-foreground">
                <Clock className="w-5 h-5 text-primary" />
                <span className="text-sm font-medium">24/7 Support</span>
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Shield className="w-5 h-5 text-primary" />
                <span className="text-sm font-medium">HIPAA Compliant</span>
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Users className="w-5 h-5 text-primary" />
                <span className="text-sm font-medium">10,000+ Doctors</span>
              </div>
            </div>
          </div>

          {/* Visual Element */}
          <div className="relative animate-fade-up-delayed">
            <div className="relative z-10">
              {/* Main Card */}
              <div className="bg-card rounded-3xl shadow-elevated p-6 lg:p-8 border border-border/50">
                <div className="flex items-center gap-4 mb-6">
                  <div className="w-16 h-16 rounded-2xl bg-gradient-hero flex items-center justify-center text-3xl shadow-soft">
                    👨‍⚕️
                  </div>
                  <div>
                    <h3 className="font-bold text-foreground text-lg">Dr. Sarah Mitchell</h3>
                    <p className="text-muted-foreground">Cardiologist • Available Today</p>
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="flex gap-2">
                    {["9:00 AM", "10:30 AM", "2:00 PM", "4:30 PM"].map((time) => (
                      <button
                        key={time}
                        className="flex-1 py-2 px-3 rounded-lg bg-secondary text-secondary-foreground text-sm font-medium hover:bg-primary hover:text-primary-foreground transition-all duration-200"
                      >
                        {time}
                      </button>
                    ))}
                  </div>

                  <Button 
                    variant="cta" 
                    className="w-full" 
                    size="lg"
                    onClick={() => navigate("/book-appointment")}
                  >
                    Book Appointment
                  </Button>
                </div>
              </div>

              {/* Floating Cards */}
              <div className="absolute -top-6 -right-6 bg-card rounded-2xl shadow-card p-4 border border-border/50 animate-float hidden sm:block">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-green-100 flex items-center justify-center">
                    <span className="text-green-600 font-bold">✓</span>
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-foreground">Appointment Confirmed</p>
                    <p className="text-xs text-muted-foreground">Tomorrow, 10:30 AM</p>
                  </div>
                </div>
              </div>

              <div className="absolute -bottom-4 -left-6 bg-card rounded-2xl shadow-card p-4 border border-border/50 animate-float-delayed hidden sm:block">
                <div className="flex items-center gap-3">
                  <div className="text-3xl">👩‍⚕️</div>
                  <div>
                    <p className="text-sm font-semibold text-foreground">Dr. Emily Chen</p>
                    <p className="text-xs text-primary font-medium">Available Now</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Background Decoration */}
            <div className="absolute -z-10 top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[120%] h-[120%] bg-gradient-hero opacity-10 rounded-full blur-3xl" />
          </div>
        </div>
      </div>
    </section>
  );
};

export default Hero;
