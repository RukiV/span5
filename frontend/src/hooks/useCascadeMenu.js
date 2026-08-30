import { useEffect, useRef, useState } from "react";

// Beheer 'n reaksie-select cascade-spyskaart se oop/sluit-toestand en maak dit
// toe wanneer die gebruiker buite die houer klik (mousedown). Klieke binne die
// sparkies se eie spyskaart word geïgnoreer sodat menusels van 'n reaksie-select
// langs / bo-aan (bv. menuPortalTarget) die spyskaart nie voortydig toemaak nie.
export default function useCascadeMenu() {
  const [menuIsOpen, setMenuIsOpen] = useState(false);
  const containerRef = useRef(null);

  useEffect(() => {
    if (!menuIsOpen) return undefined;

    function handleMouseDown(e) {
      const target = e.target;
      if (!containerRef.current) return;
      if (!target || typeof target.closest !== "function") return;
      // Ignore mousedown on detached nodes (e.g. the input element that gets
      // replaced mid-click when the menu opens), otherwise the menu closes the
      // instant it opens.
      if (!document.body.contains(target)) return;
      if (containerRef.current.contains(target)) return;
      if (target.closest(".react-select__menu, .select__menu")) return;
      setMenuIsOpen(false);
    }

    document.addEventListener("mousedown", handleMouseDown);
    return () => document.removeEventListener("mousedown", handleMouseDown);
  }, [menuIsOpen]);

  return {
    containerRef,
    menuIsOpen,
    onMenuOpen: () => setMenuIsOpen(true),
    onMenuClose: () => setMenuIsOpen(false),
  };
}
