// HTML5 sleep-en-los hulpreëls vir her-ouering van die fisiese hiërargie.
// Gebruik die native DataTransfer API (geen eksterne biblioteek nodig).

export const DND_TYPES = {
  BUILDING: 'building',
  ROOM: 'room',
  ASSET: 'asset',
  ASSET_GROUP: 'asset_group',
  GROUP: 'group',
  STOCK: 'stock',
};

// Begin 'n sleur. Maak 'n dataTransfer-pakkie met `type` en `id`.
export function startDrag(evt, type, id) {
  evt.dataTransfer.setData('text/plain', JSON.stringify({ type, id }));
  evt.dataTransfer.effectAllowed = 'move';
}

// Lees die gesleurde item se { type, id } vanaf dataTransfer.
export function readDrag(evt) {
  const raw = evt.dataTransfer.getData('text/plain');
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

// Inline `onDragOver`-helper. Keer die verstek af (nodig sodat drop kan afvuur)
// en stel die drop-effek. `canDrop` is 'n opsionele funksie wat bepaal of die
// kol vyandig is; WYS indien nie.
export function dragOver(evt, canDrop = null) {
  evt.preventDefault();
  const payload = readDrag(evt);
  const allowed = canDrop ? canDrop(payload) : true;
  evt.dataTransfer.dropEffect = allowed ? 'move' : 'none';
}
