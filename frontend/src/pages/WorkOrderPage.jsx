import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, workOrdersAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/WorkOrder.css";

function WorkOrderPage() {
  // Haal admin-status vir beheer-opsies
  const { isAdmin } = useCurrentUser();
  
  // State vir werksopdragte-lys
  const [workOrders, setWorkOrders] = useState([]);
  const [assets, setAssets] = useState([]);               // Bates vir toekenning
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");        // Soek op ID/Beskrywing
  const [statusFilter, setStatusFilter] = useState("");    // Filter op status
  const [sortBy, setSortBy] = useState("id");              // Sorteer op veld
  
  // Modal en redigerings-state
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [quotes, setQuotes] = useState([]);
  const [selectedQuoteId, setSelectedQuoteId] = useState(null);
  const [newQuote, setNewQuote] = useState({ supplier: "", amount: "", description: "" });
  
  // Vorm-data vir werksopdrag (uitgebreide velde)
  const [formData, setFormData] = useState({
    // Hoofinligting
    job_desc: "",                   // Hoofbeskrywing
    job_type: "",                   // Werksoort (maintenance, repair, inspection, installation, emergency)
    job_status: "OPEN",             // Status (OPEN, WAIT, COMPLETED)
    job_priority: "Normal",         // Prioriteit
    job_createddatetime: "",        // Skeppingsdatum
    
    // Aanspreekpunt-inligting
    contact_name: "",               // Naam van persoon
    contact_email: "",              // E-pos
    contact_phone: "",              // Telefoonnommer
    
    // Asset en Lokasie
    asset_id: "",                   // Bate-ID
    room_id: "",                    // Kamer/Lokasie
    
    // Werk-inligting
    nature: "",                     // Aard van werk
    brief_description: "",          // Kort Beskrywing
    job_notes: "",                  // Gedetailleerde aantekeninge
    
    // Voltooiings-inligting
    authorized_by: "",              // Goedgekeur deur
    completed_date: "",             // Voltooide datum
    cost_recovery_notes: "",        // Kostetoerekening-aantekeninge
  });

  // Haal almal data wanneer blad laai
  useEffect(() => {
    fetchWorkOrders();
    fetchAssets();
  }, []);

  // Haal werksopdragte-lys van backend
  const fetchWorkOrders = async () => {
    setLoading(true);
    try {
      const response = await workOrdersAPI.getAll();
      setWorkOrders(response.data);
    } catch (error) {
      console.error("Fout by haal werksopdragte:", error);
    } finally {
      setLoading(false);
    }
  };

  // Haal bates-lys vir dropdown-keuse
  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data);
    } catch (error) {
      console.error("Fout by haal bates:", error);
    }
  };

  // Hulpfunksie: Formateer datetime na date-only (YYYY-MM-DD)
  const formatDateForInput = (dateString) => {
    if (!dateString) return "";
    // Haal net die datum-deel uit (eerste 10 karakters: YYYY-MM-DD)
    return dateString.split('T')[0];
  };

  // Hanteer redigering van werksopdrag
  function handleEditWorkOrder(order) {
    setIsEditing(true);
    setEditingId(order.jobcard_id);

    // Ontleed beskrywing
    const description = order.job_desc || "";
    const colonIndex = description.indexOf(":");
    const briefDesc = colonIndex > 0 ? description.substring(0, colonIndex).trim() : description;
    const details = colonIndex > 0 ? description.substring(colonIndex + 1).trim() : "";

    setFormData({
      job_desc: description,
      job_type: order.job_type || "",
      job_status: order.job_status || "OPEN",
      job_priority: order.job_priority || "Normal",
      job_createddatetime: formatDateForInput(order.job_createddatetime),
      contact_name: order.contact_name || "",
      contact_email: order.contact_email || "",
      contact_phone: order.contact_phone || "",
      asset_id: order.asset_id || "",
      room_id: order.room_id || "",
      nature: order.nature || "",
      brief_description: briefDesc,
      job_notes: details,
      authorized_by: order.authorized_by || "",
      completed_date: formatDateForInput(order.job_finisheddatetime),
      cost_recovery_notes: order.cost_recovery_notes || "",
    });
    setShowModal(true);
  }

  // Hanteer besparing van werksopdrag
  const handleSaveWorkOrder = async () => {
    try {
      if (!formData.job_desc && !formData.brief_description) {
        alert("Voer asseblief 'n beskrywing in.");
        return;
      }

      // Kombineer velde vir backend payload
      const payload = {
        job_desc: `${formData.brief_description}${formData.job_notes ? `: ${formData.job_notes}` : ''}`,
        job_type: formData.job_type || null,
        job_status: formData.job_status,
        job_priority: formData.job_priority || "Normal",
        job_createddatetime: formData.job_createddatetime || new Date().toISOString(),
        asset_id: formData.asset_id ? Number(formData.asset_id) : null,
        room_id: formData.room_id ? Number(formData.room_id) : null,
        contact_name: formData.contact_name || null,
        contact_email: formData.contact_email || null,
        contact_phone: formData.contact_phone || null,
        authorized_by: formData.authorized_by || null,
        completed_date: formData.completed_date || null,
        cost_recovery_notes: formData.cost_recovery_notes || null,
      };

      if (isEditing) {
        await workOrdersAPI.update(editingId, payload);
      } else {
        await workOrdersAPI.create(payload);
      }
      
      handleCloseModal();
      fetchWorkOrders();
    } catch (error) {
      console.error("Fout by besparing:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  // ===== QUOTES FUNKSIES =====
  const handleAddQuote = () => {
    if (!newQuote.supplier || !newQuote.amount) {
      alert("Verskaffer en bedrag is vereist");
      return;
    }
    
    const quote = {
      id: Date.now(),
      supplier: newQuote.supplier,
      amount: parseFloat(newQuote.amount),
      description: newQuote.description,
      createdAt: new Date().toLocaleDateString('af-ZA')
    };
    
    setQuotes([...quotes, quote]);
    setNewQuote({ supplier: "", amount: "", description: "" });
  };

  const handleDeleteQuote = (quoteId) => {
    setQuotes(quotes.filter(q => q.id !== quoteId));
    if (selectedQuoteId === quoteId) {
      setSelectedQuoteId(null);
    }
  };

  const handleSelectQuote = (quoteId) => {
    setSelectedQuoteId(quoteId === selectedQuoteId ? null : quoteId);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setQuotes([]);
    setSelectedQuoteId(null);
    setNewQuote({ supplier: "", amount: "", description: "" });
    setFormData({
      job_desc: "",
      job_type: "",
      job_status: "OPEN",
      job_priority: "Normal",
      job_createddatetime: "",
      contact_name: "",
      contact_email: "",
      contact_phone: "",
      asset_id: "",
      room_id: "",
      nature: "",
      brief_description: "",
      job_notes: "",
      authorized_by: "",
      completed_date: "",
      cost_recovery_notes: "",
    });
  };

  const handleNewWorkOrder = () => {
    setIsEditing(false);
    setEditingId(null);
    setFormData({
      job_desc: "",
      job_type: "",
      job_status: "OPEN",
      job_priority: "Normal",
      job_createddatetime: new Date().toISOString().split('T')[0],
      contact_name: "",
      contact_email: "",
      contact_phone: "",
      asset_id: "",
      room_id: "",
      nature: "",
      brief_description: "",
      job_notes: "",
      authorized_by: "",
      completed_date: "",
      cost_recovery_notes: "",
    });
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
      console.error("Fout by verwydering:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  // Filter en sorteer werksopdragte
  const filteredWorkOrders = workOrders.filter((order) => {
    const query = searchTerm.toLowerCase();
    const description = order.job_desc || "";
    const matchesSearch = description.toLowerCase().includes(query) || String(order.jobcard_id).includes(query);
    const matchesFilter = statusFilter === "" || order.job_status === statusFilter;
    return matchesSearch && matchesFilter;
  }).sort((a, b) => {
    switch (sortBy) {
      case "date":
        return new Date(b.job_createddatetime) - new Date(a.job_createddatetime);
      case "status":
        return (a.job_status || "").localeCompare(b.job_status || "");
      default:
        return (a.jobcard_id || 0) - (b.jobcard_id || 0);
    }
  });

  const translateStatus = (status) => {
    const translations = {
      OPEN: "Oop",
      WAIT: "Hangende",
      COMPLETED: "Voltooi",
      open: "Oop",
      wag: "Hangende",
      besig: "Besig",
      voltooid: "Voltooi",
    };
    return translations[status] || status || "-";
  };

  const getStatusClass = (status) => {
    if (status === "COMPLETED" || status === "voltooid") return "status-completed";
    if (status === "OPEN" || status === "open") return "status-open";
    if (status === "WAIT" || status === "wag") return "status-wait";
    return "status-default";
  };

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li class="dropdown" >
              <div className="dropdown-trigger">
                  <span>Bates & Voorraad</span>
              </div>
                  <div className="dropdown-content">
                  <Link to="/assets">Bates</Link>
                  <Link to="/stock">Voorraad</Link>
                  </div>
          </li>
              <li class="dropdown">
              <div className="dropdown-trigger">
                  <span>Lokale & Terreine</span>
              </div>
              <div className="dropdown-content">
                  <li><Link to="/rooms">Lokale</Link></li>
                  <li><Link to="/terrains">Terreine</Link></li>
              </div>
          </li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders" style={{ background: "#935e28" }}>Werksopdragte</Link></li>
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Teken Uit</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Bestuur Werksopdragte</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          {/* Beheer-reeks: Soek, Filter, Sorteer, Voeg By */}
          <div className="controls">
            <input 
              type="text" 
              className="search-box"
              id="jobSearch" 
              placeholder="Soek op ID of Beskrywing..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            
            <select 
              className="filter-select"
              id="statusFilter"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="">Alle Statuse</option>
              <option value="OPEN">Oop</option>
              <option value="WAIT">Hangende</option>
              <option value="COMPLETED">Voltooi</option>
            </select>

            <select 
              className="sort-select"
              id="jobSort"
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
            >
              <option value="id">Sorteer: ID</option>
              <option value="date">Sorteer: Datum</option>
              <option value="status">Sorteer: Status</option>
            </select>

              <button 
              type="button"
              className="btn-add" 
              id="addJobBtn"
              title="Voeg Nuwe Werksopdrag By"
              onClick={handleNewWorkOrder}
            >
              + Nuwe Werksopdrag
            </button>
          </div>

          {/* Tabel van Werksopdragte */}
          <table className="standard-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Beskrywing</th>
                <th>Werksoort</th>
                <th>Bate ID</th>
                <th>Datum</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredWorkOrders.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: "center", padding: "20px" }}>Geen werksopdragte gevind</td>
                </tr>
              ) : (
                filteredWorkOrders.map((order) => (
                  <tr key={order.jobcard_id}>
                    <td>{order.jobcard_id}</td>
                    <td className="description-cell">{order.job_desc || "-"}</td>
                    <td>{order.job_type || "-"}</td>
                    <td>{order.asset_id || "-"}</td>
                    <td>{order.job_createddatetime ? new Date(order.job_createddatetime).toLocaleDateString('af-ZA') : "-"}</td>
                    <td>
                      <span className={`status-badge ${getStatusClass(order.job_status)}`}>
                        {translateStatus(order.job_status)}
                      </span>
                    </td>
                    <td className="actions-cell">
                        <button 
                        type="button"
                        className="btn-edit"
                        onClick={() => handleEditWorkOrder(order)}
                        title="Bekyk en wysig werksopdrag"
                      >
                        Bekyk
                      </button>
                      <button 
                        type="button"
                        className="btn-delete"
                        onClick={() => handleDeleteWorkOrder(order.jobcard_id)}
                        title="Verwyder werksopdrag"
                      >
                        Verwyder
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL: Werksopdrag-Kaart */}
      {showModal && (
        <div className="modal" >
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            {/* Header */}
            <div className="modal-header">
                <h3>Werksopdrag Kaart</h3>
                {isEditing && (
                  <div className="mri-job-no">
                    <input 
                      type="text" 
                      className="inp-bold-large"
                      value={editingId}
                      readOnly
                    />
                  </div>
                )}
                <span className="close" onClick={handleCloseModal}>&times;</span>
                <hr/>
            </div>

            {/* Vorm */}
            <form className="mri-border-box" onSubmit={(e) => e.preventDefault()}>
              {/* Rij 1: Besonderhede */}
              <div className="mri-row flex">
                <div className="mri-cell w-60 border-r">
                  <label>Werksopdrag Beskrywing</label>
                  <input 
                    type="text" 
                    className="mri-txt-area-large"
                    value={formData.brief_description}
                    onChange={(e) => setFormData({...formData, brief_description: e.target.value})}
                    placeholder="Kort beskrywing van werk"
                  />
                </div>
                <div className="mri-cell w-40">
                  <div className="mri-fld"><span>Datum</span> 
                    <input 
                      type="date" 
                      value={formData.job_createddatetime}
                      onChange={(e) => setFormData({...formData, job_createddatetime: e.target.value})}
                    />
                  </div>
                  <div className="mri-fld"><span>Status</span> 
                    <select 
                      value={formData.job_status}
                      onChange={(e) => setFormData({...formData, job_status: e.target.value})}
                    >
                      <option value="OPEN">Oop</option>
                      <option value="WAIT">Hangende</option>
                      <option value="COMPLETED">Voltooi</option>
                    </select>
                  </div>
                  <div className="mri-fld"><span>Werksoort</span> 
                    <select 
                      value={formData.job_type}
                      onChange={(e) => setFormData({...formData, job_type: e.target.value})}
                    >
                      <option value="">Kies...</option>
                      <option value="maintenance">Onderhoud</option>
                      <option value="repair">Herstel</option>
                      <option value="inspection">Inspeksie</option>
                      <option value="installation">Installasie</option>
                      <option value="emergency">Nood</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Bate en Aard */}
              <div className="mri-row flex">
                <div className="mri-cell w-50 border-r">
                  <label>Bate</label>
                  <select 
                    value={formData.asset_id}
                    onChange={(e) => setFormData({...formData, asset_id: e.target.value})}
                    className="inp-full"
                  >
                    <option value="">Geen bate gekies</option>
                    {assets.map(asset => (
                      <option key={asset.asset_id} value={asset.asset_id}>
                        {asset.asset_id} - {asset.asset_name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="mri-cell w-50">
                  <div className="mri-fld"><span>Aard</span> <input type="text" value={formData.nature} onChange={(e) => setFormData({...formData, nature: e.target.value})} placeholder="Elektries, Meganies, ens." /></div>
                  <div className="mri-fld"><span>Prioriteit</span> 
                    <select value={formData.job_priority} onChange={(e) => setFormData({...formData, job_priority: e.target.value})}>
                      <option>Laag</option>
                      <option>Normal</option>
                      <option>Hoog</option>
                      <option>Spoedeisend</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Werk-Notas */}
              <div className="mri-row bg-light-grey">
                <div className="mri-cell w-100">
                  <label>Werknotas</label>
                  <textarea 
                    className="mri-txt-area-large"
                    value={formData.job_notes}
                    onChange={(e) => setFormData({...formData, job_notes: e.target.value})}
                    placeholder="Gedetailleerde beskrywing van werk wat gedoen moet word..."
                  />
                </div>
              </div>

              {/* Voltooiing */}
              <div className="mri-row flex last-row">
                <div className="mri-cell w-50 border-r">
                  <label>Voltooiing</label>
                  <div className="mri-fld"><span>Goedgekeur deur</span> <input type="text" value={formData.authorized_by} onChange={(e) => setFormData({...formData, authorized_by: e.target.value})} /></div>
                  <div className="mri-fld"><span>Voltooide Datum</span> <input type="date" value={formData.completed_date} onChange={(e) => setFormData({...formData, completed_date: e.target.value})} /></div>
                </div>
                <div className="mri-cell w-50">
                  <label>Koste-Nota</label>
                  <textarea 
                    className="mri-txt-area-small"
                    value={formData.cost_recovery_notes}
                    onChange={(e) => setFormData({...formData, cost_recovery_notes: e.target.value})}
                    placeholder="Koste-toerekening notas..."
                  />
                </div>
              </div>
            </form>

            {/* QUOTES SEKSIE */}
            <div className="mri-border-box">
              <h3>Kwotasies</h3>
              
              {/* Voeg Nuwe Kwotasie By */}
              <div className="quote-form">
                <h4 className="quote-form-title">Voeg Nuwe Kwotasie By</h4>
                <div className="quote-input-row">
                  <input 
                    type="text" 
                    placeholder="Verskaffer Naam"
                    value={newQuote.supplier}
                    onChange={(e) => setNewQuote({...newQuote, supplier: e.target.value})}
                    className="quote-input"
                  />
                  <input 
                    type="number" 
                    placeholder="Bedrag (R)"
                    value={newQuote.amount}
                    onChange={(e) => setNewQuote({...newQuote, amount: e.target.value})}
                    className="quote-input"
                  />
                  <button 
                    type="button"
                    onClick={handleAddQuote}
                    className="quote-add-btn"
                  >
                    Voeg By
                  </button>
                </div>
                <textarea 
                  placeholder="Beskrywing van Kwotasie (opsioneel)"
                  value={newQuote.description}
                  onChange={(e) => setNewQuote({...newQuote, description: e.target.value})}
                  className="quote-textarea"
                />
              </div>

              {/* Kwotasies Tabel */}
              {quotes.length > 0 && (
                <div className=" quote-table-wrap">
                  <table className="quote-table">
                    <thead>
                      <tr>
                        <th>Verskaffer</th>
                        <th style={{textAlign: "right"}}>Bedrag</th>
                        <th>Beskrywing</th>
                        <th style={{textAlign: "center"}}>Datum</th>
                        <th style={{textAlign: "center"}}>Gekies</th>
                        <th style={{textAlign: "center"}}>Aksie</th>
                      </tr>
                    </thead>
                    <tbody>
                      {quotes.map((quote) => (
                        <tr key={quote.id} className={selectedQuoteId === quote.id ? "selected" : ""}>
                          <td>{quote.supplier}</td>
                          <td style={{textAlign: "right", fontWeight: "700"}}>R {quote.amount.toFixed(2)}</td>
                          <td>{quote.description || "-"}</td>
                          <td style={{textAlign: "center"}}>{quote.createdAt}</td>
                          <td style={{textAlign: "center"}}>
                            <input 
                              type="radio" 
                              name="selectedQuote"
                              checked={selectedQuoteId === quote.id}
                              onChange={() => handleSelectQuote(quote.id)}
                            />
                          </td>
                          <td style={{textAlign: "center"}}>
                            <button 
                              type="button"
                              onClick={() => handleDeleteQuote(quote.id)}
                              className="quote-delete-btn"
                            >
                              Verwyder
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {selectedQuoteId && (
                    <div className="quote-summary">
                      ✓ Gekose Kwotasie: R {quotes.find(q => q.id === selectedQuoteId)?.amount.toFixed(2)} - {quotes.find(q => q.id === selectedQuoteId)?.supplier}
                    </div>
                  )}
                </div>
              )}
              {quotes.length === 0 && (
                <div className="quote-empty">
                  Geen kwotasies bygevoeg nog nie
                </div>
              )}
            </div>

            {/* Knoppies */}
            <div className="modal-footer no-print">
              <button type="button" className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button type="button" className="btn-view" onClick={() => window.print()}>Druk Werksopdrag</button>
              <button type="button" className="btn-save" onClick={handleSaveWorkOrder}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default WorkOrderPage;