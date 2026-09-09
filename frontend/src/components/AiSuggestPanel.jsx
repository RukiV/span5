import React, { useState } from "react";

/**
 * AiSuggestPanel — AI-veldvoorstelle, DOCKED binne die vorm/modaal self.
 *
 * Plaas hierdie komponent direk bo die modaal se voetsone (of bo die vorm se
 * aksieknoppies). Wys per oop veld wat die AI voorstel + 'n "Gebruik"-knoppie.
 *
 * props:
 *  - suggestions: { veldKey: { value, id? } }   (soos deur useAiSuggestions)
 *  - loading: bool — wag tans op die backend
 *  - filled: hoeveel vormvelde reeds ingevul is (<3 = poort nog toe)
 *  - error: bool — laaste versoek het misluk (bv. ou backend sonder /ai/suggest)
 *  - labels: { veldKey: 'Vertoonnaam' }
 *  - onUse: (veldKey, voorstel) => void
 */
function AiSuggestPanel({ suggestions = {}, loading = false, filled = 0, error = false, labels = {}, onUse }) {
  const [collapsed, setCollapsed] = useState(false);
  const entries = Object.entries(suggestions || {}).filter(
    ([, s]) => s && s.value !== undefined && s.value !== null && String(s.value).trim() !== ""
  );

  let body;
  if (error) {
    body = <div style={{ color: '#b91c1c' }}>AI-diens onbereikbaar — kontroleer dat die backend op datum is.</div>;
  } else if (filled < 3) {
    body = <div style={{ color: '#666' }}>Vul minstens 3 velde in (tans {filled}) en ek stel voor hoe die res gevul kan word.</div>;
  } else if (loading && entries.length === 0) {
    body = <div style={{ color: '#666', display: 'flex', alignItems: 'center', gap: 8 }}><span className="spinner-border spinner-border-sm" role="status" aria-hidden="true" />Dink…</div>;
  } else if (entries.length === 0) {
    body = <div style={{ color: '#666' }}>Geen voorstelle vir die oop velde nie.</div>;
  } else {
    body = (
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px 18px' }}>
        {entries.map(([key, s]) => (
          <div key={key} style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: '220px' }}>
            <div>
              <div style={{ fontSize: '0.68rem', color: '#888', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{labels[key] || key}</div>
              <div style={{ fontWeight: 600, color: '#0E1E3B', overflowWrap: 'anywhere' }}>{String(s.value)}</div>
            </div>
            <button
              type="button"
              className="btn-add"
              style={{ padding: '3px 12px', fontSize: '0.78rem', marginLeft: 'auto', flexShrink: 0 }}
              onClick={() => onUse?.(key, s)}
            >
              Gebruik
            </button>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div
      style={{
        position: 'fixed', top: '50%', right: 0, transform: 'translateY(-50%)',
        zIndex: 1300, width: '300px', maxWidth: '85vw',
        maxHeight: '70vh', overflowY: 'auto',
        background: '#fdf8f3',
        border: '1px solid #e7d9c7',
        borderLeft: '4px solid #935E28',
        borderRadius: '10px 0 0 10px',
        boxShadow: '-6px 0 22px rgba(0,0,0,0.18)',
        fontSize: '0.85rem',
      }}
    >
      <div
        onClick={() => setCollapsed((c) => !c)}
        style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', cursor: 'pointer', fontWeight: 600, color: '#935E28', userSelect: 'none', position: 'sticky', top: 0, background: '#fdf8f3', zIndex: 1 }}
        title="Voorgestelde Werksopdragte-veldvoorstelle"
      >
        <span>💡 Voorgestelde Werksopdragte{entries.length > 0 ? ` (${entries.length})` : ''}</span>
        <span>{collapsed ? '▸' : '▾'}</span>
      </div>
      {!collapsed && <div style={{ padding: '0 14px 10px', lineHeight: 1.35 }}>{body}</div>}
    </div>
  );
}

export default AiSuggestPanel;
