import Papa from 'papaparse'

export interface ExportData {
  [key: string]: unknown
}

/**
 * Export data to CSV file
 * @param data Array of objects to export
 * @param filename Name of the file to download
 */
export function exportToCsv(data: ExportData[], filename: string): void {
  try {
    // Convert to CSV using papaparse
    const csv = Papa.unparse(data)

    // Create blob from CSV string
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })

    // Create temporary URL
    const url = URL.createObjectURL(blob)

    // Create and trigger download link
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    link.style.display = 'none'

    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)

    // Clean up
    URL.revokeObjectURL(url)
  } catch (error) {
    console.error('Export to CSV failed:', error)
    throw new Error('Failed to export data to CSV')
  }
}

/**
 * Format filename with sensor name, time range, and current date
 */
export function generateCsvFilename(
  sensor: string,
  timeRange: string,
  date: Date = new Date()
): string {
  const dateStr = date.toISOString().split('T')[0]
  const sanitized = sensor.toLowerCase().replace(/\s+/g, '-')
  return `greengains-data-${sanitized}-${timeRange}-${dateStr}.csv`
}

/**
 * Prepare sensor readings for CSV export.
 * Expects { timestamp, value } shape from the readings endpoint.
 */
export function prepareSensorDataForExport(
  rawData: Record<string, unknown>[],
  sensor = 'value'
) {
  const col = sensor.toLowerCase()
  return rawData.map((row) => ({
    timestamp: row.timestamp || row.time || new Date().toISOString(),
    [col]: row.value,
  }))
}
