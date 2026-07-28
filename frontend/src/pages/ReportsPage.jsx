import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import * as XLSX from 'xlsx';
import { apiClient, authAPI } from "../services/api";
import '../styles/App.css';
import '../styles/Reports.css';

const REPORT_TABLES = [
  { value: 'assets', label: 'Bates', endpoint: '/assets' },
  { value: 'stock', label: 'Voorraad', endpoint: '/stock' },
  { value: 'rooms', label: 'Lokale', endpoint: '/rooms' },
  { value: 'location', label: 'Terreine', endpoint: '/location' },
  { value: 'fault', label: 'Foutkaartjies', endpoint: '/fault' },
  { value: 'job', label: 'Werksopdragte', endpoint: '/job' },
  { value: 'users', label: 'Gebruikers', endpoint: '/users' },
  { value: 'quotes', label: 'Kwotasies', endpoint: '/quotes' }
];

const COLUMN_FALLBACKS = {
  assets: ['asset_id', 'asset_name', 'asset_serial', 'asset_isoutdoor', 'room_id', 'asset_status'],
  stock: ['stock_id', 'stock_name', 'stock_quantity', 'stock_status'],
  rooms: ['room_id', 'room_name', 'room_capacity', 'room_status'],
  location: ['location_id', 'location_name', 'location_type', 'location_status'],
  fault: ['fault_id', 'fault_title', 'fault_status', 'asset_id', 'created_at'],
  job: ['job_id', 'job_title', 'job_status', 'asset_id', 'assigned_to'],
  users: ['user_id', 'user_name', 'user_surname', 'user_email', 'role_id', 'user_status'],
  quotes: ['quote_id', 'quote_amount', 'quote_status', 'contractor_id', 'job_id']
};

