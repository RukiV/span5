import React from 'react';
import Modal from './Modal';
import { DND_TYPES, startDrag, readDrag, dragOver } from '../../utils/dnd';

/**
 * Sleep-en-los dialoog om DIREKTE kinders van 'n ouer na 'n nuwe ouer te skuif
 * voordat die ouer verwyder word.
 *
 * Modus:
 *  - 'individual' (bv. lokale onder 'n gebou): elke kind is 'n eie sleepbare kaart.
 *  - 'assetGroup' (bv. bates/stock onder 'n lokaal - enkel lokaal): 'n sleepbare GROEP kop
 *    (sleur = skuif AL die kinders saam na een teiken) PLUS elke kind se ry is individueel sleepbaar.
 *  - 'grouped' (bv. bates/voorraad gegroepeer volgens lokaal, lokale gegroepeer volgens gebou):
 *    groepe elk met items. Sleep groep-kop = skuif hele groep (alle bates in daardie lokaal).
 *    Gebou-vlak groepering word visueel vertoon wanneer groups[].buildingId verskaf word.
 *
 * SLEGS direkte kinders / inhoud word vertoon en geskuif.
 * - 'n Kind sonder 'n gekose nuwe ouer word saam met die ouer kaskade-verwyder.
 * - Ouers is soekbaar, en ouers waaraan jy reeds 'n kind toegewys het bly vasgepen/beklemtoon.
 *
 * onConfirm:
 *  - individual: { [kindId]: newParentId|null }
 *  - assetGroup: { [kindId]: newParentId|null, groupTarget: newParentId|null }
 *  - grouped: { [itemId]: newParentId|null }  (groep-toewysing uitgebrei na items)
 */
