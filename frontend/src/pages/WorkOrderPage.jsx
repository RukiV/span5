import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { apiClient } from "../services/api";
import "../styles/WorkOrder.css";

function WorkOrderPage() {
  const [workOrders, setWorkOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [newWorkOrder, setNewWorkOrder] = useState({
    title: "",
    description: "",
    work_type: "",
    scheduled_date: "",
    status: "pending",
    priority: "medium",
  });

  useEffect(() => {
    fetchWorkOrders();
  }, []);

  const fetchWorkOrders = async () => {
    setLoading(true);
    try {
      const response = await apiClient.workOrders.getAll();
      setWorkOrders(response.data);
    } catch (error) {
      console.error("Error fetching work orders:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddWorkOrder = async () => {
    try {
      await apiClient.workOrders.create(newWorkOrder);
      setShowModal(false);
      setNewWorkOrder({ title: "", description: "", work_type: "", scheduled_date: "", status: "pending", priority: "medium" });
      fetchWorkOrders();
    } catch (error) {
      console.error("Error creating work order:", error);
    }
  };

  const handleDeleteWorkOrder = async (workOrderId) => {
    try {
      await apiClient.workOrders.delete(workOrderId);
      fetchWorkOrders();
    } catch (error) {
      console.error("Error deleting work order:", error);
    }
  };

  const filteredWorkOrders = workOrders.filter((order) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      order.title.toLowerCase().includes(query) ||
      order.description.toLowerCase().includes(query);
    const matchesFilter = statusFilter === "" || order.status === statusFilter;
    return matchesSearch && matchesFilter;
  });

  const getStatusClass = (status) => {
    switch (status) {
      case "pending":
        return "status-pending";
      case "in_progress":
        return "status-in-progress";
      case "completed":
        return "status-completed";
      case "cancelled":
        return "status-cancelled";
      default:
        return "status-default";
    }
  };

  if (loading) {
    return (
      <div style={{ display: "flex" }}>
        <div className="sidebar">
          <h2>FBS</h2>
          <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li><Link to="/assets">Bates</Link></li>
            <li><Link to="/rooms">Lokale</Link></li>
            <li><Link to="/work-orders" style={{ background: "#935e28" }}>Werksopdragte</Link></li>
            <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          </ul>
          <div className="logout-container">
            <Link to="/login" className="btn-logout-sidebar">Logout</Link>
          </div>
        </div>
        <div className="main">
          <div className="navbar">
            <h3>Werksopdragte Bestuur</h3>
            <div className="user">Admin</div>
          </div>
          <div className="content">Laai werksopdragte...</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/work-orders" style={{ background: "#935e28" }}>Werksopdragte</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>
      <div className="main">
        <div className="navbar">
          <h3>Werksopdragte Bestuur</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="controls">
            <input
              type="text"
              placeholder="Soek..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="">Filter: Alle</option>
              <option value="pending">Hangende</option>
              <option value="in_progress">In Progress</option>
              <option value="completed">Voltooi</option>
              <option value="cancelled">Gekanselleer</option>
            </select>
            <button className="btn-add" onClick={() => setShowModal(true)}>+ Nuwe Werksopdrag</button>
          </div>

          <table className="work-orders-table">
            <thead>
              <tr>
                <th>ID Werksopdrag</th>
                <th>Titel</th>
                <th>Werksoort</th>
                <th>Prioriteit</th>
                <th>Geskeduleerde Datum</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredWorkOrders.map((order) => (
                <tr key={order.id}>
                  <td>{order.id}</td>
                  <td>{order.title}</td>
                  <td>{order.work_type || '-'}</td>
                  <td>{order.priority}</td>
                  <td>{order.scheduled_date ? new Date(order.scheduled_date).toLocaleDateString('af-ZA') : '-'}</td>
                  <td>
                    <span className={`status ${getStatusClass(order.status)}`}>
                      {order.status}
                    </span>
                  </td>
                  <td>
                    <button className="btn-delete" onClick={() => handleDeleteWorkOrder(order.id)}>
                      Verwyder
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Nuwe Werksopdrag (ID Werksopdrag sal outomaties gegenereer word)</h3>
              <span className="close" onClick={() => setShowModal(false)}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Titel</label>
                <input
                  type="text"
                  value={newWorkOrder.title}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, title: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Werksoort</label>
                <select
                  value={newWorkOrder.work_type}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, work_type: e.target.value })}
                >
                  <option value="">Kies werksoort</option>
                  <option value="maintenance">Onderhoud</option>
                  <option value="repair">Herstel</option>
                  <option value="installation">Installasie</option>
                  <option value="inspection">Inspeksie</option>
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Prioriteit</label>
                <select
                  value={newWorkOrder.priority}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, priority: e.target.value })}
                >
                  <option value="low">Laag</option>
                  <option value="medium">Medium</option>
                  <option value="high">Hoog</option>
                  <option value="urgent">Dringend</option>
                </select>
              </div>
              <div className="input-group">
                <label>Geskeduleerde Datum</label>
                <input
                  type="datetime-local"
                  value={newWorkOrder.scheduled_date}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, scheduled_date: e.target.value })}
                />
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Beschrywing</label>
                <textarea
                  value={newWorkOrder.description}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, description: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Status</label>
                <select
                  value={newWorkOrder.status}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, status: e.target.value })}
                >
                  <option value="pending">Hangende</option>
                  <option value="in_progress">In Progress</option>
                  <option value="completed">Voltooi</option>
                  <option value="cancelled">Gekanselleer</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={() => setShowModal(false)}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddWorkOrder}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default WorkOrderPage;