import React, { useEffect, useState } from 'react';
import Modal from '../Modal/Modal';
import ImportWizard from '../ImportWizard/ImportWizard';
import { importAPI } from '../../services/api';
import { useCurrentUser } from '../../hooks/useCurrentUser';
import { useToast } from '../Toast/useToast';
import { downloadBlob, filenameFromDisposition } from '../../utils/fileDownload';
import './ImportExportModal.css';

function ImportExportModal({ isOpen, onClose, defaultEntity = null, onImported }) {
  const { hasRight } = useCurrentUser();
  const { showToast } = useToast();
  const [tab, setTab] = useState('import');
  const [schema, setSchema] = useState([]);
  const [selectedTables, setSelectedTables] = useState([]);
  const [colSel, setColSel] = useState({});
  const [expanded, setExpanded] = useState({});
  const [format, setFormat] = useState('xlsx');
  const [templateOnly, setTemplateOnly] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    setTab('import');
    setFormat('xlsx');
    setTemplateOnly(false);
    setColSel({});
    setExpanded({});
    importAPI
      .schema()
      .then((r) => {
        const allowed = (r.data || []).filter((s) => hasRight(s.right));
        setSchema(allowed);
        setSelectedTables(
          defaultEntity && allowed.some((s) => s.key === defaultEntity) ? [defaultEntity] : []
        );
      })
      .catch(() => setSchema([]));
  }, [isOpen, defaultEntity]); // eslint-disable-line react-hooks/exhaustive-deps

  const targetsOf = (key) => (schema.find((s) => s.key === key)?.targets) || [];

  const toggleTable = (key) => {
    setSelectedTables((prev) => {
      if (prev.includes(key)) {
        return prev.filter((k) => k !== key);
      }
      const next = [...prev, key];
      if (next.length > 1) setFormat('xlsx');
      return next;
    });
    setColSel((prev) => {
      const next = { ...prev };
      if (selectedTables.includes(key)) delete next[key];
      else next[key] = new Set(targetsOf(key).map((t) => t.target));
      return next;
    });
    setExpanded((prev) => ({ ...prev, [key]: true }));
  };

  const toggleColumn = (key, target) => {
    setColSel((prev) => {
      const cur = new Set(prev[key] || []);
      if (cur.has(target)) cur.delete(target);
      else cur.add(target);
      return { ...prev, [key]: cur };
    });
  };

  const setAllColumns = (key, all) => {
    setColSel((prev) => ({
      ...prev,
      [key]: all ? new Set(targetsOf(key).map((t) => t.target)) : new Set(),
    }));
  };

  const missingRequired = (key) => {
    const sel = colSel[key];
    if (!sel) return [];
    return targetsOf(key).filter((t) => t.required && !sel.has(t.target));
  };

  const handleExport = async () => {
    if (!selectedTables.length) return;
    setBusy(true);
    try {
      const payload = {
        format,
        template: templateOnly,
        tables: selectedTables.map((key) => ({
          entity: key,
          columns: Array.from(colSel[key] || []),
        })),
      };
      const resp = await importAPI.exportData(payload);
      const fallback = `${templateOnly ? 'sjabloon' : 'uitvoer'}-${new Date()
        .toISOString()
        .slice(0, 10)}.${format}`;
      downloadBlob(resp.data, filenameFromDisposition(resp.headers?.['content-disposition'], fallback));
      showToast({
        type: 'success',
        message: templateOnly ? 'Sjabloon is afgelaai.' : 'Uitvoer is afgelaai.',
      });
    } catch (err) {
      let msg = err.message;
      if (err.response?.data instanceof Blob) {
        try {
          msg = JSON.parse(await err.response.data.text()).detail || msg;
        } catch (_) {}
      } else if (err.response?.data?.detail) {
        msg = err.response.data.detail;
      }
      showToast({ type: 'error', title: 'Uitvoer het misluk', message: msg });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Rekords invoer / uitvoer" size="xl">
      <div className="dx-tabs">
        <button
          type="button"
          className={`dx-tab ${tab === 'import' ? 'dx-active' : ''}`}
          onClick={() => setTab('import')}
        >
          ⬆ Invoer
        </button>
        <button
          type="button"
          className={`dx-tab ${tab === 'export' ? 'dx-active' : ''}`}
          onClick={() => setTab('export')}
        >
          ⬇ Uitvoer
        </button>
      </div>

      {tab === 'import' ? (
        <ImportWizard embedded isOpen={isOpen} onClose={onClose} defaultEntity={defaultEntity} onImported={onImported} />
      ) : (
        <div className="dx-export">
          <p className="iw-stepnote">
            Kies watter tabelle jy wil uitvoer en watter kolomme ingesluit moet word. Die lêer is
            in presies dieselfde formaat as wat die invoer verwag.
          </p>

          {!schema.length && <p className="iw-busy">Laai tabelle…</p>}

          {schema.map((s) => {
            const checked = selectedTables.includes(s.key);
            const sel = colSel[s.key];
            const missing = missingRequired(s.key);
            return (
              <div key={s.key} className={`dx-card ${checked ? 'dx-checked' : ''}`}>
                <label className="dx-tablehead">
                  <input type="checkbox" checked={checked} onChange={() => toggleTable(s.key)} />
                  <strong>{s.label}</strong>
                  <span className="dx-count">{sel ? `${sel.size}/${s.targets.length}` : s.targets.length} kolomme</span>
                </label>

                {checked && (
                  <>
                    <button
                      type="button"
                      className="iw-linkbtn"
                      onClick={() => setExpanded((prev) => ({ ...prev, [s.key]: !prev[s.key] }))}
                    >
                      {expanded[s.key] === false ? 'Wys kolomme' : 'Versteek kolomme'}
                    </button>
                    {(expanded[s.key] !== false) && (
                      <div className="dx-cols">
                        <div className="dx-colactions">
                          <button type="button" className="iw-linkbtn" onClick={() => setAllColumns(s.key, true)}>Kies alles</button>
                          <button type="button" className="iw-linkbtn" onClick={() => setAllColumns(s.key, false)}>Maak leeg</button>
                        </div>
                        {s.targets.map((t) => (
                          <label key={t.target} className="dx-col">
                            <input
                              type="checkbox"
                              checked={!sel || sel.has(t.target)}
                              onChange={() => toggleColumn(s.key, t.target)}
                            />
                            <span>
                              {t.kind === 'ref' ? '⟶ ' : ''}{t.label}{t.required ? ' *' : ''}
                            </span>
                          </label>
                        ))}
                      </div>
                    )}
                    {missing.length > 0 && (
                      <div className="iw-warning">
                        Verpligte kolomme geselekteer uitgelaat ({missing.map((m) => m.label).join(', ')}) — daardie rye sal faal by herinvoer.
                      </div>
                    )}
                  </>
                )}
              </div>
            );
          })}

          {selectedTables.includes('fault') && !templateOnly && (
            <div className="iw-warning">
              Gesluite foute word ingesluit. By herinvoer met “Slaan oor” tel gesluite foute nie as
              duplikate nie en word hulle as nuwe foute geskep.
            </div>
          )}

          <div className="dx-options">
            <div className="dx-option-group" role="radiogroup" aria-label="Formaat">
              <span className="dx-option-label">Formaat:</span>
              <label className={`dx-pill ${format === 'xlsx' ? 'dx-selected' : ''}`}>
                <input
                  type="radio"
                  name="dx-format"
                  value="xlsx"
                  checked={format === 'xlsx'}
                  onChange={() => setFormat('xlsx')}
                />
                XLSX (multi-blad)
              </label>
              <label className={`dx-pill ${format === 'csv' ? 'dx-selected' : ''}`}>
                <input
                  type="radio"
                  name="dx-format"
                  value="csv"
                  disabled={selectedTables.length !== 1}
                  checked={format === 'csv'}
                  onChange={() => setFormat('csv')}
                />
                CSV (een tabel)
              </label>
            </div>
            <label className="dx-template-toggle">
              <input
                type="checkbox"
                checked={templateOnly}
                onChange={(e) => setTemplateOnly(e.target.checked)}
              />
              Slegs kolomkoppe (leë sjabloon)
            </label>
          </div>

          <div className="dx-footer">
            <button
              type="button"
              className="btn-add"
              disabled={busy || !selectedTables.length}
              onClick={handleExport}
            >
              {busy
                ? 'Bou lêer…'
                : `${templateOnly ? 'Laai sjabloon' : 'Voer uit'} (${selectedTables.length} tabel${selectedTables.length === 1 ? '' : 'le'})`}
            </button>
          </div>
        </div>
      )}
    </Modal>
  );
}

export default ImportExportModal;
