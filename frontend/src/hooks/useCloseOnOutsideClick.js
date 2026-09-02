import { useEffect, useRef } from "react";

// Gee 'n ref terug om aan 'n houer te koppel en roep `onOutside` aan wanneer
// die gebruiker buite daardie houer klik (bv. om 'n react-select spyskaart te
// sluit sonder om op 'n blur-opsie staat te maak).
export default function useCloseOnOutsideClick(onOutside) {
  const ref = useRef(null);
  const onOutsideRef = useRef(onOutside);

  useEffect(() => {
    onOutsideRef.current = onOutside;
  }, [onOutside]);

  useEffect(() => {
    function handleMouseDown(e) {
      if (ref.current && !ref.current.contains(e.target)) {
        onOutsideRef.current();
      }
    }
    document.addEventListener("mousedown", handleMouseDown);
    return () => document.removeEventListener("mousedown", handleMouseDown);
  }, []);

  return ref;
}
