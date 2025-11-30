/**
 * 数据导出工具
 *
 * 提供CSV、Excel、PDF等格式的数据导出功能
 */

// ==================== CSV导出 ====================

/**
 * 导出为CSV格式
 */
export function exportToCSV(data: any[], filename: string, headers?: string[]) {
  // 获取表头
  const csvHeaders = headers || (data.length > 0 ? Object.keys(data[0]) : []);

  // 生成CSV内容
  const csvContent = [
    // 表头行
    csvHeaders.join(','),
    // 数据行
    ...data.map(row =>
      csvHeaders
        .map(header => {
          const value = row[header];
          // 处理包含逗号或换行符的值
          if (typeof value === 'string' && (value.includes(',') || value.includes('\n'))) {
            return `"${value.replace(/"/g, '""')}"`;
          }
          return value ?? '';
        })
        .join(','),
    ),
  ].join('\n');

  // 创建Blob并下载
  const blob = new Blob([`\uFEFF${csvContent}`], { type: 'text/csv;charset=utf-8;' });
  downloadBlob(blob, `${filename}.csv`);
}

/**
 * 导出对象数组为CSV（带中文表头）
 */
export function exportToCSVWithMapping(
  data: any[],
  filename: string,
  fieldMapping: Record<string, string>,
) {
  const fields = Object.keys(fieldMapping);
  const headers = Object.values(fieldMapping);

  const csvContent = [
    // 表头行
    headers.join(','),
    // 数据行
    ...data.map(row =>
      fields
        .map(field => {
          const value = row[field];
          if (typeof value === 'string' && (value.includes(',') || value.includes('\n'))) {
            return `"${value.replace(/"/g, '""')}"`;
          }
          return value ?? '';
        })
        .join(','),
    ),
  ].join('\n');

  const blob = new Blob([`\uFEFF${csvContent}`], { type: 'text/csv;charset=utf-8;' });
  downloadBlob(blob, `${filename}.csv`);
}

// ==================== Excel导出 ====================

/**
 * 导出为Excel格式（简单版）
 * 注意：这是一个简化实现，实际项目中建议使用 xlsx 库
 */
export function exportToExcel(data: any[], filename: string, _sheetName = 'Sheet1') {
  if (data.length === 0) {
    console.warn('No data to export');
    return;
  }

  // 获取表头
  const headers = Object.keys(data[0]);

  // 创建HTML表格
  let html = '<html><head><meta charset="utf-8"></head><body>';
  html += '<table border="1">';

  // 表头
  html += '<thead><tr>';
  headers.forEach(header => {
    html += `<th>${header}</th>`;
  });
  html += '</tr></thead>';

  // 数据行
  html += '<tbody>';
  data.forEach(row => {
    html += '<tr>';
    headers.forEach(header => {
      html += `<td>${row[header] ?? ''}</td>`;
    });
    html += '</tr>';
  });
  html += '</tbody></table></body></html>';

  // 创建Blob并下载
  const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
  downloadBlob(blob, `${filename}.xls`);
}

/**
 * 导出为Excel（带字段映射）
 */
export function exportToExcelWithMapping(
  data: any[],
  filename: string,
  fieldMapping: Record<string, string>,
  _sheetName = 'Sheet1',
) {
  if (data.length === 0) {
    console.warn('No data to export');
    return;
  }

  const fields = Object.keys(fieldMapping);
  const headers = Object.values(fieldMapping);

  let html = '<html><head><meta charset="utf-8"></head><body>';
  html += '<table border="1">';

  // 表头
  html += '<thead><tr>';
  headers.forEach(header => {
    html += `<th>${header}</th>`;
  });
  html += '</tr></thead>';

  // 数据行
  html += '<tbody>';
  data.forEach(row => {
    html += '<tr>';
    fields.forEach(field => {
      html += `<td>${row[field] ?? ''}</td>`;
    });
    html += '</tr>';
  });
  html += '</tbody></table></body></html>';

  const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
  downloadBlob(blob, `${filename}.xls`);
}

// ==================== PDF导出 ====================

/**
 * 导出为PDF（简单版）
 * 注意：这需要浏览器的打印功能，实际项目中建议使用 jsPDF 或 pdfmake 库
 */
export function exportToPDF(title: string, content: HTMLElement | string) {
  const printWindow = window.open('', '_blank');
  if (!printWindow) {
    console.error('Failed to open print window');
    return;
  }

  const htmlContent = typeof content === 'string' ? content : content.outerHTML;

  printWindow.document.write(`
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>${title}</title>
        <style>
          @media print {
            @page { margin: 1cm; }
            body { margin: 0; }
            .no-print { display: none; }
          }
          body {
            font-family: Arial, sans-serif;
            font-size: 12px;
          }
          table {
            width: 100%;
            border-collapse: collapse;
          }
          th, td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
          }
          th {
            background-color: #f2f2f2;
          }
        </style>
      </head>
      <body>
        <h1>${title}</h1>
        ${htmlContent}
      </body>
    </html>
  `);

  printWindow.document.close();

  // 等待内容加载后打印
  setTimeout(() => {
    printWindow.print();
    printWindow.close();
  }, 250);
}

