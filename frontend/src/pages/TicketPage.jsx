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
      setTickets(response.data);
    } catch (error) {
      console.error("Error fetching tickets:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddTicket = async () => {
    try {
      await apiClient.tickets.create(newTicket);
      setShowModal(false);
      setNewTicket({ title: "", description: "", category: "", status: "open", priority: "medium" });
      fetchTickets();
    } catch (error) {
      console.error("Error creating ticket:", error);
    }
  };

  const handleDeleteTicket = async (ticketId) => {
    try {
      await apiClient.tickets.delete(ticketId);
      fetchTickets();
    } catch (error) {
      console.error("Error deleting ticket:", error);
    }
  };

  const filteredTickets = tickets.filter((ticket) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      ticket.title.toLowerCase().includes(query) ||
      ticket.description.toLowerCase().includes(query);
    const matchesFilter = statusFilter === "" || ticket.status === statusFilter;
    return matchesSearch && matchesFilter;
  });

  const getStatusClass = (status) => {
    switch (status) {
      case "open":
        return "status-open";
      case "in_progress":
        return "status-in-progress";
      case "resolved":
        return "status-resolved";
      case "closed":
        return "status-closed";
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
              <option value="open">Oop</option>
              <option value="in_progress">In Progress</option>
              <option value="resolved">Opgelost</option>
              <option value="closed">Gesluit</option>
            </select>
            <button className="btn-add" onClick={() => setShowModal(true)}>+ Nuwe Foutkaartjie</button>
          </div>

          <table className="tickets-table">
            <thead>
              <tr>
                <th>ID Kaartjie</th>
                <th>Titel</th>
                <th>Beskrywing</th>
                <th>Kategorie</th>
                <th>Prioriteit</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredTickets.map((ticket) => (
                <tr key={ticket.id}>
                  <td>{ticket.id}</td>
                  <td>{ticket.title}</td>
                  <td>{ticket.description}</td>
                  <td>{ticket.category || '-'}</td>
                  <td>{ticket.priority}</td>
                  <td>
                    <span className={`status ${getStatusClass(ticket.status)}`}>
                      {ticket.status}
                    </span>
                  </td>
                  <td>
                    <button className="btn-delete" onClick={() => handleDeleteTicket(ticket.id)}>
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
              <h3>Nuwe Foutkaartjie (ID Kaartjie sal outomaties gegenereer word)</h3>
              <span className="close" onClick={() => setShowModal(false)}>&times;</span>
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
                <input
                  type="text"
                  value={newTicket.category}
                  onChange={(e) => setNewTicket({ ...newTicket, category: e.target.value })}
                  placeholder="bv. Elektries, Klemplerij, ens"
                />
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
                  <option value="urgent">Dringend</option>
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
                  <option value="open">Oop</option>
                  <option value="in_progress">In Progress</option>
                  <option value="resolved">Opgelost</option>
                  <option value="closed">Gesluit</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={() => setShowModal(false)}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddTicket}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default TicketPage;