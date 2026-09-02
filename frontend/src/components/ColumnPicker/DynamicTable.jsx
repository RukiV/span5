import React, { useRef, useCallback } from 'react';
import useColumnVisibility from '../../hooks/useColumnVisibility';
import ColumnPicker from './ColumnPicker';

/**
 * DynamicTable — Renders a fully sortable & column-pickable table.
 *
 * Usage:
 *   const COLUMNS = [
 *     { key: 'id',    label: 'ID',  render: (r) => r.id,                         sortKey: 'id', defaultVisible: true },
 *     { key: 'name',  label: 'Naam',render: (r) => r.name,                       sortKey: 'name' },
 *     { key: 'status',label: 'Status',render: (r) => <StatusBadge status={r.status}/>, sortKey: 'status' },
 *   ];
 *
 *   <DynamicTable
 *     storageKey="my-page"
 *     columns={COLUMNS}
 *     data={filteredData}
 *     sortProps={{ handleSort, sortKey, sortDirection, getSortIndicator, getSortClass }}
 *     onRowClick={(item) => handleEdit(item)}
 *     actions={(item) => <button onClick={...}>Verwyder</button>}
 *     emptyMessage="Geen data gevind"
 *   />
 */
export default function DynamicTable({
  storageKey,
  columns,
  data = [],
  sortProps = {},
  onRowClick,
  actions,
  actionsLabel = 'Aksies',
  emptyMessage = 'Geen data gevind',
  extraControls, // Extra JSX to put next to the ColumnPicker button
}) {
  const columnPickerRef = useRef(null);
  const { visibleColumns, toggleColumn, resetVisibility, columnDefs } =
    useColumnVisibility(storageKey, columns);

  const btnRef = useRef(null);
  const { handleSort, getSortIndicator, getSortClass } = sortProps;

  // Right-click handler
  const onHeaderContextMenu = useCallback((e, colKey) => {
    e.preventDefault();
    columnPickerRef.current?.onHeaderContextMenu?.(e, colKey);
  }, []);

  const colPickerBtnRef = useRef(null);

  return (
    <>
      <div className="controls-right">
        {extraControls}
        <ColumnPicker
          ref={columnPickerRef}
          columns={columnDefs}
          visibleColumns={visibleColumns.map(c => c)}
          toggleColumn={toggleColumn}
          resetVisibility={resetVisibility}
          buttonRef={colPickerBtnRef}
        />
      </div>

      <table className="standard-table">
        <thead>
          <tr>
            {visibleColumns.map((col) => (
              <th
                key={col.key}
                className={col.sortKey && getSortClass ? getSortClass(col.sortKey) : ''}
                onClick={() => col.sortKey && handleSort && handleSort(col.sortKey)}
                onContextMenu={(e) => onHeaderContextMenu(e, col.key)}
                style={col.width ? { width: col.width } : undefined}
              >
                {col.label}
                {col.sortKey && getSortIndicator && getSortIndicator(col.sortKey)}
              </th>
            ))}
            {actions && <th style={actions ? { width: '120px' } : undefined}>{actionsLabel}</th>}
          </tr>
        </thead>
        <tbody>
          {data.length === 0 ? (
            <tr>
              <td colSpan={visibleColumns.length + (actions ? 1 : 0)} style={{ textAlign: 'center', padding: '20px' }}>
                {emptyMessage}
              </td>
            </tr>
          ) : (
            data.map((item, idx) => (
              <tr
                key={item.id || item[Object.keys(item)[0]] || idx}
                onClick={() => onRowClick && onRowClick(item)}
                style={onRowClick ? { cursor: 'pointer' } : undefined}
              >
                {visibleColumns.map((col) => (
                  <td key={col.key}>{col.render ? col.render(item) : item[col.key]}</td>
                ))}
                {actions && <td onClick={(e) => e.stopPropagation()}>{actions(item)}</td>}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </>
  );
}
