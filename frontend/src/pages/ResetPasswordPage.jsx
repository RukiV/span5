import React, { useState } from "react";
import { useNavigate, useSearchParams, Link } from "react-router-dom";
import api from "../services/api";
import "../styles/Login.css";

export default function ResetPasswordPage() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get("token");
  const navigate = useNavigate();

  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (!token) {
    return (
      <div className="login-container">
        <div className="login-card">
          <h2>Ongeldige Skakel</h2>
          <p>Die herstel skakel is ongeldig. Vra asseblief 'n nuwe een aan.</p>
          <div className="signup-link">
            <Link to="/forgot-password">Stuur weer herstel skakel</Link>
          </div>
        </div>
      </div>
    );
  }

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage("");
    setError("");

    if (password !== confirm) {
      setError("Wagwoorde stem nie ooreen nie.");
      return;
    }

    if (password.length < 8) {
      setError("Wagwoord moet ten minste 8 karakters lank wees.");
      return;
    }

    setLoading(true);

    try {
      await api.post("/auth/reset-password", {
        token,
        new_password: password,
      });
      setMessage("Wagwoord suksesvol herstel!");
      setTimeout(() => navigate("/login"), 3000);
    } catch (err) {
      const detail = err.response?.data?.detail || "Kon nie wagwoord herstel nie.";
      setError(detail);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <form className="login-form" onSubmit={handleSubmit}>
          <div className="logo-container">
            <div className="logo">
              <h1>FBS</h1>
            </div>
          </div>
          <h2>Herstel Wagwoord</h2>

          {message && <div className="alert alert-success">{message}</div>}
          {error && <div className="alert alert-error">{error}</div>}

          <div className="input-group">
            <input
              type="password"
              placeholder="Nuwe wagwoord"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              minLength={8}
            />
          </div>
          <div className="input-group">
            <input
              type="password"
              placeholder="Bevestig nuwe wagwoord"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              required
              disabled={loading}
              minLength={8}
            />
          </div>

          <button type="submit" className="login-button" disabled={loading}>
            {loading ? "Besig om te herstel..." : "Herstel Wagwoord"}
          </button>

          <div className="signup-link">
            <Link to="/login">Terug na aanmelding</Link>
          </div>
        </form>
      </div>
    </div>
  );
}