function ReportsPage() {
  const [loading, setLoading] = useState(true);
  const [selectedTable, setSelectedTable] = useState('assets');
  const [availableColumns, setAvailableColumns] = useState([]);
  const [selectedColumns, setSelectedColumns] = useState([]);
  const [tableRecords, setTableRecords] = useState([]);
  const [loadingTable, setLoadingTable] = useState(false);
  const [reportHistory, setReportHistory] = useState([]);
  const [statusMessage, setStatusMessage] = useState('');

  useEffect(() => {
    (async () => {
      try {
        await authAPI.me();
        setLoading(false);
      } catch (err) {
        try { sessionStorage.clear(); localStorage.clear(); } catch (_) {}
        window.location.replace(window.location.origin + '/login');
      }
    })();
  }, []);

  useEffect(() => {
    const storedHistory = localStorage.getItem('reportCsvExports');
    if (storedHistory) {
      try {
        setReportHistory(JSON.parse(storedHistory));
      } catch (error) {
        console.error('Error loading report history:', error);
      }
    }
  }, []);

  const loadTableData = useCallback((tableName) => {
    const tableConfig = REPORT_TABLES.find((item) => item.value === tableName);
    if (!tableConfig) {
      return;
    }

    setLoadingTable(true);
    apiClient.get(tableConfig.endpoint)
      .then((response) => {
        const records = response.data || [];
        setTableRecords(records);
        const columns = getColumnsFromRecords(records, tableName);
        setAvailableColumns(columns);
        setSelectedColumns(columns);
      })
      .catch((error) => {
        console.error('Error loading table data:', error);
        setTableRecords([]);
        setAvailableColumns([]);
        setSelectedColumns([]);
        setStatusMessage('Kon die tabeldata nie laai nie.');
      })
      .finally(() => {
        setLoadingTable(false);
      });
  }, []);

  useEffect(() => {
    loadTableData(selectedTable);
  }, [loadTableData, selectedTable]);

  const getColumnsFromRecords = (records, tableName) => {
    if (Array.isArray(records) && records.length > 0) {
      const firstRecord = records[0];
      if (firstRecord && typeof firstRecord === 'object') {
        return Object.keys(firstRecord);
      }
    }
    return COLUMN_FALLBACKS[tableName] || [];
  };

  const toggleColumn = (columnName) => {
    setSelectedColumns((current) => {
      if (current.includes(columnName)) {
        return current.filter((column) => column !== columnName);
      }
      return [...current, columnName];
    });
  };

  const escapeCsvValue = (value) => {
    const stringValue = String(value ?? '');
    if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
      return `"${stringValue.replace(/"/g, '""')}"`;
    }
    return stringValue;
  };

  const buildCsvContent = () => {
    if (!selectedColumns.length) {
      return '';
    }

    const header = selectedColumns.map(escapeCsvValue).join(',');
    const rows = tableRecords.map((record) => {
      return selectedColumns.map((column) => escapeCsvValue(record[column])).join(',');
    });

    return [header, ...rows].join('\n');
  };

  const downloadTextFile = (content, fileName, mimeType) => {
    const blob = new Blob([content], { type: mimeType });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  };

  const downloadCsv = (csvContent, fileName) => {
    downloadTextFile(csvContent, fileName, 'text/csv;charset=utf-8;');
  };

  const downloadExcel = (buffer, fileName) => {
    const blob = new Blob([buffer], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;charset=utf-8;'
    });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  };

  const arrayBufferToBase64 = (buffer) => {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const chunkSize = 0x8000;
    for (let offset = 0; offset < bytes.length; offset += chunkSize) {
      const chunk = bytes.subarray(offset, offset + chunkSize);
      binary += Array.from(chunk, (byte) => String.fromCharCode(byte)).join('');
    }
    return window.btoa(binary);
  };

  const base64ToArrayBuffer = (base64) => {
    const binary = window.atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes.buffer;
  };

  const buildExcelBuffer = () => {
    const rows = [
      selectedColumns,
      ...tableRecords.map((record) => selectedColumns.map((column) => record[column] ?? ''))
    ];

    const worksheet = XLSX.utils.aoa_to_sheet(rows);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, selectedTableConfig?.label || selectedTable);
    return XLSX.write(workbook, { bookType: 'xlsx', type: 'array' });
  };

  const handleGenerateReport = (format = 'csv') => {
    if (!selectedColumns.length) {
      alert('Kies asseblief ten minste een kolom.');
      return;
    }

    const tableConfig = REPORT_TABLES.find((item) => item.value === selectedTable);
    const fileName = `${selectedTable}-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.${format === 'xlsx' ? 'xlsx' : 'csv'}`;

    if (format === 'xlsx') {
      const workbookBuffer = buildExcelBuffer();
      const entry = {
        id: Date.now(),
        fileName,
        createdAt: new Date().toLocaleString('af-ZA'),
        tableLabel: tableConfig?.label || selectedTable,
        columns: selectedColumns,
        format: 'xlsx',
        excelContentBase64: arrayBufferToBase64(workbookBuffer)
      };

      const updatedHistory = [entry, ...reportHistory].slice(0, 10);
      setReportHistory(updatedHistory);
      localStorage.setItem('reportCsvExports', JSON.stringify(updatedHistory));
      downloadExcel(workbookBuffer, fileName);
      setStatusMessage(`XLSX vir ${tableConfig?.label || selectedTable} is geskep.`);
      return;
    }

    const csvContent = buildCsvContent();
    const entry = {
      id: Date.now(),
      fileName,
      createdAt: new Date().toLocaleString('af-ZA'),
      tableLabel: tableConfig?.label || selectedTable,
      columns: selectedColumns,
      format: 'csv',
      csvContent
    };

    const updatedHistory = [entry, ...reportHistory].slice(0, 10);
    setReportHistory(updatedHistory);
    localStorage.setItem('reportCsvExports', JSON.stringify(updatedHistory));
    downloadCsv(csvContent, fileName);
    setStatusMessage(`CSV vir ${tableConfig?.label || selectedTable} is geskep.`);
  };

  const handleDownloadHistoryEntry = (entry) => {
    if (entry.format === 'xlsx' && entry.excelContentBase64) {
      const workbookBuffer = base64ToArrayBuffer(entry.excelContentBase64);
      downloadExcel(workbookBuffer, entry.fileName);
      return;
    }

    downloadCsv(entry.csvContent || '', entry.fileName);
  };

  const selectedTableConfig = REPORT_TABLES.find((item) => item.value === selectedTable);

  if (loading) {
    return (
      <div className="main">
        <div className="content">Laai...</div>
      </div>
    );
  }

  return (
    <div className="main">
      <div className="content">
          {statusMessage && <div className="report-status">{statusMessage}</div>}

          <div className="report-generator-card">
            <div className="report-generator-header">
              <h4>Genereer verslag</h4>
              <p>Kies 'n databasis-tabel en die kolomme wat jy wil insluit.</p>
            </div>

            <div className="report-controls">
              <label className="report-field">
                <span>Tabel</span>
                <select value={selectedTable} onChange={(e) => setSelectedTable(e.target.value)}>
                  {REPORT_TABLES.map((table) => (
                    <option key={table.value} value={table.value}>{table.label}</option>
                  ))}
                </select>
              </label>
              <div className="report-column-actions">
                <button type="button" className="btn-edit" onClick={() => setSelectedColumns(availableColumns)}>
                  Kies alles
                </button>
                <button type="button" className="btn-cancel" onClick={() => setSelectedColumns([])}>
                  Maak leeg
                </button>
              </div>
            </div>

            <div className="report-meta">
              <span>{selectedTableConfig?.label || selectedTable}</span>
              <span>{tableRecords.length} rekords</span>
            </div>

            {loadingTable ? (
              <div className="report-loading">Besig om data te laai...</div>
            ) : (
              <div className="report-columns-grid">
                {availableColumns.map((column) => (
                  <label key={column} className="report-column-option">
                    <input
                      type="checkbox"
                      checked={selectedColumns.includes(column)}
                      onChange={() => toggleColumn(column)}
                    />
                    <span>{column}</span>
                  </label>
                ))}
              </div>
            )}

            <div className="report-actions">
              <button type="button" className="btn-add" onClick={() => handleGenerateReport('csv')} disabled={loadingTable}>
                Genereer CSV
              </button>
              <button type="button" className="btn-edit" onClick={() => handleGenerateReport('xlsx')} disabled={loadingTable}>
                Genereer XLSX
              </button>
            </div>
          </div>

          {reportHistory.length > 0 && (
            <div className="report-history-card">
              <h4>Vorige verslag-lêers</h4>
              <ul className="report-history-list">
                {reportHistory.map((entry) => (
                  <li key={entry.id} className="report-history-item">
                    <div>
                      <strong>{entry.fileName}</strong>
                      <div className="report-history-meta">{entry.tableLabel} • {entry.columns.join(', ')}</div>
                      <div className="report-history-meta">{entry.createdAt}</div>
                    </div>
                    <button type="button" className="btn-edit" onClick={() => handleDownloadHistoryEntry(entry)}>
                      Laai weer
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
  );
}

export default ReportsPage;