function MoveChildrenDialog({ config, onClose, onConfirm }) {
  const children = config?.children || [];
  const groups = config?.groups || null;
  const parentOptions = config?.parentOptions || [];
  const mode = config?.mode || (groups ? 'grouped' : 'individual');

  const isGrouped = !!groups && mode === 'grouped';

  const [assignments, setAssignments] = React.useState(() => {
    const init = { groupTarget: null };
    if (groups) {
      for (const g of groups) {
        init[g.id] = null;
        for (const it of g.items || []) init[it.id] = null;
      }
    }
    for (const c of children) init[c.id] = null;
    return init;
  });
  const [search, setSearch] = React.useState('');

  React.useEffect(() => {
    if (!config) return;
    const init = { groupTarget: null };
    const cfgGroups = config.groups || [];
    const cfgChildren = config.children || [];
    for (const g of cfgGroups) {
      init[g.id] = null;
      for (const it of g.items || []) init[it.id] = null;
    }
    for (const c of cfgChildren) init[c.id] = null;
    setAssignments(init);
    setSearch('');
  }, [config]);

  if (!config) return null;
  const {
    title = 'Skuif kinders',
    parentLabel = 'verwyder',
    confirmLabel = 'Skuif en verwyder',
    cancelLabel = 'Kanselleer',
    childrenHeader = null,
  } = config;

  const reset = () => {
    const init = { groupTarget: null };
    if (groups) {
      for (const g of groups) {
        init[g.id] = null;
        for (const it of g.items || []) init[it.id] = null;
      }
    }
    for (const c of children) init[c.id] = null;
    setAssignments(init);
    setSearch('');
  };

  const getParentLabel = (value) => {
    const o = parentOptions.find((p) => String(p.value) === String(value));
    return o ? o.label : '';
  };

  // Versamel alle itemIds vir telling/assigned bepaling
  const allItemIds = isGrouped ? groups.flatMap((g) => g.items.map((it) => it.id)) : children.map((c) => c.id);
  const assignedParentValues = parentOptions
    .map((p) => p.value)
    .filter((v) => {
      if (String(assignments.groupTarget) === String(v)) return true;
      if (isGrouped) {
        for (const g of groups) {
          if (String(assignments[g.id]) === String(v)) return true;
        }
      }
      return allItemIds.some((id) => String(assignments[id]) === String(v));
    });

  const query = search.trim().toLowerCase();
  const visibleParents = parentOptions.filter((p) => {
    const isAssigned = assignedParentValues.some((v) => String(v) === String(p.value));
    if (isAssigned) return true;
    if (!query) return true;
    return String(p.label || '').toLowerCase().includes(query);
  });
  const sortedParents = [...visibleParents].sort((a, b) => {
    const aAssigned = assignedParentValues.some((v) => String(v) === String(a.value)) ? 0 : 1;
    const bAssigned = assignedParentValues.some((v) => String(v) === String(b.value)) ? 0 : 1;
    return aAssigned - bAssigned;
  });

  const handleDrop = (evt, parentValue) => {
    evt.preventDefault();
    const payload = readDrag(evt);
    if (!payload) return;
    // Groep-sleep
    if (payload.type === DND_TYPES.GROUP) {
      const gid = payload.id;
      setAssignments((prev) => ({ ...prev, [gid]: parentValue }));
      return;
    }
    if (mode === 'assetGroup' && payload.type === DND_TYPES.ASSET_GROUP) {
      setAssignments((prev) => ({ ...prev, groupTarget: parentValue }));
      return;
    }
    const id = payload.id;
    if (id == null) return;
    setAssignments((prev) => {
      const next = { ...prev };
      next[id] = parentValue;
      return next;
    });
  };

  const buildConfirm = () => {
    if (isGrouped) {
      const out = {};
      for (const g of groups) {
        const gTarget = assignments[g.id] ?? null;
        for (const it of g.items) {
          const individual = assignments[it.id] ?? null;
          out[it.id] = individual != null ? individual : gTarget;
        }
      }
      // Vir versoenbaarheid, sluit ook groep-keys self in indien nodig (nie nodig vir bestaande callers)
      return out;
    }
    const out = {};
    for (const c of children) out[c.id] = assignments[c.id] ?? null;
    if (mode === 'assetGroup') {
      out.groupTarget = assignments.groupTarget ?? null;
    }
    return out;
  };

  const footer = (
    <>
      <button className="btn-cancel" onClick={() => { reset(); onClose(); }}>{cancelLabel}</button>
      <button className="btn-add" onClick={() => { reset(); onConfirm(buildConfirm()); }}>{confirmLabel}</button>
    </>
  );

  const parentZoneStyle = (value) => {
    const isAssigned = assignedParentValues.some((v) => String(v) === String(value));
    const base = {
      border: '1px dashed #cbd5e1',
      borderRadius: '8px',
      padding: '8px 10px',
      marginBottom: '8px',
      background: '#fff',
      cursor: 'grab',
      minHeight: '40px',
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
    };
    if (isAssigned) {
      return { ...base, border: '1px dashed #16a34a', background: '#f0fdf4', boxShadow: '0 0 0 1px #16a34a inset' };
    }
    return base;
  };

  const draggableChildStyle = (isGroup) => ({
    border: '1px solid #e2e8f0',
    borderRadius: '8px',
    padding: '8px 10px',
    marginBottom: '8px',
    background: isGroup ? '#eff6ff' : '#fafbfc',
    cursor: 'grab',
    fontSize: '13px',
    fontWeight: isGroup ? 700 : 400,
    color: '#1e293b',
  });

  const groupHeaderStyle = (isAssigned) => ({
    border: '1px solid #bfdbfe',
    borderRadius: '8px',
    padding: '8px 10px',
    marginBottom: '6px',
    background: isAssigned ? '#dbeafe' : '#eff6ff',
    cursor: 'grab',
    fontSize: '13px',
    fontWeight: 700,
    color: '#1e40af',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  });

  const itemInGroupStyle = (hasTarget) => ({
    border: '1px solid #e2e8f0',
    borderRadius: '6px',
    padding: '6px 8px',
    marginBottom: '6px',
    marginLeft: '12px',
    background: hasTarget ? '#f0fdf4' : '#fff',
    cursor: 'grab',
    fontSize: '12px',
    color: '#334155',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  });

  // Bepaal of gebou-groepering nodig is (meer as 1 gebou)
  const distinctBuildingIds = isGrouped ? new Set(groups.map((g) => g.buildingId).filter((v) => v != null)) : new Set();
  const showBuildingHeaders = distinctBuildingIds.size > 1;

  // Sorteer groepe volgens gebou dan label vir terrein-geval
  const sortedGroups = isGrouped
    ? [...groups].sort((a, b) => {
        const aB = a.buildingId != null ? String(a.buildingId) : '';
        const bB = b.buildingId != null ? String(b.buildingId) : '';
        if (aB !== bB) return aB.localeCompare(bB);
        return String(a.label).localeCompare(String(b.label), 'af', { sensitivity: 'base' });
      })
    : [];

  const countForParent = (parentValue) => {
    if (isGrouped) {
      let cnt = 0;
      for (const g of groups) {
        const gTarget = assignments[g.id];
        for (const it of g.items) {
          const t = assignments[it.id] ?? gTarget ?? null;
          if (String(t) === String(parentValue)) cnt += 1;
        }
      }
      return cnt;
    }
    if (mode === 'assetGroup') {
      const groupCnt = String(assignments.groupTarget) === String(parentValue) ? 1 : 0;
      const itemCnt = children.filter((c) => String(assignments[c.id]) === String(parentValue)).length;
      return groupCnt + itemCnt;
    }
    return children.filter((c) => String(assignments[c.id]) === String(parentValue)).length;
  };

  return (
    <Modal
      isOpen={true}
      onClose={() => { reset(); onClose(); }}
      title={title}
      size="lg"
      footer={footer}
    >
      <div style={{ marginBottom: '14px', fontSize: '14px', lineHeight: '1.6', color: '#495057' }}>
        Sleep elke kind na sy/haar nuwe ouer. 'n Kind sonder 'n nuwe ouer
        ({parentLabel}) word saam met hierdie rekord permanent verwyder.
        {mode === 'assetGroup' && (
          <div style={{ marginTop: '6px', fontWeight: 600, color: '#1d4ed8' }}>
            Sleur die blou kop na 'n ouer om AL die bates saam te skuif, of sleep elke bate apart.
          </div>
        )}
        {isGrouped && (
          <div style={{ marginTop: '6px', fontWeight: 600, color: '#1d4ed8' }}>
            Bates en voorraad is volgens lokaal gegroepeer en lokale volgens gebou. Sleur ’n lokaal-kop om al sy bates saam te skuif.
          </div>
        )}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
        {/* Linkerkolom: kinders / groepe */}
        <div>
          <div style={{ fontSize: '13px', fontWeight: 700, color: '#334155', marginBottom: '8px' }}>
            {childrenHeader || (mode === 'assetGroup' ? 'Bates (sleep individueel of as groep)' : isGrouped ? 'Groepe (sleep per lokaal)' : 'Kinders')}
          </div>
          <div style={{ maxHeight: '46vh', overflowY: 'auto', paddingRight: '4px' }}>
            {isGrouped ? (
              <>
                {sortedGroups.length === 0 ? (
                  <div style={{ fontSize: '13px', color: '#94a3b8' }}>Geen kinders om te skuif.</div>
                ) : (
                  (() => {
                    let lastBuildingId = null;
                    return sortedGroups.map((g) => {
                      const gAssigned = assignments[g.id] != null;
                      const showBuildingHeader = showBuildingHeaders && String(g.buildingId) !== String(lastBuildingId);
                      if (showBuildingHeader) lastBuildingId = g.buildingId;
                      return (
                        <React.Fragment key={g.id}>
                          {showBuildingHeader && (
                            <div style={{ fontSize: '12px', fontWeight: 700, color: '#475569', margin: '10px 0 6px', padding: '6px 8px', background: '#f1f5f9', borderRadius: '6px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <span>🏢</span> {g.buildingLabel || `Gebou ${g.buildingId}`}
                            </div>
                          )}
                          <div style={{ border: '1px solid #cbd5e1', borderRadius: '10px', marginBottom: '10px', overflow: 'hidden', background: '#fff' }}>
                            <div
                              draggable
                              onDragStart={(e) => startDrag(e, DND_TYPES.GROUP, g.id)}
                              style={groupHeaderStyle(gAssigned)}
                              title="Sleur om hele groep saam te skuif"
                            >
                              <span>▤</span>
                              <span style={{ flex: 1 }}>{g.label} ({g.items.length})</span>
                              {gAssigned && (
                                <span style={{ fontSize: '11px', color: '#16a34a', fontWeight: 600 }}>
                                  → {getParentLabel(assignments[g.id])}
                                </span>
                              )}
                            </div>
                            <div style={{ padding: '6px 6px 2px' }}>
                              {g.items.map((it) => {
                                const effectiveTarget = assignments[it.id] ?? assignments[g.id] ?? null;
                                const hasTarget = effectiveTarget != null;
                                return (
                                  <div
                                    key={it.id}
                                    draggable
                                    onDragStart={(e) => startDrag(e, DND_TYPES.ASSET, it.id)}
                                    style={itemInGroupStyle(hasTarget)}
                                    title="Sleur om individuele bate te skuif"
                                  >
                                    <span style={{ fontSize: '12px' }}>⠿</span>
                                    <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.label}</span>
                                    {hasTarget && (
                                      <span style={{ fontSize: '11px', color: '#16a34a', fontWeight: 600, flexShrink: 0 }}>
                                        → {getParentLabel(effectiveTarget)}
                                      </span>
                                    )}
                                  </div>
                                );
                              })}
                            </div>
                          </div>
                        </React.Fragment>
                      );
                    });
                  })()
                )}
              </>
            ) : (
              <>
                {mode === 'assetGroup' && (
                  <div
                    draggable
                    onDragStart={(e) => startDrag(e, DND_TYPES.ASSET_GROUP, 'all')}
                    style={draggableChildStyle(true)}
                    title="Sleur om al die bates na een ouer te skuif"
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <span style={{ fontSize: '14px' }}>▤</span>
                      <span>Bates uit hierdie lokaal — Al {children.length} bates</span>
                      {assignments.groupTarget != null && (
                        <span style={{ marginLeft: 'auto', fontSize: '12px', color: '#16a34a', fontWeight: 600 }}>
                          → {getParentLabel(assignments.groupTarget)}
                        </span>
                      )}
                    </div>
                  </div>
                )}
                {children.map((c) => (
                  <div
                    key={c.id}
                    draggable
                    onDragStart={(e) => startDrag(e, mode === 'assetGroup' ? DND_TYPES.ASSET : DND_TYPES.ROOM, c.id)}
                    style={draggableChildStyle(false)}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <span style={{ fontSize: '14px' }}>⠿</span>
                      <span>{c.label}</span>
                      {assignments[c.id] != null && (
                        <span style={{ marginLeft: 'auto', fontSize: '12px', color: '#16a34a', fontWeight: 600 }}>
                          → {getParentLabel(assignments[c.id])}
                        </span>
                      )}
                    </div>
                  </div>
                ))}
                {children.length === 0 && !isGrouped && (
                  <div style={{ fontSize: '13px', color: '#94a3b8' }}>Geen kinders om te skuif.</div>
                )}
              </>
            )}
          </div>
        </div>

        {/* Regterkolom: ouer teikens */}
        <div>
          <div style={{ fontSize: '13px', fontWeight: 700, color: '#334155', marginBottom: '8px' }}>
            Nuwe ouers
          </div>
          <input
            type="text"
            placeholder="Soek ouer..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              width: '100%', boxSizing: 'border-box', padding: '8px 10px', marginBottom: '8px',
              border: '1px solid #cbd5e1', borderRadius: '8px', fontSize: '13px',
            }}
          />
          <div style={{ maxHeight: '46vh', overflowY: 'auto', paddingRight: '4px' }}>
            {sortedParents.map((p) => {
              const assignedCount = countForParent(p.value);
              return (
                <div
                  key={p.value}
                  draggable={false}
                  onDragOver={(e) => dragOver(e)}
                  onDrop={(e) => handleDrop(e, p.value)}
                  style={parentZoneStyle(p.value)}
                  title={`Los hier om te skuif na: ${p.label}`}
                >
                  <span style={{ fontSize: '14px' }}>▣</span>
                  <span style={{ flex: '1', fontSize: '13px' }}>{p.label}</span>
                  {assignedCount > 0 && (
                    <span style={{ fontSize: '11px', background: '#dcfce7', color: '#16a34a', borderRadius: '10px', padding: '2px 8px', fontWeight: 600 }}>
                      {assignedCount}
                    </span>
                  )}
                </div>
              );
            })}
            {sortedParents.length === 0 && (
              <div style={{ fontSize: '13px', color: '#94a3b8' }}>Geen ouers gevind.</div>
            )}
          </div>
        </div>
      </div>
    </Modal>
  );
}

export default MoveChildrenDialog;
