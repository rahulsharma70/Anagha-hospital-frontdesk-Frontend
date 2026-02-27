import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Heart, Calendar, User, Clock, MapPin, FileText, CheckCircle, XCircle, Filter } from "lucide-react";
import { appointmentsAPI, operationsAPI } from "@/lib/api";
import { getCurrentUser } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";

type AppointmentStatus = "pending" | "confirmed" | "completed" | "cancelled";
type UserType = "patient" | "pharma";

interface Appointment {
  id: string;
  doctorName: string;
  hospital: string;
  specialty?: string;
  date: string;
  time: string;
  type: string;
  status: AppointmentStatus;
  notes?: string;
}

const MyAppointments = () => {
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [userType, setUserType] = useState<UserType>("patient");
  const [statusFilter, setStatusFilter] = useState<AppointmentStatus | "all">("all");
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();
  const { toast } = useToast();

  useEffect(() => {
    const fetchAppointments = async () => {
      try {
        const currentUser = await getCurrentUser();
        if (!currentUser) {
          navigate("/login");
          return;
        }

        const role = currentUser.role?.toLowerCase() || "patient";
        setUserType(role === "pharma" ? "pharma" : "patient");

        // Fetch appointments and operations
        const [appts, ops] = await Promise.all([
          appointmentsAPI.getMyAppointments().catch(() => []),
          operationsAPI.getMyOperations().catch(() => [])
        ]);

        // Transform backend data to frontend format
        const transformedAppointments: Appointment[] = [];
        
        // Add appointments
        if (appts && Array.isArray(appts)) {
          appts.forEach((apt: any) => {
            transformedAppointments.push({
              id: apt.id.toString(),
              doctorName: apt.doctor_name || "Unknown Doctor",
              hospital: apt.hospital_name || "Unknown Hospital",
              specialty: apt.specialty,
              date: apt.date || "",
              time: apt.time_slot || "",
              type: "Consultation",
              status: apt.status || "pending",
              notes: apt.reason || apt.notes
            });
          });
        }

        // Add operations
        if (ops && Array.isArray(ops)) {
          ops.forEach((op: any) => {
            transformedAppointments.push({
              id: `op-${op.id}`,
              doctorName: op.doctor_name || "Unknown Doctor",
              hospital: op.hospital_name || "Unknown Hospital",
              specialty: op.specialty,
              date: op.date || op.operation_date || "", // Backend returns 'date' mapped from 'operation_date'
              time: "", // Operations don't have time slots, only dates
              type: "Operation",
              status: op.status || "pending",
              notes: op.notes || "" // Backend returns 'notes', not 'reason'
            });
          });
        }

        setAppointments(transformedAppointments);
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

    fetchAppointments();
  }, [navigate, toast]);

  const filteredAppointments = statusFilter === "all" 
    ? appointments 
    : appointments.filter((a) => a.status === statusFilter);

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
            <Link to={userType === "patient" ? "/book-appointment" : "/pharma-appointment"}>
              <Button variant="hero" size="sm">
                Book New Appointment
              </Button>
            </Link>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          {/* Page Header */}
          <div className="mb-8">
            <h1 className="text-2xl font-bold text-foreground mb-2">My Appointments</h1>
            <p className="text-muted-foreground">View and manage all your appointments</p>
          </div>

          {/* Filters */}
          <div className="flex flex-wrap gap-3 mb-6">
            <div className="flex items-center gap-2 text-muted-foreground">
              <Filter className="w-4 h-4" />
              <span className="text-sm font-medium">Filter:</span>
            </div>
            {["all", "pending", "confirmed", "completed", "cancelled"].map((status) => (
              <button
                key={status}
                onClick={() => setStatusFilter(status as AppointmentStatus | "all")}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                  statusFilter === status
                    ? "bg-primary text-primary-foreground"
                    : "bg-card border border-border text-muted-foreground hover:bg-muted"
                }`}
              >
                {status.charAt(0).toUpperCase() + status.slice(1)}
              </button>
            ))}
          </div>

          {/* Appointments List */}
          <div className="space-y-4">
            {loading ? (
              <div className="bg-card rounded-2xl border border-border p-12 text-center">
                <Calendar className="w-12 h-12 text-muted-foreground mx-auto mb-4 animate-pulse" />
                <p className="text-muted-foreground">Loading appointments...</p>
              </div>
            ) : filteredAppointments.length === 0 ? (
              <div className="bg-card rounded-2xl border border-border p-12 text-center">
                <Calendar className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
                <h3 className="text-lg font-semibold text-foreground mb-2">No appointments found</h3>
                <p className="text-muted-foreground mb-4">
                  {statusFilter === "all" 
                    ? "You don't have any appointments yet." 
                    : `No ${statusFilter} appointments.`}
                </p>
                <Link to={userType === "patient" ? "/book-appointment" : "/pharma-appointment"}>
                  <Button variant="hero">Book an Appointment</Button>
                </Link>
              </div>
            ) : (
              filteredAppointments.map((appointment) => (
                <div
                  key={appointment.id}
                  className="bg-card rounded-xl border border-border p-6 hover:shadow-card transition-shadow"
                >
                  <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div className="flex items-start gap-4">
                      <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                        <User className="w-6 h-6 text-primary" />
                      </div>
                      <div>
                        <h3 className="font-semibold text-foreground">{appointment.doctorName}</h3>
                        {appointment.specialty && (
                          <p className="text-sm text-primary">{appointment.specialty}</p>
                        )}
                        <div className="flex items-center gap-2 mt-1 text-sm text-muted-foreground">
                          <MapPin className="w-4 h-4" />
                          {appointment.hospital}
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-col items-start md:items-end gap-2">
                      <span className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(appointment.status)}`}>
                        {getStatusIcon(appointment.status)}
                        {appointment.status.charAt(0).toUpperCase() + appointment.status.slice(1)}
                      </span>
                      <div className="flex items-center gap-4 text-sm text-muted-foreground">
                        <div className="flex items-center gap-1">
                          <Calendar className="w-4 h-4" />
                          {appointment.date}
                        </div>
                        <div className="flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          {appointment.time}
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="mt-4 pt-4 border-t border-border flex flex-wrap items-center gap-4">
                    <span className="px-3 py-1 bg-secondary rounded-lg text-sm text-secondary-foreground">
                      {appointment.type}
                    </span>
                    {appointment.notes && (
                      <div className="flex items-center gap-2 text-sm text-muted-foreground">
                        <FileText className="w-4 h-4" />
                        {appointment.notes}
                      </div>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Back Link */}
          <p className="text-center mt-8">
            <Link to="/" className="text-muted-foreground hover:text-foreground transition-colors text-sm">
              ← Back to Home
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default MyAppointments;
