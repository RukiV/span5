// Gedeelde hulpreëls vir verwydering (kaskade-waarskuwing, foutboodskappe,
// en groepverwydering).

// Haal die backend se foutbeskrywing uit 'n axios-fout; val terug op `fallback`.
export function getDeleteErrorMessage(error, fallback) {
  return getApiErrorMessage(error, fallback);
}

// Haal en normaliseer die backend se foutbeskrywing uit 'n axios-fout.
// Hanteer beide string-detail (bv. HTTPException) en die array-detail wat
// FastAPI/Pydantic vir 422-validasie-foute terugstuur. Val terug op `fallback`.
export function getApiErrorMessage(error, fallback) {
  const detail = error?.response?.data?.detail;
  if (typeof detail === 'string' && detail.trim()) return detail;
  if (Array.isArray(detail) && detail.length > 0) {
    return detail
      .map((item) => (item && typeof item.msg === 'string' ? item.msg : null))
      .filter(Boolean)
      .join(' ')
      || fallback;
  }
  return fallback;
}

// Helper om Afrikaanse lys te formateer: ["a","b","c"] -> "a, b en c"
function formatAfrikaansList(parts) {
  if (parts.length === 0) return '';
  if (parts.length === 1) return parts[0];
  if (parts.length === 2) return `${parts[0]} en ${parts[1]}`;
  return `${parts.slice(0, -1).join(', ')} en ${parts[parts.length - 1]}`;
}

// Enkelvoud-kaart vir korrekte grammatika: 1 bate vs 2 bates
const SINGULAR_MAP = {
  lokale: 'lokaal',
  geboue: 'gebou',
  bates: 'bate',
  voorraad: 'voorraad',
  foutkaartjies: 'foutkaartjie',
  werksopdragte: 'werksopdrag',
};

function formatCountLabel(count, pluralLabel) {
  if (count === 1) {
    const singular = SINGULAR_MAP[pluralLabel] || pluralLabel;
    // Voor voorraad bly enkelvoud = meervoud
    return `1 ${singular}`;
  }
  return `${count} ${pluralLabel}`;
}

