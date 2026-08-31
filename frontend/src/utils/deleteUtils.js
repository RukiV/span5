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
