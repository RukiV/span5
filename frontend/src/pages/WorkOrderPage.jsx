import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, workOrdersAPI, apiClient } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/WorkOrder.css";

function WorkOrderPage() {
  const { isAdmin } = useCurrentUser();
  const [workOrders, setWorkOrders] = useState([]);
  const [assets, setAssets] = useState([]);
  const [faultTickets, setFaultTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newWorkOrder, setNewWorkOrder] = useState({
    title: "",
    description: "",
    work_type: "",
    scheduled_date: "",
    status: "wag",
    priority: "medium",
    asset_id: "",
    fault_id: "",
  });

  useEffect(() => {
    fetchWorkOrders();
    fetchAssets();
    fetchFaultTickets();
  }, []);

  const fetchWorkOrders = async () => {
    setLoading(true);
    try {
      const response = await workOrdersAPI.getAll();
      setWorkOrders(response.data);
    } catch (error) {
      console.error("Error fetching work orders:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data);
    } catch (error) {
      console.error("Error fetching assets:", error);
    }
  };

  const fetchFaultTickets = async () => {
    try {
      const response = await apiClient.tickets.getAll();
      setFaultTickets(response.data);
    } catch (error) {
      console.error("Error fetching fault tickets:", error);
    }
  };

  const handleAddWorkOrder = async () => {
    try {
      if (!newWorkOrder.title && !newWorkOrder.description) {
        alert("Voer asseblief 'n titel of beskrywing vir die werksopdrag in.");
        return;
      }

      const payload = {
        job_desc: newWorkOrder.title
          ? `${newWorkOrder.title}${newWorkOrder.description ? `: ${newWorkOrder.description}` : ''}`
          : newWorkOrder.description,
        job_type: newWorkOrder.work_type || null,
        job_status: newWorkOrder.status,
        job_createddatetime: newWorkOrder.scheduled_date || null,
        asset_id: newWorkOrder.asset_id ? Number(newWorkOrder.asset_id) : null,
        fault_id: newWorkOrder.fault_id ? Number(newWorkOrder.fault_id) : null,
      };

      if (isEditing) {
        await workOrdersAPI.update(editingId, payload);
      } else {
        await workOrdersAPI.create(payload);
      }
      handleCloseModal();
      fetchWorkOrders();
    } catch (error) {
      console.error("Error saving work order:", error);
      alert("Fout tydens besparing van werksopdrag. Probeer asseblief weer.");
    }
  };

  const handleEditWorkOrder = (order) => {
    setIsEditing(true);
    setEditingId(order.jobcard_id);
    const description = order.job_desc || "";
    const colonIndex = description.indexOf(":");
    const title = colonIndex > 0 ? description.substring(0, colonIndex).trim() : description;
    const details = colonIndex > 0 ? description.substring(colonIndex + 1).trim() : "";
    
    setNewWorkOrder({
      title: title,
      description: details,
      work_type: order.job_type || "",
      scheduled_date: order.job_createddatetime || "",
      status: order.job_status || "wag",
      priority: "medium",
      asset_id: order.asset_id || "",
      fault_id: order.fault_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewWorkOrder({ title: "", description: "", work_type: "", scheduled_date: "", status: "wag", priority: "medium", asset_id: "", fault_id: "" });
  };

  const handleNewWorkOrder = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewWorkOrder({ title: "", description: "", work_type: "", scheduled_date: "", status: "wag", priority: "medium", asset_id: "", fault_id: "" });
    setShowModal(true);
  };

  const handleDeleteWorkOrder = async (workOrderId) => {
    if (!window.confirm("Is jy seker jy wil hierdie werksopdrag verwyder?")) {
      return;
    }
    try {
      await workOrdersAPI.delete(workOrderId);
      fetchWorkOrders();
    } catch (error) {
      console.error("Error deleting work order:", error);
      alert("Fout tydens verwydering van werksopdrag. Probeer asseblief weer.");
    }
  };

  const filteredWorkOrders = workOrders.filter((order) => {
    const query = searchTerm.toLowerCase();
    const description = order.job_desc || "";
    const matchesSearch =
      description.toLowerCase().includes(query) ||
      (order.job_type || "").toLowerCase().includes(query) ||
      String(order.asset_id || "").includes(query);
    const matchesFilter = statusFilter === "" || order.job_status === statusFilter;
    return matchesSearch && matchesFilter;
  });

  const getStatusClass = (status) => {
    switch (status) {
      case "wag":
        return "status-pending";
      case "open":
        return "status-in-progress";
      case "besig":
        return "status-in-progress";
      case "voltooid":
        return "status-completed";
      case "geannuleerd":
        return "status-cancelled";
      default:
        return "status-default";
    }
  };

  const translateWorkType = (workType) => {
    const translations = {
      maintenance: "Onderhoud",
      repair: "Herstel",
      inspection: "Inspeksie",
      installation: "Installasie"
    };
    return translations[workType] || workType || "-";
  };

  const extractTitle = (jobDesc) => {
    if (!jobDesc) return "-";
    const parts = jobDesc.split(":");
    return parts[0].trim();
  };

  const translateStatus = (status) => {
    const translations = {
      wag: "Hangende",
      open: "Oop",
      besig: "Besig",
      voltooid: "Voltooi",
      geannuleerd: "Gekanselleer"
    };
    return translations[status] || status || "-";
  };

  if (loading) {
    
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders"style={{ background: "#935e28" }}>Werksopdragte</Link></li>
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
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
              <option value="wag">Hangende</option>
              <option value="open">Oop</option>
              <option value="besig">Besig</option>
              <option value="voltooid">Voltooi</option>
              <option value="geannuleerd">Gekanselleer</option>
            </select>
            <button className="btn-add" onClick={handleNewWorkOrder}>+ Nuwe Werksopdrag</button>
          </div>

          <table className="work-orders-table">
            <thead>
              <tr>
                <th>ID Werksopdrag</th>
                <th>Titel</th>
                <th>Bate ID</th>
                <th>Werksoort</th>
                <th>Foutkaartjie</th>
                <th>Geskeduleerde Datum</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredWorkOrders.map((order) => {
                const faultTicket = faultTickets.find(t => t.fault_id === order.fault_id);
                return (
                <tr key={order.jobcard_id}>
                  <td>{order.jobcard_id}</td>
                  <td>{extractTitle(order.job_desc)}</td>
                  <td>{order.asset_id ?? '-'}</td>
                  <td>{translateWorkType(order.job_type)}</td>
                  <td>{faultTicket ? `${faultTicket.fault_id}: ${extractTitle(faultTicket.fault_description)}` : '-'}</td>
                  <td>{order.job_createddatetime ? new Date(order.job_createddatetime).toLocaleString('af-ZA') : '-'}</td>
                  <td>
                    <span className={`status ${getStatusClass(order.job_status)}`}>
                      {translateStatus(order.job_status)}
                    </span>
                  </td>
                  <td>
                    <button className="btn-edit" onClick={() => handleEditWorkOrder(order)}>
                      Wysig
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteWorkOrder(order.jobcard_id)}>
                      Verwyder
                    </button>
                  </td>
                </tr>
              );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} Werksopdrag {!isEditing && "(ID Werksopdrag sal outomaties gegenereer word)"}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
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
              <div className="input-group">
                <label>Asset</label>
                <select
                  value={newWorkOrder.asset_id}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, asset_id: e.target.value })}
                >
                  <option value="">Geen asset gekies</option>
                  {assets.map((asset) => (
                    <option key={asset.asset_id} value={asset.asset_id}>
                      {asset.asset_id} - {asset.asset_name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="input-group">
                <label>Foutkaartjie</label>
                <select
                  value={newWorkOrder.fault_id}
                  onChange={(e) => setNewWorkOrder({ ...newWorkOrder, fault_id: e.target.value })}
                >
                  <option value="">Geen foutkaartjie gekies</option>
                  {faultTickets.map((ticket) => (
                    <option key={ticket.fault_id} value={ticket.fault_id}>
                      {ticket.fault_id} - {ticket.fault_description}
                    </option>
                  ))}
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
                <label>Beskrywing</label>
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
                  <option value="wag">Hangende</option>
                  <option value="open">Oop</option>
                  <option value="besig">Besig</option>
                  <option value="voltooid">Voltooi</option>
                  <option value="geannuleerd">Gekanselleer</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddWorkOrder}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default WorkOrderPage;