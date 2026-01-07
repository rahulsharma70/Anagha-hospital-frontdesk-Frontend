import { Calendar, User, Bell, Smartphone, RefreshCw, Building2, Shield, Heart } from "lucide-react";

const features = [
  {
    icon: Calendar,
    title: "Design Your Personalized Booking Experience",
    description: "Reduce appointment scheduling time with a custom online booking page. Allow patients to self-schedule consultations with the right specialists in just a few clicks.",
    color: "bg-primary/10 text-primary",
  },
  {
    icon: User,
    title: "Showcase Doctor Availability in Real Time",
    description: "Create detailed profiles for every doctor in your practice. Help patients easily find the right consultant while ensuring smooth and accurate appointment allocation.",
    color: "bg-accent/10 text-accent",
  },
  {
    icon: Bell,
    title: "Reduce No-Shows with Smart Reminders",
    description: "Send automated appointment reminders and confirmations. Patients can conveniently reschedule on their own, keeping your calendar accurate and up to date.",
    color: "bg-primary/10 text-primary",
  },
  {
    icon: Smartphone,
    title: "Manage Your Schedule Anytime, Anywhere",
    description: "Access your appointment calendar on the go. Receive instant alerts and stay in control of your schedule—even when you're away from the clinic.",
    color: "bg-accent/10 text-accent",
  },
  {
    icon: RefreshCw,
    title: "Plan Follow-Ups with Confidence",
    description: "Organize complete treatment journeys by scheduling recurring follow-up visits in advance. Provide consistent care without repeated manual bookings.",
    color: "bg-primary/10 text-primary",
  },
  {
    icon: Building2,
    title: "Simplify Operation Scheduling",
    description: "Easily schedule and manage surgical procedures across specialties such as Orthopedics, Gynecology, and General Surgery—all from one centralized system.",
    color: "bg-accent/10 text-accent",
  },
  {
    icon: Shield,
    title: "Healthcare-Grade Security You Can Trust",
    description: "Protect patient data with built-in security and privacy safeguards designed specifically for healthcare environments. Your data stays secure, compliant, and confidential.",
    color: "bg-primary/10 text-primary",
  },
  {
    icon: Heart,
    title: "Designed for Every Healthcare Professional",
    description: "Whether you're a hospital, clinic, doctor, or specialist, our platform adapts seamlessly to your workflow—making appointment management simpler for everyone.",
    color: "bg-accent/10 text-accent",
  },
];

const Features = () => {
  return (
    <section id="features" className="py-16 lg:py-24 relative">
      <div className="absolute inset-0 bg-gradient-subtle opacity-50" />
      
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 relative">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 animate-fade-up">
          <span className="inline-block px-4 py-2 rounded-full bg-secondary text-secondary-foreground text-sm font-semibold mb-4">
            Powerful Features
          </span>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-foreground mb-6">
            Optimize Your Practice, <span className="text-gradient">Effortlessly</span>
          </h2>
          <p className="text-lg text-muted-foreground leading-relaxed">
            Everything you need to streamline appointments, reduce no-shows, and deliver exceptional patient care.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6 lg:gap-8">
          {features.map((feature, index) => (
            <div
              key={feature.title}
              className="group bg-card rounded-2xl p-6 border border-border/50 shadow-soft hover:shadow-elevated transition-all duration-300 hover:-translate-y-1"
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <div className={`w-14 h-14 rounded-xl ${feature.color} flex items-center justify-center mb-5 group-hover:scale-110 transition-transform duration-300`}>
                <feature.icon className="w-7 h-7" />
              </div>
              
              <h3 className="text-lg font-bold text-foreground mb-3 leading-tight">
                {feature.title}
              </h3>
              
              <p className="text-muted-foreground text-sm leading-relaxed">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Features;
