export function downloadBlob(blob, fileName) {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
}

export function filenameFromDisposition(header, fallback) {
  if (!header) return fallback;
  const match = /filename\*?=(?:UTF-8''|")?([^";]+)/i.exec(header);
  if (!match) return fallback;
  try {
    return decodeURIComponent(match[1].replace(/"/g, ''));
  } catch (_) {
    return match[1].replace(/"/g, '');
  }
}