// Bied die gebruiker die keuse wanneer 'n ouer kinders het:
//  - `'delete'`: verwyder alles daaronder (destruktiewe kaskade).
//  - `'move'`: skuif direkte kinders individueel na nuwe ouers, dan verwyder.
//  - `'moveContent'`: skuif bates en voorraad in die subboom individueel na nuwe lokale (gebou/terrein).
//  - `false`: gekanselleer.
// As daar GEEN kinders en GEEN inhoud is nie, word slegs 'n eenvoudige bevestiging gewys.
export async function chooseDeleteStrategy(confirm, { entityLabel, childrenLabel, hasChildren, hasContent = false, counts = null, directChildrenLabel = null, parentLevelLabel = null }) {
  if (!hasChildren && !hasContent) {
    const ok = await confirm({
      title: `Verwyder ${entityLabel}?`,
      message: `Is jy seker jy wil die ${entityLabel} permanent verwyder?`,
      confirmLabel: 'Ja, verwyder',
      cancelLabel: 'Kanselleer',
      variant: 'danger',
    });
    return ok ? 'delete' : false;
  }
  const actions = [
    { key: 'delete', label: 'Verwyder alles daaronder', variant: 'danger' },
  ];
  if (hasChildren) {
    actions.push({ key: 'move', label: 'Skuif kinders na nuwe ouers', variant: 'info' });
  }
  if (hasContent) {
    actions.push({ key: 'moveContent', label: 'Skuif bates en voorraad', variant: 'info' });
  }

  // Bou dinamiese boodskap: "Daar is x, y en z gekoppel. Is jy seker ... of wil jy ... of ...?"
  let message;
  if (counts && typeof counts === 'object') {
    const parts = [];
    for (const [label, count] of Object.entries(counts)) {
      if (count > 0) parts.push(formatCountLabel(count, label));
    }
    if (parts.length > 0) {
      const lys = formatAfrikaansList(parts);
      const base = `Daar is ${lys} gekoppel aan hierdie ${entityLabel}.`;
      // Bou opsies met korrekte grammatika: "hierdie rekord en sy kinders verwyder of wil jy die X na nuwe Y skuif"
      const opsies = [];
      opsies.push('hierdie rekord en sy kinders verwyder');
      if (hasChildren) {
        if (directChildrenLabel && parentLevelLabel) {
          opsies.push(`die ${directChildrenLabel} na nuwe ${parentLevelLabel} skuif`);
        } else {
          opsies.push('kinders skuif');
        }
      }
      if (hasContent) {
        opsies.push('die bates en voorraad na nuwe lokale skuif');
      }
      // Vir lokaal-geval waar hasChildren = bates/voorraad en hasContent=false, is die 2de opsie reeds bates-skuif.
      // Indien hasChildren true maar directChildrenLabel ontbreek vir lokaal, vervang generiese "kinders skuif" met bates-teks
      // (RoomsPage sal directChildrenLabel="bates en voorraad" en parentLevelLabel="lokaal" deurgee vir korrekte sin)
      let vraag;
      if (opsies.length === 1) {
        vraag = `Is jy seker jy wil ${opsies[0]}?`;
      } else if (opsies.length === 2) {
        vraag = `Is jy seker jy wil ${opsies[0]} of wil jy ${opsies[1]}?`;
      } else {
        vraag = `Is jy seker jy wil ${opsies[0]} of wil jy ${opsies[1]} of ${opsies[2]}?`;
      }
      message = `${base} ${vraag}`;
    }
  }
  if (!message) {
    // Fallback vir oproepers wat nie counts deurgee nie
    let fallback = `Die ${entityLabel} het ${childrenLabel} wat gekoppel is.`;
    if (hasContent && hasChildren) {
      fallback = `Die ${entityLabel} het ${childrenLabel} en bates/voorraad wat gekoppel is.`;
    } else if (hasContent && !hasChildren) {
      fallback = `Die ${entityLabel} het bates en voorraad wat gekoppel is.`;
    }
    const opsies = [];
    opsies.push('hierdie rekord en sy kinders verwyder');
    if (hasChildren) {
      if (directChildrenLabel && parentLevelLabel) {
        opsies.push(`die ${directChildrenLabel} na nuwe ${parentLevelLabel} skuif`);
      } else {
        opsies.push('kinders skuif');
      }
    }
    if (hasContent) opsies.push('die bates en voorraad na nuwe lokale skuif');
    let vraag;
    if (opsies.length === 1) vraag = `Is jy seker jy wil ${opsies[0]}?`;
    else if (opsies.length === 2) vraag = `Is jy seker jy wil ${opsies[0]} of wil jy ${opsies[1]}?`;
    else vraag = `Is jy seker jy wil ${opsies[0]} of wil jy ${opsies[1]} of ${opsies[2]}?`;
    message = `${fallback} ${vraag}`;
  }

  // Maak popup wyer indien 3 opsies (4 knoppies in ry) sodat hulle langs mekaar pas sonder scrollbar
  const popupSize = actions.length >= 3 ? 'lg' : 'md';
  return confirm({
    title: `Verwyder ${entityLabel}?`,
    message,
    actions,
    cancelLabel: 'Kanselleer',
    size: popupSize,
    variant: 'danger',
    cascade: true,
  });
}

