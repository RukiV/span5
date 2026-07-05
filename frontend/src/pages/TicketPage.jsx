import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { apiClient } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import "../styles/Ticket.css";
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';

function TicketPage() {
  // Haal admin-status vir beheer-opsies
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  
  // State vir foutkaartjies-lys
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");        // Soek op titel/beskrywing
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  
  // Modal en redigerings-state
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  
  // Vorm-data vir foutkaartjie
  const [newTicket, setNewTicket] = useState({
    title: "",                      // Hoofsaak/titel
    description: "",                // Volledige beskrywing
    category: "",                   // Fout-tipe (REPAIR, MAINTENANCE, etc.)
    status: "open",                 // Fout-status (open, wait, resolved)
    priority: "medium",             // Prioriteit (low, medium, high)
  });

  // Haal foutkaartjies wanneer blad laai
  useEffect(() => {
    fetchTickets();
  }, []);

  // Haal alle foutkaartjies van backend
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

  // Hanteer toevoeging van nuwe foutkaartjie of redigering van bestaande
  const handleAddTicket = async () => {
    try {
      // Valideer dat ten minste titel of beskrywing ingevul is
      if (!newTicket.title && !newTicket.description) {
        alert("Voer asseblief 'n titel of beskrywing vir die foutkaartjie in.");
        return;
      }

      // Bou data vir backend - kombineer titel en beskrywing
      const payload = {
        fault_description: newTicket.title
          ? `${newTicket.title}${newTicket.description ? `: ${newTicket.description}` : ''}`
          : newTicket.description,
        fault_type: newTicket.category && newTicket.category.trim() ? newTicket.category : null,
        fault_status: newTicket.status,
        fault_priority: newTicket.priority,
      };

      console.log("Payload being sent:", JSON.stringify(payload, null, 2));

      // Opdateer of skep nuwe kaartjie
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

  // Laai foutkaartjie-data in vorm vir redigering
  const handleEditTicket = (ticket) => {
    setIsEditing(true);
    setEditingId(ticket.fault_id);
    // Ontleed beskrywing om titel en details te skei
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

  // Sluit modal en stel vorm terug
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

  const filteredTickets = [...tickets]
    .filter((ticket) => {
      const query = searchTerm.trim().toLowerCase();
      const description = ticket.fault_description || "";
      if (!query) return true;
      const values = {
        id: ticket.fault_id,
        title: extractTitle(description),
        category: ticket.fault_type,
        priority: translatePriority(ticket.fault_priority),
        status: translateStatus(ticket.fault_status),
      };
      const matchesColumn = filterColumn === 'all'
        ? Object.values(values).some((value) => String(value || '').toLowerCase().includes(query))
        : String(values[filterColumn] || '').toLowerCase().includes(query);
      return matchesColumn;
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.fault_id || 0) - Number(b.fault_id || 0)) * direction;
      if (sortBy === 'title') return String(extractTitle(a.fault_description)).localeCompare(String(extractTitle(b.fault_description)), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'status') return String(translateStatus(a.fault_status)).localeCompare(String(translateStatus(b.fault_status)), 'af', { sensitivity: 'base' }) * direction;
      return 0;
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

  if (loading) {
    
  }

  return (
    <div style={{ display: "flex" }}>
      <Sidebar currentPath="/fault-tickets" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Foutkaartjies Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  placeholder="Soek..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="title">Titel</option>
                <option value="category">Kategorie</option>
                <option value="priority">Prioriteit</option>
                <option value="status">Status</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="id">ID</option>
                <option value="title">Titel</option>
                <option value="status">Status</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>
              <button className="btn-add" onClick={handleNewTicket}>+ Nuwe Foutkaartjie</button>
            </div>
          </div>

          <table className="standard-table">
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
              <button className="btn-add" onClick={handleAddTicket}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default TicketPage;