/**
 * 导出表格数据为PDF
 */
export function exportTableToPDF(
  data: any[],
  filename: string,
  headers: string[] | Record<string, string>,
) {
  const headerArray = Array.isArray(headers) ? headers : Object.values(headers);

  const fields = Array.isArray(headers) ? Object.keys(data[0] || {}) : Object.keys(headers);

  let html = '<table>';

  // 表头
  html += '<thead><tr>';
  headerArray.forEach(header => {
    html += `<th>${header}</th>`;
  });
  html += '</tr></thead>';

  // 数据行
  html += '<tbody>';
  data.forEach(row => {
    html += '<tr>';
    fields.forEach(field => {
      html += `<td>${row[field] ?? ''}</td>`;
    });
    html += '</tr>';
  });
  html += '</tbody></table>';

  exportToPDF(filename, html);
}

// ==================== 图表导出 ====================

/**
 * 导出ECharts图表为图片
 */
export function exportChartImage(
  chartInstance: any,
  filename: string,
  type: 'png' | 'jpeg' = 'png',
) {
  if (!chartInstance) {
    console.error('Chart instance is required');
    return;
  }

  try {
    // 获取图表的DataURL
    const dataURL = chartInstance.getDataURL({
      type,
      pixelRatio: 2,
      backgroundColor: '#fff',
    });

    // 下载图片
    const link = document.createElement('a');
    link.href = dataURL;
    link.download = `${filename}.${type}`;
    link.click();
  } catch (error) {
    console.error('Failed to export chart:', error);
  }
}

/**
 * 导出DOM元素为图片（使用html2canvas）
 * 注意：需要安装 html2canvas 库
 */
export async function exportElementToImage(
  _element: HTMLElement,
  _filename: string,
  _format: 'png' | 'jpeg' = 'png',
) {
  try {
    // 动态导入 html2canvas（如果已安装）
    // const html2canvas = await import('html2canvas');
    // const canvas = await html2canvas.default(element);
    // const dataURL = canvas.toDataURL(`image/${format}`);

    // 下载图片
    // const link = document.createElement('a');
    // link.href = dataURL;
    // link.download = `${filename}.${format}`;
    // link.click();

    console.warn('html2canvas is not installed. Please install it to use this feature.');
  } catch (error) {
    console.error('Failed to export element to image:', error);
  }
}

// ==================== 辅助函数 ====================

/**
 * 下载Blob对象
 */
function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * 格式化日期为字符串
 */
export function formatDateForExport(date: Date | string): string {
  const d = new Date(date);
  return d.toLocaleDateString('zh-CN');
}

/**
 * 格式化金额为字符串
 */
export function formatAmountForExport(amount: number, currency = 'CNY'): string {
  return `${currency} ${amount.toFixed(2)}`;
}

// ==================== 导出模板 ====================

/**
 * 交易记录导出模板
 */
export interface TransactionExportData {
  serialNum: string;
  date: string;
  type: string;
  category: string;
  amount: number;
  description?: string;
  member?: string;
}

export function exportTransactions(transactions: TransactionExportData[], filename = '交易记录') {
  const fieldMapping = {
    serialNum: '交易编号',
    date: '日期',
    type: '类型',
    category: '分类',
    amount: '金额',
    description: '描述',
    member: '成员',
  };

  exportToCSVWithMapping(transactions, filename, fieldMapping);
}

/**
 * 分摊记录导出模板
 */
export interface SplitRecordExportData {
  serialNum: string;
  transactionSerialNum: string;
  memberName: string;
  amount: number;
  isPaid: boolean;
  paidAt?: string;
}

export function exportSplitRecords(records: SplitRecordExportData[], filename = '分摊记录') {
  const fieldMapping = {
    serialNum: '分摊编号',
    transactionSerialNum: '交易编号',
    memberName: '成员',
    amount: '分摊金额',
    isPaid: '支付状态',
    paidAt: '支付时间',
  };

  const formattedRecords = records.map(record => ({
    ...record,
    isPaid: record.isPaid ? '已支付' : '未支付',
    paidAt: record.paidAt ? formatDateForExport(record.paidAt) : '',
  }));

  exportToCSVWithMapping(formattedRecords, filename, fieldMapping);
}

/**
 * 结算记录导出模板
 */
export interface SettlementRecordExportData {
  serialNum: string;
  type: string;
  totalAmount: number;
  optimizedAmount: number;
  status: string;
  createdAt: string;
}

export function exportSettlementRecords(
  records: SettlementRecordExportData[],
  filename = '结算记录',
) {
  const fieldMapping = {
    serialNum: '结算编号',
    type: '结算类型',
    totalAmount: '结算总额',
    optimizedAmount: '优化后金额',
    status: '状态',
    createdAt: '创建时间',
  };

  const formattedRecords = records.map(record => ({
    ...record,
    createdAt: formatDateForExport(record.createdAt),
  }));

  exportToCSVWithMapping(formattedRecords, filename, fieldMapping);
}
