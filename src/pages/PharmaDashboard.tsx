import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Heart, Calendar, User, Clock, Building2, Bell, Plus, FileText, CheckCircle, XCircle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { appointmentsAPI } from "@/lib/api";
import { getCurrentUser } from "@/lib/auth";

type AppointmentStatus = "pending" | "confirmed" | "completed" | "cancelled";

interface Appointment {
  id: string;
  doctorName: string;
  hospital: string;
  date: string;
  time: string;
  purpose: string;
  status: AppointmentStatus;
}

const PharmaDashboard = () => {
  const [activeTab, setActiveTab] = useState<"appointments" | "notifications">("appointments");
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchData = async () => {
      try {
        const currentUser = await getCurrentUser();
        if (!currentUser || currentUser.role?.toLowerCase() !== "pharma") {
          navigate("/login");
          return;
        }

        const appts = await appointmentsAPI.getMyAppointments();
        
        // Transform backend data to frontend format
        const transformedAppointments: Appointment[] = (appts || []).map((apt: any) => ({
          id: apt.id.toString(),
          doctorName: apt.doctor_name || "Unknown Doctor",
          hospital: apt.hospital_name || "Unknown Hospital",
          date: apt.date || "",
          time: apt.time_slot || "",
          purpose: apt.reason || apt.purpose || "Product Discussion",
          status: apt.status || "pending"
        }));

        setAppointments(transformedAppointments);
        
        // For notifications, we can derive from appointments (confirmed, cancelled, etc.)
        // In a real app, you'd have a separate notifications endpoint
        const appointmentNotifications = transformedAppointments
          .filter(apt => apt.status === "confirmed" || apt.status === "cancelled")
          .map(apt => ({
            id: apt.id,
            message: apt.status === "confirmed" 
              ? `Your appointment with ${apt.doctorName} is confirmed`
              : `Appointment with ${apt.doctorName} has been ${apt.status}`,
            time: apt.date,
            unread: true,
            type: apt.status
          }));
        setNotifications(appointmentNotifications);
      } catch (error) {
        console.error("Error fetching appointments:", error);
        toast({
          title: "Error",
          description: "Failed to load appointments. Please try again.",
          variant: "destructive",
        });
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [navigate, toast]);

  const getStatusColor = (status: AppointmentStatus) => {
    switch (status) {
      case "confirmed":
        return "bg-primary/10 text-primary";
      case "pending":
        return "bg-accent/10 text-accent";
      case "completed":
        return "bg-green-100 text-green-700";
      case "cancelled":
        return "bg-destructive/10 text-destructive";
    }
  };

  const getStatusIcon = (status: AppointmentStatus) => {
    switch (status) {
      case "confirmed":
        return <CheckCircle className="w-4 h-4" />;
      case "pending":
        return <Clock className="w-4 h-4" />;
      case "completed":
        return <CheckCircle className="w-4 h-4" />;
      case "cancelled":
        return <XCircle className="w-4 h-4" />;
    }
  };

  const upcomingCount = appointments.filter((a) => a.status === "pending" || a.status === "confirmed").length;
  const completedCount = appointments.filter((a) => a.status === "completed").length;
  const unreadNotifications = notifications.filter((n) => n.unread).length;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border sticky top-0 z-10">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <Link to="/" className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-xl bg-gradient-hero flex items-center justify-center shadow-soft">
                <Heart className="w-5 h-5 text-primary-foreground" />
              </div>
              <span className="font-bold text-xl text-foreground">Anagha Health</span>
            </Link>
            <div className="flex items-center gap-4">
              <Button variant="outline" size="sm" className="relative" onClick={() => setActiveTab("notifications")}>
                <Bell className="w-4 h-4" />
                {unreadNotifications > 0 && (
                  <span className="absolute -top-1 -right-1 w-4 h-4 bg-accent text-accent-foreground text-xs rounded-full flex items-center justify-center">
                    {unreadNotifications}
                  </span>
                )}
              </Button>
              <Link to="/pharma-appointment">
                <Button variant="hero" size="sm" className="flex items-center gap-2">
                  <Plus className="w-4 h-4" />
                  Book Appointment
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-foreground mb-2">Welcome, Pharma Representative!</h1>
          <p className="text-muted-foreground">Manage your doctor appointments and meetings</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-card rounded-xl border border-border p-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
                <Calendar className="w-5 h-5 text-primary" />
              </div>
              <div>
                <div className="text-2xl font-bold text-foreground">{upcomingCount}</div>
                <div className="text-sm text-muted-foreground">Upcoming</div>
              </div>
            </div>
          </div>
          <div className="bg-card rounded-xl border border-border p-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-green-100 flex items-center justify-center">
                <CheckCircle className="w-5 h-5 text-green-600" />
              </div>
              <div>
                <div className="text-2xl font-bold text-foreground">{completedCount}</div>
                <div className="text-sm text-muted-foreground">Completed</div>
              </div>
            </div>
          </div>
          <div className="bg-card rounded-xl border border-border p-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center">
                <User className="w-5 h-5 text-accent" />
              </div>
              <div>
                <div className="text-2xl font-bold text-foreground">12</div>
                <div className="text-sm text-muted-foreground">Doctors</div>
              </div>
            </div>
          </div>
          <div className="bg-card rounded-xl border border-border p-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center">
                <Building2 className="w-5 h-5 text-secondary-foreground" />
              </div>
              <div>
                <div className="text-2xl font-bold text-foreground">5</div>
                <div className="text-sm text-muted-foreground">Hospitals</div>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-4 mb-6">
          <button
            onClick={() => setActiveTab("appointments")}
            className={`px-4 py-2 rounded-lg font-medium transition-all ${
              activeTab === "appointments"
                ? "bg-primary text-primary-foreground"
                : "bg-card text-muted-foreground hover:bg-muted"
            }`}
          >
            My Appointments
          </button>
          <button
            onClick={() => setActiveTab("notifications")}
            className={`px-4 py-2 rounded-lg font-medium transition-all relative ${
              activeTab === "notifications"
                ? "bg-primary text-primary-foreground"
                : "bg-card text-muted-foreground hover:bg-muted"
            }`}
          >
            Notifications
            {unreadNotifications > 0 && activeTab !== "notifications" && (
              <span className="absolute -top-1 -right-1 w-4 h-4 bg-accent text-accent-foreground text-xs rounded-full flex items-center justify-center">
                {unreadNotifications}
              </span>
            )}
          </button>
        </div>

        {/* Content */}
        {activeTab === "appointments" ? (
          <div className="bg-card rounded-2xl border border-border overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-muted">
                  <tr>
                    <th className="px-6 py-4 text-left text-sm font-semibold text-foreground">Doctor</th>
                    <th className="px-6 py-4 text-left text-sm font-semibold text-foreground">Hospital</th>
                    <th className="px-6 py-4 text-left text-sm font-semibold text-foreground">Date & Time</th>
                    <th className="px-6 py-4 text-left text-sm font-semibold text-foreground">Purpose</th>
                    <th className="px-6 py-4 text-left text-sm font-semibold text-foreground">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {loading ? (
                    <tr>
                      <td colSpan={5} className="px-6 py-8 text-center text-muted-foreground">
                        Loading appointments...
                      </td>
                    </tr>
                  ) : appointments.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-6 py-8 text-center text-muted-foreground">
                        No appointments found. Book your first appointment!
                      </td>
                    </tr>
                  ) : (
                    appointments.map((appointment) => (
                    <tr key={appointment.id} className="hover:bg-muted/50 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                            <User className="w-5 h-5 text-primary" />
                          </div>
                          <span className="font-medium text-foreground">{appointment.doctorName}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-muted-foreground">{appointment.hospital}</td>
                      <td className="px-6 py-4">
                        <div className="text-foreground">{appointment.date}</div>
                        <div className="text-sm text-muted-foreground">{appointment.time}</div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2 text-muted-foreground">
                          <FileText className="w-4 h-4" />
                          {appointment.purpose}
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(appointment.status)}`}>
                          {getStatusIcon(appointment.status)}
                          {appointment.status.charAt(0).toUpperCase() + appointment.status.slice(1)}
                        </span>
                      </td>
                    </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          <div className="bg-card rounded-2xl border border-border p-6">
            {notifications.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-muted-foreground">No notifications yet</p>
                <p className="text-sm text-muted-foreground mt-2">You'll see notifications about your appointments here</p>
              </div>
            ) : (
              <div className="space-y-4">
                {notifications.map((notification) => (
                  <div
                    key={notification.id}
                    className={`p-4 rounded-xl border transition-all ${
                      notification.unread
                        ? "border-primary/30 bg-primary/5"
                        : "border-border bg-card"
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div className={`w-2 h-2 rounded-full mt-2 ${notification.unread ? "bg-primary" : "bg-muted"}`} />
                      <div className="flex-1">
                        <p className="text-foreground">{notification.message}</p>
                        <p className="text-sm text-muted-foreground mt-1">{notification.time}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Quick Actions */}
        <div className="mt-8 flex gap-4">
          <Link to="/pharma-appointment" className="flex-1">
            <Button variant="outline" className="w-full h-12">
              <Plus className="w-4 h-4 mr-2" />
              Book New Appointment
            </Button>
          </Link>
          <Link to="/my-appointments" className="flex-1">
            <Button variant="outline" className="w-full h-12">
              <Calendar className="w-4 h-4 mr-2" />
              View All Appointments
            </Button>
          </Link>
        </div>
      </div>
    </div>
  );
};

export default PharmaDashboard;