// Wys die groot rooi kaskade-waarskuwing. Gebruik dit wanneer 'n rekord
// kinders het wat saam permanent verwyder sal word.
// Bou nou korrekte "insluitend ..." lys per entiteit — 'n bate het geen geboue/lokale onder nie.
const CASCADE_INCLUSION_MAP = {
  terrein: 'geboue, lokale, bates, voorraad, foutkaartjies, werkopdragte en beelde',
  terreine: 'geboue, lokale, bates, voorraad, foutkaartjies, werkopdragte en beelde',
  gebou: 'lokale, bates, voorraad, foutkaartjies, werkopdragte en beelde',
  geboue: 'lokale, bates, voorraad, foutkaartjies, werkopdragte en beelde',
  lokaal: 'bates, voorraad, foutkaartjies, werkopdragte en beelde',
  lokale: 'bates, voorraad, foutkaartjies, werkopdragte en beelde',
  bate: 'foutkaartjies, werkopdragte en beelde',
  bates: 'foutkaartjies, werkopdragte en beelde',
  'voorraad-item': 'beelde',
  voorraad: 'beelde',
  'voorraad-items': 'beelde',
  foutkaartjie: 'werksopdragte en beelde',
  foutkaartjies: 'werksopdragte en beelde',
  werksopdrag: 'beelde',
  werksopdragte: 'beelde',
  werkopdrag: 'beelde',
};

function getCascadeInclusion(entityLabel) {
  const key = String(entityLabel || '').toLowerCase().trim();
  return CASCADE_INCLUSION_MAP[key] || null;
}

function dedupInclusion(childrenLabel, inclusion) {
  if (!inclusion) return null;
  const childParts = String(childrenLabel || '')
    .toLowerCase()
    .split(/[\/,]/)
    .map((s) => s.trim())
    .filter(Boolean);
  const flatInc = String(inclusion)
    .split(',')
    .flatMap((p) => p.split(' en ').map((s) => s.trim().toLowerCase()))
    .filter(Boolean);
  const filtered = flatInc.filter((inc) => !childParts.some((cp) => inc === cp || inc.includes(cp) || cp.includes(inc)));
  if (filtered.length === 0) return null;
  return formatAfrikaansList(filtered);
}

export async function confirmCascade(confirm, { entityLabel, childrenLabel }) {
  const inclusion = getCascadeInclusion(entityLabel);
  const deduped = dedupInclusion(childrenLabel, inclusion);
  const detail = deduped ? ` — insluitend ${deduped}.` : '.';
  return confirm({
    title: `Verwyder ${entityLabel} en alles daaronder?`,
    message: `Is jy seker? Dit sal die ${entityLabel} sowel as ALLE ${childrenLabel} daaronder permanent verwyder${detail}`,
    confirmLabel: `Ja, verwyder ${entityLabel} en alles`,
    cancelLabel: 'Kanselleer',
    variant: 'danger',
    cascade: true,
  });
}

// Verwyder 'n lys id's een vir een en rapporteer suksesse en mislukkings.
// `apiDelete` is 'n funksie wat '(id) => Promise' teruggee.
export async function batchDelete({
  ids,
  apiDelete,
  confirm,
  showToast,
  entityLabel,
  childrenLabel,
  refresh,
  errorFallback,
}) {
  if (!ids || ids.length === 0) return;

  const ok = await confirmCascade(confirm, { entityLabel, childrenLabel });
  if (!ok) return;

  const failed = [];
  let succeeded = 0;
  for (const id of ids) {
    try {
      await apiDelete(id);
      succeeded += 1;
    } catch (error) {
      failed.push(getDeleteErrorMessage(error, errorFallback));
    }
  }

  if (refresh) refresh();

  if (failed.length === 0) {
    showToast({
      type: 'success',
      title: 'Sukses',
      message: `${succeeded} rekord(s) is verwyder.`,
    });
  } else if (succeeded === 0) {
    showToast({
      type: 'error',
      title: 'Fout',
      message: failed[0],
    });
  } else {
    showToast({
      type: 'warning',
      title: 'Gedeeltelik',
      message: `${succeeded} rekord(s) is verwyder, maar ${failed.length} kon nie verwyder word nie. ${failed[0]}`,
    });
  }
}
