import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import api from "../services/api";
import "../styles/Login.css";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage("");
    setError("");
    setLoading(true);

    try {
      await api.post("/auth/forgot-password", { user_email: email });
      setMessage("As die e-pos adres bestaan, is 'n herstel skakel gestuur.");
    } catch (err) {
      setError("Kon nie versoek verwerk nie. Probeer asseblief later.");
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
          <h2>Wagwoord Herstel</h2>
          <p className="subtitle">
            Voer jou e-pos adres in en ons stuur 'n herstel skakel.
          </p>

          {message && <div className="alert alert-success">{message}</div>}
          {error && <div className="alert alert-error">{error}</div>}

          <div className="input-group">
            <input
              type="email"
              placeholder="E-pos adres"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
            />
          </div>

          <button type="submit" className="login-button" disabled={loading}>
            {loading ? "Besig om te stuur..." : "Stuur Herstel Skakel"}
          </button>

          <div className="signup-link">
            <Link to="/login">Terug na aanmelding</Link>
          </div>
        </form>
      </div>
    </div>
  );
}
