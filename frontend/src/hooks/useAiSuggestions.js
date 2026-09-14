import { useEffect, useRef, useState } from "react";
import { apiClient } from "../services/api";

/**
 * useAiSuggestions — debounce AI-veldvoorstelle vir 'n vorm.
 *
 * Roep POST /ai/suggest (context + huidige vormwaardes) op nadat die gebruiker
 * ~800 ms getik het. Met niks ingevul doen dit niks (backend-gate, maar
 * ons spaar ook die versoek). Foutiewe/stil gevalle → leë voorstelle.
 *
 * Geeft terug: { suggestions, loading, filled }
 *   - suggestions: { veldKey: { value, id? }, ... }
 *   - loading: waar terwyl daar op die backend gewag word
 *   - filled: hoeveel vormvelde tans ingevul is (0 = poort toe)
 */
export default function useAiSuggestions({ context, values, enabled = true, delay = 800 }) {
  const [suggestions, setSuggestions] = useState({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const abortRef = useRef(null);

  const serialized = JSON.stringify(values ?? {});

  useEffect(() => {
    if (!enabled || !context) return;
    const vals = JSON.parse(serialized);
    const filled = Object.values(vals).filter(
      (v) => v !== null && v !== undefined && !(typeof v === "string" && !v.trim())
    ).length;

    if (filled < 1) {
      setSuggestions({});
      setLoading(false);
      setError(false);
      return;
    }

    setLoading(true);
    const timer = setTimeout(async () => {
      try {
        abortRef.current?.abort?.();
        const ctrl = new AbortController();
        abortRef.current = ctrl;
        const resp = await apiClient.suggest.suggest(context, vals, { signal: ctrl.signal });
        setSuggestions(resp.data?.suggestions || {});
        setError(false);
      } catch (err) {
        // Afgestorte/ou versoek — stil. Werklike foute (404/ou backend) merk ons
        // sodat die paneel dit kan wys i.p.v. dood te lyk.
        if (err?.response) setError(true);
        setSuggestions({});
      } finally {
        setLoading(false);
      }
    }, delay);

    return () => clearTimeout(timer);
  }, [serialized, context, enabled, delay]);

  const filledNow = Object.values(JSON.parse(serialized)).filter(
    (v) => v !== null && v !== undefined && !(typeof v === "string" && !v.trim())
  ).length;

  return { suggestions, loading, filled: filledNow, error };
}
