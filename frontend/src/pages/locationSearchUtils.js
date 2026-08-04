export function buildFlatLocationOptions(terrains, buildings, rooms, assets) {
  const buildingMap = {};
  (buildings || []).forEach(b => { buildingMap[String(b.building_id)] = b; });

  const options = [];
  (terrains || []).forEach(t => {
    const id = String(t.location_id);
    const name = t.location_name || t.location_desc || '';
    options.push({
      value: id,
      label: `${id} - ${name || "Terrein"}`,
      _cascadeLevel: 0,
      _parentId: null,
      _fields: { location_id: id, building_id: '', room_id: '', asset_id: '' },
    });
  });
  (buildings || []).forEach(b => {
    const id = String(b.building_id);
    const name = b.building_name || '';
    options.push({
      value: id,
      label: `${id} - ${name || "Gebou"}`,
      _cascadeLevel: 1,
      _parentId: String(b.location_id),
      _fields: { location_id: String(b.location_id), building_id: id, room_id: '', asset_id: '' },
    });
  });
  (rooms || []).forEach(r => {
    const id = String(r.room_id);
    const name = r.room_name || r.room_number || '';
    const building = buildingMap[String(r.building_id)];
    options.push({
      value: id,
      label: `${id} - ${name || "Lokaal"}`,
      _cascadeLevel: 2,
      _parentId: String(r.building_id),
      _fields: {
        location_id: building ? String(building.location_id) : '',
        building_id: String(r.building_id),
        room_id: id,
        asset_id: '',
      },
    });
  });
  (assets || []).forEach(a => {
    const id = String(a.asset_id);
    const name = a.asset_name || '';
    const room = (rooms || []).find(r => String(r.room_id) === String(a.room_id));
    const building = room ? buildingMap[String(room.building_id)] : null;
    options.push({
      value: id,
      label: `${id} - ${name || "Bate"}`,
      _cascadeLevel: 3,
      _parentId: String(a.room_id),
      _fields: {
        location_id: building ? String(building.location_id) : '',
        building_id: room ? String(room.building_id) : '',
        room_id: String(a.room_id),
        asset_id: id,
      },
    });
  });
  return options;
}