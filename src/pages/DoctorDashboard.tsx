import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Heart, Calendar, Users, Bell, Clock, CheckCircle, XCircle, User, Phone, FileText, ChevronRight, LogOut } from "lucide-react";
import { appointmentsAPI, operationsAPI, authAPI } from "@/lib/api";
import { getCurrentUser, logout } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";

type AppointmentStatus = "pending" | "confirmed" | "completed" | "cancelled" | "visited";

interface Appointment {
  id: number;
  user_name: string;
  user_id: number;
  doctor_id: number;
  hospital_id: number;
  hospital_name: string;
  date: string;
  time_slot: string;
  status: AppointmentStatus;
  reason?: string;
  created_at: string;
}

interface Operation {
  id: number;
  patient_name: string;
  patient_id: number;
  doctor_id: number;
  hospital_id: number;
  hospital_name: string;
  specialty: string;
  date: string;
  operation_date: string;
  status: AppointmentStatus;
  notes?: string;
  created_at: string;
}

interface DoctorUser {
  id: number;
  name: string;
  mobile: string;
  role: string;
  degree?: string;
  institute_name?: string;
  hospital_id?: number;
}

const DoctorDashboard = () => {
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [operations, setOperations] = useState<Operation[]>([]);
  const [activeTab, setActiveTab] = useState<"appointments" | "patients">("appointments");
  const [currentUser, setCurrentUser] = useState<DoctorUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const { toast } = useToast();
  const navigate = useNavigate();

  // Fetch all data on component mount
  useEffect(() => {
    const fetchData = async () => {
      try {
        setIsLoading(true);
        
        // Get current user
        const user = await getCurrentUser();
        if (!user || user.role !== "doctor") {
          toast({
            title: "Access Denied",
            description: "You must be a doctor to access this dashboard.",
            variant: "destructive",
          });
          navigate("/login");
          return;
        }
        setCurrentUser(user as DoctorUser);

        // Fetch appointments and operations in parallel
        const [appointmentsData, operationsData] = await Promise.all([
          appointmentsAPI.getDoctorAppointments().catch(() => []),
          operationsAPI.getDoctorOperations().catch(() => []),
        ]);

        setAppointments(appointmentsData || []);
        setOperations(operationsData || []);
      } catch (error: any) {
        console.error("Error fetching dashboard data:", error);
        toast({
          title: "Error",
          description: error.message || "Failed to load dashboard data",
          variant: "destructive",
        });
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, [toast, navigate]);

  // Calculate stats
  const today = new Date().toISOString().split('T')[0];
  const todayAppointments = appointments.filter(a => a.date === today);
  const todayOperations = operations.filter(o => o.date === today); // Backend returns 'date' (mapped from 'operation_date')
  const pendingAppointments = appointments.filter(a => a.status === "pending");
  const pendingOperations = operations.filter(o => o.status === "pending");
  const pendingCount = pendingAppointments.length + pendingOperations.length;
  const completedToday = [
    ...appointments.filter(a => a.date === today && (a.status === "completed" || a.status === "visited")),
    ...operations.filter(o => o.date === today && o.status === "completed") // Backend returns 'date'
  ].length;

  // Get unique patients from appointments and operations
  const uniquePatients = new Map<number, {
    id: number;
    name: string;
    phone: string;
    lastVisit: string;
    totalVisits: number;
    conditions: string[];
  }>();

  appointments.forEach(apt => {
    if (!uniquePatients.has(apt.user_id)) {
      uniquePatients.set(apt.user_id, {
        id: apt.user_id,
        name: apt.user_name,
        phone: "", // Will be filled from operations if available
        lastVisit: apt.date,
        totalVisits: 1,
        conditions: [],
      });
    } else {
      const patient = uniquePatients.get(apt.user_id)!;
      patient.totalVisits++;
      if (apt.date > patient.lastVisit) {
        patient.lastVisit = apt.date;
      }
    }
  });

  operations.forEach(op => {
    if (!uniquePatients.has(op.patient_id)) {
      uniquePatients.set(op.patient_id, {
        id: op.patient_id,
        name: op.patient_name,
        phone: "",
        lastVisit: op.date || "", // Backend returns 'date' (mapped from 'operation_date')
        totalVisits: 1,
        conditions: [op.specialty],
      });
    } else {
      const patient = uniquePatients.get(op.patient_id)!;
      patient.totalVisits++;
      if ((op.operation_date || op.date) > patient.lastVisit) {
        patient.lastVisit = op.operation_date || op.date;
      }
      if (!patient.conditions.includes(op.specialty)) {
        patient.conditions.push(op.specialty);
      }
    }
  });

  const patientsList = Array.from(uniquePatients.values());

  const handleAppointmentStatusChange = async (id: number, newStatus: AppointmentStatus) => {
    try {
      if (newStatus === "confirmed") {
        await appointmentsAPI.confirm(id);
        toast({
          title: "Success",
          description: "Appointment confirmed",
        });
      } else if (newStatus === "cancelled") {
        await appointmentsAPI.cancel(id);
        toast({
          title: "Success",
          description: "Appointment cancelled",
        });
      } else if (newStatus === "completed") {
        // Mark as visited (which sets status to completed)
        await appointmentsAPI.markVisited(id);
        toast({
          title: "Success",
          description: "Appointment marked as completed",
        });
      }

      // Refresh appointments
      const updatedAppointments = await appointmentsAPI.getDoctorAppointments();
      setAppointments(updatedAppointments || []);
    } catch (error: any) {
      console.error("Error updating appointment:", error);
      toast({
        title: "Error",
        description: error.message || "Failed to update appointment",
        variant: "destructive",
      });
    }
  };

  const handleOperationStatusChange = async (id: number, newStatus: AppointmentStatus) => {
    try {
      if (newStatus === "confirmed") {
        await operationsAPI.confirm(id);
        toast({
          title: "Success",
          description: "Operation confirmed",
        });
      } else if (newStatus === "cancelled") {
        await operationsAPI.cancel(id);
        toast({
          title: "Success",
          description: "Operation cancelled",
        });
      }

      // Refresh operations
      const updatedOperations = await operationsAPI.getDoctorOperations();
      setOperations(updatedOperations || []);
    } catch (error: any) {
      console.error("Error updating operation:", error);
      toast({
        title: "Error",
        description: error.message || "Failed to update operation",
        variant: "destructive",
      });
    }
  };

  const handleLogout = () => {
    logout();
  };

  const getStatusColor = (status: AppointmentStatus) => {
    switch (status) {
      case "pending": return "bg-amber-100 text-amber-700";
      case "confirmed": return "bg-blue-100 text-blue-700";
      case "completed": return "bg-green-100 text-green-700";
      case "visited": return "bg-green-100 text-green-700";
      case "cancelled": return "bg-red-100 text-red-700";
    }
  };

  const getTypeColor = (type: string) => {
    switch (type) {
      case "appointment": return "bg-primary/10 text-primary";
      case "operation": return "bg-accent/10 text-accent";
      default: return "bg-muted text-muted-foreground";
    }
  };

  // Combine appointments and operations for display
  const allItems = [
    ...appointments.map(apt => ({
      id: apt.id,
      type: "appointment" as const,
      patientName: apt.user_name || "Unknown Patient",
      phone: "", // Phone not in appointment response
      date: apt.date || "",
      time: apt.time_slot || "",
      status: apt.status || "pending",
      notes: apt.reason || "", // Backend doesn't always include reason in list endpoints
      hospital: apt.hospital_name || "Unknown Hospital",
    })),
    ...operations.map(op => ({
      id: op.id,
      type: "operation" as const,
      patientName: op.patient_name,
      phone: "",
      date: op.date || "", // Backend returns 'date' (mapped from 'operation_date')
      time: "", // Operations don't have time slots
      status: op.status,
      notes: op.notes || "", // Backend returns 'notes'
      specialty: op.specialty,
      hospital: op.hospital_name || "Unknown Hospital",
    })),
  ].sort((a, b) => {
    // Sort by date, then by time
    if (a.date !== b.date) {
      return a.date.localeCompare(b.date);
    }
    return a.time.localeCompare(b.time);
  });

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-muted-foreground">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card border-b border-border sticky top-0 z-10">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-gradient-hero flex items-center justify-center shadow-soft">
              <Heart className="w-5 h-5 text-primary-foreground" />
            </div>
            <span className="font-bold text-xl text-foreground">Anagha Health</span>
          </Link>
          
          <div className="flex items-center gap-4">
            {/* Notifications */}
            <button className="relative p-2 rounded-full hover:bg-muted transition-colors">
              <Bell className="w-5 h-5 text-muted-foreground" />
              {pendingCount > 0 && (
                <span className="absolute top-0 right-0 w-5 h-5 bg-accent text-accent-foreground text-xs rounded-full flex items-center justify-center">
                  {pendingCount}
                </span>
              )}
            </button>
            
            {/* Profile */}
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-gradient-hero flex items-center justify-center text-primary-foreground font-bold">
                {currentUser?.name?.split(" ").map(n => n[0]).join("").slice(0, 2).toUpperCase() || "DR"}
              </div>
              <div className="hidden sm:block">
                <p className="text-sm font-medium text-foreground">
                  {currentUser?.name || "Doctor"}
                  {currentUser?.degree && ` (${currentUser.degree})`}
                </p>
                <p className="text-xs text-muted-foreground">
                  {currentUser?.institute_name || "General Medicine"}
                </p>
              </div>
            </div>

            <Button variant="ghost" size="icon" onClick={handleLogout}>
                <LogOut className="w-5 h-5" />
              </Button>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Stats Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <div className="bg-card rounded-xl border border-border p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                <Calendar className="w-6 h-6 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{todayAppointments.length + todayOperations.length}</p>
                <p className="text-sm text-muted-foreground">Today's Schedule</p>
              </div>
            </div>
          </div>
          
          <div className="bg-card rounded-xl border border-border p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center">
                <Bell className="w-6 h-6 text-amber-600" />
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{pendingCount}</p>
                <p className="text-sm text-muted-foreground">Pending Requests</p>
              </div>
            </div>
          </div>
          
          <div className="bg-card rounded-xl border border-border p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-green-100 flex items-center justify-center">
                <Users className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{patientsList.length}</p>
                <p className="text-sm text-muted-foreground">Total Patients</p>
              </div>
            </div>
          </div>
          
          <div className="bg-card rounded-xl border border-border p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center">
                <CheckCircle className="w-6 h-6 text-accent" />
              </div>
              <div>
                <p className="text-2xl font-bold text-foreground">{completedToday}</p>
                <p className="text-sm text-muted-foreground">Completed Today</p>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 mb-6">
          <button
            onClick={() => setActiveTab("appointments")}
            className={`px-6 py-3 rounded-lg font-medium transition-all ${
              activeTab === "appointments"
                ? "bg-primary text-primary-foreground"
                : "bg-card text-muted-foreground hover:bg-muted"
            }`}
          >
            <Calendar className="w-4 h-4 inline-block mr-2" />
            Appointments & Operations
          </button>
          <button
            onClick={() => setActiveTab("patients")}
            className={`px-6 py-3 rounded-lg font-medium transition-all ${
              activeTab === "patients"
                ? "bg-primary text-primary-foreground"
                : "bg-card text-muted-foreground hover:bg-muted"
            }`}
          >
            <Users className="w-4 h-4 inline-block mr-2" />
            Patient History
          </button>
        </div>

        {/* Content */}
        {activeTab === "appointments" && (
          <div className="space-y-4">
            <h2 className="text-xl font-bold text-foreground">Upcoming Appointments & Operations</h2>
            
            {allItems.length === 0 ? (
              <div className="bg-card rounded-xl border border-border p-12 text-center">
                <Calendar className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
                <p className="text-muted-foreground">No appointments or operations scheduled</p>
              </div>
            ) : (
              <div className="space-y-3">
                {allItems.map((item) => (
                  <div key={`${item.type}-${item.id}`} className="bg-card rounded-xl border border-border p-6 hover:shadow-card transition-shadow">
                    <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                      <div className="flex items-start gap-4">
                        <div className="w-12 h-12 rounded-full bg-muted flex items-center justify-center text-foreground font-bold">
                          {item.patientName.split(" ").map(n => n[0]).join("").slice(0, 2)}
                        </div>
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <h3 className="font-semibold text-foreground">{item.patientName}</h3>
                            <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${getTypeColor(item.type)}`}>
                              {item.type === "operation" ? `${item.specialty || "Operation"}` : "Appointment"}
                            </span>
                            {item.hospital && (
                              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-secondary text-secondary-foreground">
                                {item.hospital}
                              </span>
                            )}
                          </div>
                          <div className="flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
                            <span className="flex items-center gap-1">
                              <Calendar className="w-4 h-4" />
                              {item.date}
                            </span>
                            {item.time && (
                            <span className="flex items-center gap-1">
                              <Clock className="w-4 h-4" />
                                {item.time}
                            </span>
                            )}
                          </div>
                          {item.notes && (
                            <p className="text-sm text-muted-foreground mt-2 flex items-start gap-1">
                              <FileText className="w-4 h-4 mt-0.5 flex-shrink-0" />
                              {item.notes}
                            </p>
                          )}
                        </div>
                      </div>
                      
                      <div className="flex items-center gap-2">
                        <span className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(item.status)}`}>
                          {item.status}
                        </span>
                        
                        {item.status === "pending" && (
                          <>
                            <Button
                              size="sm"
                              variant="outline"
                              className="text-green-600 border-green-200 hover:bg-green-50"
                              onClick={() => {
                                if (item.type === "appointment") {
                                  handleAppointmentStatusChange(item.id, "confirmed");
                                } else {
                                  handleOperationStatusChange(item.id, "confirmed");
                                }
                              }}
                            >
                              <CheckCircle className="w-4 h-4 mr-1" />
                              Accept
                            </Button>
                            <Button
                              size="sm"
                              variant="outline"
                              className="text-red-600 border-red-200 hover:bg-red-50"
                              onClick={() => {
                                if (item.type === "appointment") {
                                  handleAppointmentStatusChange(item.id, "cancelled");
                                } else {
                                  handleOperationStatusChange(item.id, "cancelled");
                                }
                              }}
                            >
                              <XCircle className="w-4 h-4 mr-1" />
                              Decline
                            </Button>
                          </>
                        )}
                        
                        {item.status === "confirmed" && item.type === "appointment" && (
                          <Button
                            size="sm"
                            variant="default"
                            onClick={() => handleAppointmentStatusChange(item.id, "completed")}
                          >
                            Mark Complete
                          </Button>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === "patients" && (
          <div className="space-y-4">
            <h2 className="text-xl font-bold text-foreground">Patient History</h2>
            
            {patientsList.length === 0 ? (
              <div className="bg-card rounded-xl border border-border p-12 text-center">
                <Users className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
                <p className="text-muted-foreground">No patients found</p>
              </div>
            ) : (
            <div className="bg-card rounded-xl border border-border overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-border bg-muted/50">
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">Patient</th>
                        <th className="text-left p-4 text-sm font-medium text-muted-foreground">Conditions</th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">Last Visit</th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">Total Visits</th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground"></th>
                    </tr>
                  </thead>
                  <tbody>
                      {patientsList.map((patient) => (
                      <tr key={patient.id} className="border-b border-border hover:bg-muted/30 transition-colors">
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm">
                              {patient.name.split(" ").map(n => n[0]).join("")}
                            </div>
                            <span className="font-medium text-foreground">{patient.name}</span>
                          </div>
                        </td>
                        <td className="p-4">
                            <div className="flex flex-wrap gap-1">
                              {patient.conditions.length > 0 ? (
                                patient.conditions.map((condition, idx) => (
                                  <span key={idx} className="px-2 py-1 rounded-full text-xs font-medium bg-secondary text-secondary-foreground">
                                    {condition}
                          </span>
                                ))
                              ) : (
                                <span className="text-muted-foreground text-sm">General</span>
                              )}
                            </div>
                        </td>
                        <td className="p-4 text-muted-foreground">{patient.lastVisit}</td>
                        <td className="p-4 text-foreground font-medium">{patient.totalVisits}</td>
                        <td className="p-4">
                          <Button variant="ghost" size="sm">
                            <ChevronRight className="w-4 h-4" />
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default DoctorDashboard;
