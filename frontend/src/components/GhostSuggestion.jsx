import React from "react";

/**
 * GhostSuggestion — inline ghost/spookteks binne 'n leë veld.
 *
 * Gebruik: draai elke voorstelveld in 'n `position: relative` wrapper en
 * wys hierdie komponent wanneer `active` waar is. Die overlay is `pointer-events: none`
 * sodat die onderliggende input/select steeds fokus/klik ontvang.
 *
 * Vir select velde gebruik `select: true` en hang `ghost-select-wrapper` op die
 * wrapper sodat die onderliggende select se "Kies…" teks weggesteek word ter
 * dood verberg sodat die ghost die enigste sigbare teks is.
 */
export default function GhostSuggestion({ active, children, onAccept }) {
  if (!active || children == null || String(children).trim() === "") return null;
  const content = String(children);
  return (
    <div
      className="ghost-suggestion"
      aria-hidden="true"
      title={onAccept ? `Druk Tab om te aanvaar: ${content}` : content}
    >
      <span className="ghost-suggestion-text">{content}</span>
      {onAccept && <span className="ghost-suggestion-hint">Tab ↵</span>}
    </div>
  );
}
