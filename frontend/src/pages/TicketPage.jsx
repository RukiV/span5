import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { apiClient } from "../services/api";
import "../styles/Ticket.css";

function TicketPage() {
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newTicket, setNewTicket] = useState({
    title: "",
    description: "",
    category: "",
    status: "open",
    priority: "medium",
  });

  useEffect(() => {
    fetchTickets();
  }, []);

  const fetchTickets = async () => {
    setLoading(true);
    try {
      const response = await apiClient.tickets.getAll();
      console.log("Tickets fetched:", response.data);
      setTickets(response.data);
    } catch (error) {
      console.error("Error fetching tickets:", error);
      alert("Fout by laai van foutkaartjies: " + (error.response?.data?.detail || error.message));
    } finally {
      setLoading(false);
    }
  };

  const handleAddTicket = async () => {
    try {
      if (!newTicket.title && !newTicket.description) {
        alert("Voer asseblief 'n titel of beskrywing vir die foutkaartjie in.");
        return;
      }

      const payload = {
        fault_description: newTicket.title
          ? `${newTicket.title}${newTicket.description ? `: ${newTicket.description}` : ''}`
          : newTicket.description,
        fault_type: newTicket.category && newTicket.category.trim() ? newTicket.category : null,
        fault_status: newTicket.status,
        fault_priority: newTicket.priority,
      };

      console.log("Payload being sent:", JSON.stringify(payload, null, 2));

      if (isEditing) {
        await apiClient.tickets.update(editingId, payload);
        alert("Foutkaartjie suksesvol opgedateer!");
      } else {
        await apiClient.tickets.create(payload);
        alert("Foutkaartjie suksesvol geskep!");
      }
      handleCloseModal();
      fetchTickets();
    } catch (error) {
      console.error("Error saving ticket:", error);
      console.error("Error response data:", error.response?.data);
      const errorDetail = error.response?.data?.detail;
      const errorMsg = Array.isArray(errorDetail) 
        ? errorDetail.map(e => `${e.loc?.join('.')}: ${e.msg}`).join('\n')
        : errorDetail || error.message;
      alert("Fout by besparing van foutkaartjie:\n" + errorMsg);
    }
  };

  const handleEditTicket = (ticket) => {
    setIsEditing(true);
    setEditingId(ticket.fault_id);
    const description = ticket.fault_description || "";
    const colonIndex = description.indexOf(":");
    const title = colonIndex > 0 ? description.substring(0, colonIndex).trim() : description;
    const details = colonIndex > 0 ? description.substring(colonIndex + 1).trim() : "";
    
    setNewTicket({
      title: title,
      description: details,
      category: ticket.fault_type || "",
      status: ticket.fault_status || "open",
      priority: ticket.fault_priority || "medium",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewTicket({ title: "", description: "", category: "", status: "open", priority: "medium" });
  };

  const handleNewTicket = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewTicket({ title: "", description: "", category: "", status: "open", priority: "medium" });
    setShowModal(true);
  };

  const handleDeleteTicket = async (ticketId) => {
    if (!window.confirm("Is jy seker jy wil hierdie foutkaartjie verwyder?")) {
      return;
    }
    try {
      await apiClient.tickets.delete(ticketId);
      fetchTickets();
    } catch (error) {
      console.error("Error deleting ticket:", error);
      alert("Fout tydens verwydering van foutkaartjie. Probeer asseblief weer.");
    }
  };

  const filteredTickets = tickets.filter((ticket) => {
    const query = searchTerm.toLowerCase();
    const description = ticket.fault_description || "";
    const matchesSearch =
      description.toLowerCase().includes(query) ||
      (ticket.fault_type || "").toLowerCase().includes(query);
    const matchesFilter = statusFilter === "" || ticket.fault_status === statusFilter;
    return matchesSearch && matchesFilter;
  });

  const getStatusClass = (status) => {
    switch (status) {
      case "wag":
        return "status-wait";
      case "open":
        return "status-open";
      case "bevestig":
        return "status-confirmed";
      case "besig":
        return "status-in-progress";
      case "opgelos":
        return "status-resolved";
      case "verwerp":
        return "status-closed";
      default:
        return "status-default";
    }
  };

  const translateCategory = (category) => {
    const translations = {
      maintenance: "Onderhoud",
      repair: "Herstel",
      upgrade: "Upgrade"
    };
    return translations[category] || category || "-";
  };

  const extractTitle = (faultDescription) => {
    if (!faultDescription) return "-";
    const parts = faultDescription.split(":");
    return parts[0].trim();
  };

  const translateStatus = (status) => {
    const translations = {
      wag: "Hangende",
      open: "Oop",
      bevestig: "Bevestig",
      besig: "Besig",
      opgelos: "Opgelost",
      verwerp: "Verwerp"
    };
    return translations[status] || status || "-";
  };

  const translatePriority = (priority) => {
    const translations = {
      low: "Laag",
      medium: "Medium",
      high: "Hoog"
    };
    return translations[priority] || priority || "-";
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
            <li><Link to="/work-orders">Werksopdragte</Link></li>
            <li><Link to="/fault-tickets" style={{ background: "#935e28" }}>Foutkaartjies</Link></li>  
          </ul>
          <div className="logout-container">
            <Link to="/login" className="btn-logout-sidebar">Logout</Link>
          </div>
        </div>
        <div className="main">
          <div className="navbar">
            <h3>Foutkaartjies Bestuur</h3>
            <div className="user">Admin</div>
          </div>
          <div className="content">Laai foutkaartjies...</div>
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
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/fault-tickets" style={{ background: "#935e28" }}>Foutkaartjies</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Foutkaartjies Bestuur</h3>
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
              <option value="wag">Wag</option>
              <option value="open">Oop</option>
              <option value="bevestig">Bevestig</option>
              <option value="besig">Besig</option>
              <option value="opgelos">Opgelost</option>
              <option value="verwerp">Verwerp</option>
            </select>
            <button className="btn-add" onClick={handleNewTicket}>+ Nuwe Foutkaartjie</button>
          </div>

          <table className="tickets-table">
            <thead>
              <tr>
                <th>ID Kaartjie</th>
                <th>Titel</th>
                <th>Kategorie</th>
                <th>Prioriteit</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredTickets.map((ticket) => (
                <tr key={ticket.fault_id}>
                  <td>{ticket.fault_id}</td>
                  <td>{extractTitle(ticket.fault_description)}</td>
                  <td>{translateCategory(ticket.fault_type)}</td>
                  <td>{translatePriority(ticket.fault_priority)}</td>
                  <td>
                    <span className={`status ${getStatusClass(ticket.fault_status)}`}>
                      {translateStatus(ticket.fault_status)}
                    </span>
                  </td>
                  <td>
                    <button className="btn-edit" onClick={() => handleEditTicket(ticket)}>
                      Wysig
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteTicket(ticket.fault_id)}>
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
              <h3>{isEditing ? "Wysig" : "Nuwe"} Foutkaartjie {!isEditing && "(ID Kaartjie sal outomaties gegenereer word)"}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Titel</label>
                <input
                  type="text"
                  value={newTicket.title}
                  onChange={(e) => setNewTicket({ ...newTicket, title: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Kategorie</label>
                <select
                  value={newTicket.category}
                  onChange={(e) => setNewTicket({ ...newTicket, category: e.target.value })}
                >
                  <option value="">Kies kategorie</option>
                  <option value="maintenance">Onderhoud</option>
                  <option value="repair">Herstel</option>
                  <option value="upgrade">Upgrade</option>
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Prioriteit</label>
                <select
                  value={newTicket.priority}
                  onChange={(e) => setNewTicket({ ...newTicket, priority: e.target.value })}
                >
                  <option value="low">Laag</option>
                  <option value="medium">Medium</option>
                  <option value="high">Hoog</option>
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Beskrywing</label>
                <textarea
                  value={newTicket.description}
                  onChange={(e) => setNewTicket({ ...newTicket, description: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Status</label>
                <select
                  value={newTicket.status}
                  onChange={(e) => setNewTicket({ ...newTicket, status: e.target.value })}
                >
                  <option value="wag">Wag</option>
                  <option value="open">Oop</option>
                  <option value="bevestig">Bevestig</option>
                  <option value="besig">Besig</option>
                  <option value="opgelos">Opgelost</option>
                  <option value="verwerp">Verwerp</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddTicket}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default TicketPage;