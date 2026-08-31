import React, { useState, useEffect, useRef } from 'react';
import Modal from '../Modal/Modal';
import { importAPI } from '../../services/api';
import { useToast } from '../Toast/useToast';
import { downloadBlob } from '../../utils/fileDownload';
import { EXAMPLE_ROWS, EXAMPLE_NOTES } from './exampleData';
import './ImportWizard.css';

const DUP_OPTIONS = [
  {
    value: 'skip',
    label: 'Slaan oor',
    description: 'Bestaande rekords bly onveranderd; die invoer-ry word geignoreer.',
  },
  {
    value: 'update',
    label: 'Opdateer',
    description: 'Die bestaande rekord se velde word oorgeskryf met die ingevoerde waardes.',
  },
  {
    value: 'create',
    label: 'Skep nuut',
    description:
      "Maak 'n nuwe rekord langs die bestaande een (nuwe ID). Nie moontlik vir gebruikers nie.",
  },
];

function ImportWizard({ isOpen, onClose, defaultEntity = null, onImported, embedded = false }) {
  const { showToast } = useToast();
  const [step, setStep] = useState('upload');
  const [schema, setSchema] = useState([]);
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [sheets, setSheets] = useState([]);
  const [dupMode, setDupMode] = useState('skip');
  const [expandedSheet, setExpandedSheet] = useState(null);
  const [commitResult, setCommitResult] = useState(null);
  const [dragOver, setDragOver] = useState(false);
  const [showExample, setShowExample] = useState(false);
  const [exampleEntity, setExampleEntity] = useState(defaultEntity);
  const fileInputRef = useRef(null);

  useEffect(() => {
    if (!isOpen) return;
    setStep('upload');
    setFile(null);
    setSheets([]);
    setDupMode('skip');
    setCommitResult(null);
    setExpandedSheet(null);
    setBusy(false);
    setShowExample(false);
    setExampleEntity(defaultEntity);
    importAPI
      .schema()
      .then((r) => setSchema(r.data || []))
      .catch(() => {});
  }, [isOpen, defaultEntity]);

  const entityOptions = schema.map((s) => ({ value: s.key, label: s.label }));
  const targetsFor = (entityKey) => schema.find((s) => s.key === entityKey)?.targets || [];

  const totalsOf = (result) =>
    (result || []).reduce(
      (acc, t) => ({
        create: acc.create + t.counts.create,
        update: acc.update + t.counts.update,
        skip: acc.skip + t.counts.skip,
        error: acc.error + t.counts.error,
      }),
      { create: 0, update: 0, skip: 0, error: 0 }
    );

  const handleFileSelected = (f) => {
    if (!f) return;
    const name = (f.name || '').toLowerCase();
    if (!name.endsWith('.csv') && !name.endsWith('.xlsx') && !name.endsWith('.xlsm')) {
      showToast({ type: 'error', title: 'Ongeldige lêer', message: 'Kies .csv of .xlsx' });
      return;
    }
    setFile(f);
    runPreview(f, null).then((ok) => { if (ok) setStep('map'); });
  };

  const buildHints = (currentSheets) => {
    const hints = {};
    for (const s of currentSheets) {
      if (!s.entity) continue;
      const hint = { entity: s.entity };
      if (s.mappingTouched) hint.mapping = s.mapping;
      hints[s.sheet_name] = hint;
    }
    return hints;
  };

  const applyDefaultEntity = (incoming) => {
    if (!defaultEntity || incoming.length !== 1) return incoming;
    return incoming.map((sh) =>
      !sh.entity ? { ...sh, entity: defaultEntity, mappingTouched: false } : sh
    );
  };

  const runPreview = async (fileObj, currentSheets) => {
    setBusy(true);
    try {
      const hints = currentSheets ? buildHints(currentSheets) : undefined;
      const resp = await importAPI.preview(fileObj, hints);
      let incoming = (resp.data.sheets || []).map((sh) => ({
        ...sh,
        mappingTouched: Boolean(sh.mapping && Object.keys(sh.mapping).length > 0),
      }));
      if (!currentSheets) {
        incoming = applyDefaultEntity(incoming);
      } else {
        incoming = incoming.map((sh) => {
          const prior = currentSheets.find((c) => c.sheet_name === sh.sheet_name);
          if (prior && prior.entity) {
            return {
              ...sh,
              entity: prior.entity,
              mapping: prior.mappingTouched ? prior.mapping : sh.mapping,
              mappingTouched: prior.mappingTouched,
            };
          }
          return sh;
        });
      }
      setSheets(incoming);
      return true;
    } catch (err) {
      showToast({
        type: 'error',
        title: 'Kon lêer nie verwerk nie',
        message: err.response?.data?.detail || err.message,
      });
      return false;
    } finally {
      setBusy(false);
    }
  };

  const updateSheet = (sheetName, patch) =>
    setSheets((prev) => prev.map((s) => (s.sheet_name === sheetName ? { ...s, ...patch } : s)));

  const changeEntity = (sheetName, newEntity) => {
    updateSheet(sheetName, {
      entity: newEntity || null,
      mapping: {},
      mappingTouched: false,
      missing_required: [],
    });
  };

  const changeMapping = (sheetName, column, target) => {
    setSheets((prev) =>
      prev.map((s) => {
        if (s.sheet_name !== sheetName) return s;
        const mapping = { ...s.mapping };
        if (target) {
          Object.keys(mapping).forEach((h) => {
            if (mapping[h] === target && h !== column) delete mapping[h];
          });
          mapping[column] = target;
        } else {
          delete mapping[column];
        }
        return { ...s, mapping, mappingTouched: true };
      })
    );
  };

  const goToPreview = async () => {
    if (!sheets.some((s) => s.entity)) {
      showToast({ type: 'info', title: 'Niks gekies nie', message: 'Wijs minstens een blad toe' });
      return;
    }
    const ok = await runPreview(file, sheets);
    if (ok) setStep('preview');
  };

  const runCommit = async () => {
    setBusy(true);
    try {
      const payload = {
        duplicate_mode: dupMode,
        tables: sheets
          .filter((s) => s.entity)
          .map((s) => ({
            entity: s.entity,
            sheet_name: s.sheet_name,
            mapping: s.mapping,
            rows: s.rows.map((r) => ({ row_number: r.row_number, values: r.values })),
          })),
      };
      const resp = await importAPI.commit(payload);
      setCommitResult(resp.data);
      setStep('done');
      const t = totalsOf(resp.data.tables);
      showToast({
        type: t.error > 0 ? 'info' : 'success',
        title: 'Invoer voltooi',
        message: `${t.create} geskep, ${t.update} opgedateer, ${t.skip} oorgeslaan, ${t.error} foute`,
      });
      onImported?.(resp.data);
    } catch (err) {
      showToast({
        type: 'error',
        title: 'Invoer het misluk',
        message: err.response?.data?.detail || err.message,
      });
    } finally {
      setBusy(false);
    }
  };

  const assignedCount = sheets.filter((s) => s.entity).length;

  const effectiveExampleEntity =
    exampleEntity || defaultEntity || (schema[0] && schema[0].key) || null;
  const example = EXAMPLE_ROWS[effectiveExampleEntity];

  const downloadTemplate = async () => {
    if (!effectiveExampleEntity) return;
    setBusy(true);
    try {
      const resp = await importAPI.exportData({
        format: 'csv',
        template: true,
        tables: [{ entity: effectiveExampleEntity }],
      });
      const label = (schema.find((s) => s.key === effectiveExampleEntity) || {}).label
        || effectiveExampleEntity;
      downloadBlob(
        new Blob([resp.data], { type: 'text/csv;charset=utf-8;' }),
        `${label.replace(/[^a-zA-Z0-9]+/g, '-')}-sjabloon.csv`
      );
    } catch (err) {
      showToast({
        type: 'error',
        title: 'Kon nie sjabloon aflaai nie',
        message: err.response?.data?.detail || err.message,
      });
    } finally {
      setBusy(false);
    }
  };

  const renderExample = () => (
    <div className="iw-example">
      <button type="button" className="iw-example-toggle" onClick={() => setShowExample(!showExample)}>
        <span className={`iw-caret ${showExample ? 'iw-open' : ''}`}>▸</span>
        Voorbeeld van verwagte data
      </button>
      {showExample && (
        <div className="iw-example-body">
          <div className="iw-example-controls">
            <select
              value={effectiveExampleEntity || ''}
              onChange={(e) => setExampleEntity(e.target.value)}
            >
              {schema.map((s) => (
                <option key={s.key} value={s.key}>{s.label}</option>
              ))}
            </select>
            <button type="button" className="btn-edit" disabled={busy} onClick={downloadTemplate}>
              ⬇ Laai sjabloon af (CSV)
            </button>
          </div>
          {example && (
            <>
              <div className="iw-tablewrap">
                <table className="iw-example-table">
                  <thead>
                    <tr>
                      {example.columns.map((col, i) => (
                        <th key={col}>{example.refs[i] ? '⟶ ' : ''}{col}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {example.rows.map((row, ri) => (
                      <tr key={ri}>
                        {row.map((val, ci) => (
                          <td key={ci}>{val || <span className="iw-empty">—</span>}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <ul className="iw-notes">
                {EXAMPLE_NOTES.map((n) => (
                  <li key={n}>{n}</li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </div>
  );

  const renderUpload = () => (
    <div className="iw-upload">
      <div
        className={`iw-dropzone ${dragOver ? 'iw-dragover' : ''}`}
        onClick={() => fileInputRef.current?.click()}
        onDragOver={(e) => {
          e.preventDefault();
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          handleFileSelected(e.dataTransfer.files?.[0]);
        }}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept=".csv,.xlsx,.xlsm"
          style={{ display: 'none' }}
          onChange={(e) => handleFileSelected(e.target.files?.[0])}
        />
        <div className="iw-dropzone-icon">⬆</div>
        <div className="iw-dropzone-text">
          <strong>Sleep .csv / .xlsx hierheen</strong>
          <span>of klik om 'n lêer te kies</span>
        </div>
        <p className="iw-dropzone-hint">
          Een werkboek mag verskeie bladsye hê — elke blad kan na 'n ander tabel wys (bv. Kampe,
          Geboue, Kamers, Aktiwiteite).
        </p>
        {busy && <p className="iw-busy">Ontleed lêer…</p>}
      </div>
      {renderExample()}
    </div>
  );

  const renderMap = () => (
    <div className="iw-map">
      <p className="iw-stepnote">
        Wijs elke blad aan tabel toe en kontroleer kolomme. Verwysings (⟶) word volgens naam/kode
        opgesoek; rye wat nie opgelos kan word nie, word as fout gemerk.
      </p>
      {sheets.map((sheet) => (
        <div key={sheet.sheet_name} className="iw-sheetcard">
          <div className="iw-sheethead">
            <span className="iw-sheetname">{sheet.sheet_name}</span>
            <span className="iw-rowcount">{sheet.total_rows} rye</span>
            <select
              className="iw-entityselect"
              value={sheet.entity || ''}
              onChange={(e) => changeEntity(sheet.sheet_name, e.target.value)}
            >
              <option value="">— Ignoreer —</option>
              {entityOptions.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>

          {sheet.entity && (
            <>
              <table className="iw-maptable">
                <thead>
                  <tr>
                    <th>Lêerkolom</th>
                    <th>Databankveld</th>
                  </tr>
                </thead>
                <tbody>
                  {sheet.columns.map((col) => (
                    <tr key={col} className={sheet.mapping[col] ? '' : 'iw-unmapped'}>
                      <td>{col}</td>
                      <td>
                        <select
                          value={sheet.mapping[col] || ''}
                          onChange={(e) => changeMapping(sheet.sheet_name, col, e.target.value)}
                        >
                          <option value="">— Nie toegewys —</option>
                          {targetsFor(sheet.entity).map((t) => (
                            <option key={t.target} value={t.target}>
                              {t.kind === 'ref' ? '⟶ ' : ''}
                              {t.label}
                              {t.required ? ' *' : ''}
                            </option>
                          ))}
                        </select>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {(sheet.missing_required || []).length > 0 && (
                <div className="iw-warning">
                  Nie alle verpligte velde is toegewys ({sheet.missing_required.join(', ')}) — daardie
                  rye sal faal.
                </div>
              )}
            </>
          )}
        </div>
      ))}
    </div>
  );

  const renderPreview = () => {
    const tables = sheets.filter((s) => s.entity);
    const totals = totalsOf(tables.map((t) => ({ counts: t.counts })));
    return (
      <div className="iw-preview">
        <div className="iw-totals">
          <span className="iw-badge iw-badge-create">{totals.create} gaan skep</span>
          <span className="iw-badge iw-badge-update">{totals.update} gaan opdateer</span>
          <span className="iw-badge iw-badge-skip">{totals.skip} gaan slaan</span>
          <span className="iw-badge iw-badge-error">{totals.error} foute</span>
        </div>

        {tables.map((t) => (
          <div key={t.sheet_name} className="iw-previewcard">
            <div className="iw-previewhead">
              <strong>{(entityOptions.find((o) => o.value === t.entity) || {}).label || t.entity}</strong>
              <span className="iw-previewmeta">
                blad “{t.sheet_name}” · {t.counts.create} skep · {t.counts.update} opdateer ·{' '}
                {t.counts.skip} slaan · {t.counts.error} foute
              </span>
              {t.counts.error > 0 && (
                <button
                  type="button"
                  className="iw-linkbtn"
                  onClick={() =>
                    setExpandedSheet(expandedSheet === t.sheet_name ? null : t.sheet_name)
                  }
                >
                  {expandedSheet === t.sheet_name ? 'Versteek foute' : 'Wys foute'}
                </button>
              )}
            </div>
            {expandedSheet === t.sheet_name && t.counts.error > 0 && (
              <table className="iw-errortable">
                <thead>
                  <tr>
                    <th>Ry</th>
                    <th>Probleem</th>
                  </tr>
                </thead>
                <tbody>
                  {t.rows
                    .filter((r) => r.status === 'error')
                    .slice(0, 50)
                    .map((r) => (
                      <tr key={r.row_number}>
                        <td>{r.row_number}</td>
                        <td>{r.reason}</td>
                      </tr>
                    ))}
                </tbody>
              </table>
            )}
          </div>
        ))}

        <div className="iw-dupmode">
          <h4>Duplikaat hantering</h4>
          {DUP_OPTIONS.map((opt) => (
            <label
              key={opt.value}
              className={`iw-dupoption ${dupMode === opt.value ? 'iw-selected' : ''}`}
            >
              <input
                type="radio"
                name="dupmode"
                checked={dupMode === opt.value}
                onChange={() => setDupMode(opt.value)}
              />
              <span>
                <strong>{opt.label}</strong>
                <em>{opt.description}</em>
              </span>
            </label>
          ))}
        </div>
      </div>
    );
  };

  const renderDone = () => {
    const totals = totalsOf(commitResult?.tables);
    return (
      <div className="iw-done">
        <div className={`iw-done-icon ${totals.error > 0 ? 'iw-partial' : ''}`}>✓</div>
        <h3>Invoer voltooi</h3>
        <div className="iw-totals">
          <span className="iw-badge iw-badge-create">{totals.create} geskep</span>
          <span className="iw-badge iw-badge-update">{totals.update} opgedateer</span>
          <span className="iw-badge iw-badge-skip">{totals.skip} oorgeslaan</span>
          <span className="iw-badge iw-badge-error">{totals.error} foute</span>
        </div>
        {(commitResult?.tables || [])
          .filter((t) => t.counts.error > 0)
          .map((t) => (
            <details key={`${t.entity}-${t.sheet_name}`} className="iw-done-errors">
              <summary>
                {t.label}: {t.counts.error} foute
              </summary>
              <ul>
                {t.rows.slice(0, 30).map((r) => (
                  <li key={r.row_number}>
                    Ry {r.row_number}: {r.reason}
                  </li>
                ))}
              </ul>
            </details>
          ))}
      </div>
    );
  };

  const renderFooter = () => {
    if (step === 'upload') return null;
    if (step === 'map')
      return (
        <>
          <button className="btn-cancel" disabled={busy} onClick={() => setStep('upload')}>
            Terug
          </button>
          <button
            className="btn-add"
            disabled={busy || assignedCount === 0}
            onClick={goToPreview}
          >
            {busy ? 'Bereken voorskou…' : `Volgende: Voorskou (${assignedCount})`}
          </button>
        </>
      );
    if (step === 'preview') {
      const totals = totalsOf(sheets.filter((s) => s.entity).map((t) => ({ counts: t.counts })));
      return (
        <>
          <button className="btn-cancel" disabled={busy} onClick={() => setStep('map')}>
            Terug na toewysing
          </button>
          <button
            className="btn-add"
            disabled={busy || totals.create + totals.update === 0}
            onClick={runCommit}
          >
            {busy ? 'Voer in…' : `Voer in (${totals.create + totals.update} rye)`}
          </button>
        </>
      );
    }
    return (
      <button className="btn-add" onClick={onClose}>
        Sluit
      </button>
    );
  };

  const body = (
    <>
      {step !== 'upload' && step !== 'done' && (
        <div className="iw-stepsbar">
          <span className={step === 'map' ? 'iw-active' : ''}>1. Toewysing &amp; kolomme</span>
          <span className={step === 'preview' ? 'iw-active' : ''}>2. Voorskou &amp; invoer</span>
        </div>
      )}
      {step === 'upload' && renderUpload()}
      {step === 'map' && renderMap()}
      {step === 'preview' && renderPreview()}
      {step === 'done' && renderDone()}
      <div className="iw-footer">{renderFooter()}</div>
    </>
  );

  if (embedded) {
    return <div className="iw-panel">{body}</div>;
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Data-invoer (CSV / XLSX)" size="xl">
      {body}
    </Modal>
  );
}

export default ImportWizard;
