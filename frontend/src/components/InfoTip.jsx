import React, { useState, useRef, useEffect } from "react";

/**
 * InfoTip — 'n klein "?"-knoppie wat by klik 'n kort verduideliking wys.
 *
 * Gebruik: <InfoTip text="Verduideliking van die veld..." />
 * Die popper sluit by buite-klik of Escape. Styling pas by App.css se donker/
 * goue palet en is heeltemal selfstandig (geen nuwe CSS nodig nie).
 */
function InfoTip({ text, ariaLabel = "Meer inligting" }) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    };
    const onKey = (e) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <span ref={wrapRef} style={{ position: 'relative', display: 'inline-flex', marginLeft: '6px', verticalAlign: 'middle' }}>
      <button
        type="button"
        aria-label={ariaLabel}
        onClick={() => setOpen((o) => !o)}
        style={{
          width: '18px', height: '18px', borderRadius: '50%', padding: 0,
          border: '1px solid #935E28', backgroundColor: open ? '#935E28' : 'transparent',
          color: open ? '#fff' : '#935E28', fontSize: '12px', fontWeight: 'bold',
          lineHeight: '16px', cursor: 'pointer', textAlign: 'center',
        }}
      >
        ?
      </button>
      {open && (
        <span
          role="tooltip"
          style={{
            position: 'absolute', top: '24px', left: '0', zIndex: 60,
            maxWidth: '280px', width: 'max-content', whiteSpace: 'normal',
            background: '#0E1E3B', color: '#fff', fontSize: '0.82rem', lineHeight: 1.4,
            padding: '8px 10px', borderRadius: '6px',
            boxShadow: '0 6px 18px rgba(0,0,0,0.25)',
          }}
        >
          {text}
        </span>
      )}
    </span>
  );
}

/** Afrikaanse verduidelikings vir die werksoorte (gedeel deur vorms). */
export const JOB_TYPE_HELP = {
  REPAIR: 'Herstelwerk: daar is \'n fout — vind die probleem en maak dit reg sodat alles weer werk.',
  MAINTENANCE: 'Onderhoud: roetine-werk om afbreek te voorkom — diens, skoonmaak of vervang van verbruiksgoed.',
  INSPECTION: 'Kyk of alles met die bate werk en ondersoek die bate fisies vir enige probleme.',
  INSTALLATION: 'Installasie: \'n nuwe toestel of onderdeel word opgesit en in werking gestel.',
};

export default InfoTip;
