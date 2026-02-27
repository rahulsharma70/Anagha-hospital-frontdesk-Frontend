import { Button } from "@/components/ui/button";
import { ArrowRight, Bell, Clock } from "lucide-react";
import { useNavigate } from "react-router-dom";

const CTA = () => {
  const navigate = useNavigate();
  return (
    <section className="py-16 lg:py-24 relative overflow-hidden">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 relative">
        {/* Main CTA Card */}
        <div className="relative bg-gradient-hero rounded-3xl p-8 lg:p-16 overflow-hidden">
          {/* Background decorations */}
          <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl" />
          <div className="absolute bottom-0 left-0 w-80 h-80 bg-white/5 rounded-full blur-3xl" />

          <div className="relative z-10 max-w-3xl mx-auto text-center">
            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-primary-foreground mb-6">
              Make Time for What Truly Matters
            </h2>
            <p className="text-lg lg:text-xl text-primary-foreground/90 mb-8 leading-relaxed">
              Join thousands of healthcare providers who trust our platform to streamline appointments and deliver exceptional patient care.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Button 
                variant="cta" 
                size="xl" 
                className="group bg-card text-foreground hover:bg-card/90"
                onClick={() => navigate("/register")}
              >
                Get Started FREE
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </Button>
            </div>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid sm:grid-cols-2 gap-6 lg:gap-8 mt-12 max-w-2xl mx-auto">
          <div className="bg-card rounded-2xl p-6 shadow-card border border-border/50">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                <Bell className="w-6 h-6 text-primary" />
              </div>
              <div>
                <h3 className="font-bold text-foreground text-lg mb-2">
                  Reduce Missed Appointments
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  Automatic appointment reminders help reduce costly no-shows and maximize your in-practice hours.
                </p>
              </div>
            </div>
          </div>

          <div className="bg-card rounded-2xl p-6 shadow-card border border-border/50">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center">
                <Clock className="w-6 h-6 text-accent" />
              </div>
              <div>
                <h3 className="font-bold text-foreground text-lg mb-2">
                  Save Time & Resources
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  Online scheduling eliminates phone tag and reduces administrative workload significantly.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default CTA;
