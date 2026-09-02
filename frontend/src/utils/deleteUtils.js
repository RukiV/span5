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

// Bied die gebruiker die keuse wanneer 'n ouer kinders het:
//  - `'delete'`: verwyder alles daaronder (destruktiewe kaskade).
//  - `'move'`: skuif direkte kinders individueel na nuwe ouers, dan verwyder.
//  - `'moveContent'`: skuif bates en voorraad in die subboom individueel na nuwe lokale (gebou/terrein).
//  - `false`: gekanselleer.
// As daar GEEN kinders en GEEN inhoud is nie, word slegs 'n eenvoudige bevestiging gewys.
export async function chooseDeleteStrategy(confirm, { entityLabel, childrenLabel, hasChildren, hasContent = false }) {
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
  let message = `Die ${entityLabel} het ${childrenLabel} wat gekoppel is.`;
  if (hasContent && hasChildren) {
    message = `Die ${entityLabel} het ${childrenLabel} en bates/voorraad wat gekoppel is.`;
  } else if (hasContent && !hasChildren) {
    message = `Die ${entityLabel} het bates en voorraad wat gekoppel is.`;
  }
  return confirm({
    title: `Verwyder ${entityLabel}?`,
    message,
    actions,
    cancelLabel: 'Kanselleer',
    size: 'md',
    variant: 'danger',
    cascade: true,
  });
}

// Wys die groot rooi kaskade-waarskuwing. Gebruik dit wanneer 'n rekord
// kinders het wat saam permanent verwyder sal word.
export async function confirmCascade(confirm, { entityLabel, childrenLabel }) {
  return confirm({
    title: `Verwyder ${entityLabel} en alles daaronder?`,
    message:
      `Is jy seker? Dit sal die ${entityLabel} sowel as ALLE ${childrenLabel} daaronder permanent verwyder — ` +
      'insluitend geboue, lokale, bates, voorraad, foutkaartjies, werkopdragte en beelde.',
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
