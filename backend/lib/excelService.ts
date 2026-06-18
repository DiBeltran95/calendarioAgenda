import ExcelJS from 'exceljs';
import path from 'path';
import fs from 'fs';

// Calcular edad a partir de fecha de nacimiento
function calcularEdad(fecnac: string | null): number | string {
    if (!fecnac) return '';
    const nacimiento = new Date(fecnac);
    const hoy = new Date();
    let edad = hoy.getFullYear() - nacimiento.getFullYear();
    const mes = hoy.getMonth() - nacimiento.getMonth();
    if (mes < 0 || (mes === 0 && hoy.getDate() < nacimiento.getDate())) {
        edad--;
    }
    return edad;
}

/**
 * Genera el reporte Excel con trabajadores, cónyuges y beneficiarios
 * Exactamente igual al formato de 2 ReporteEmpresas
 */
export async function generateExcelReport(empresa: any, trabajadores: any[]) {
    // Crear workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Sistema Subsidio';
    workbook.created = new Date();

    const worksheet = workbook.addWorksheet('Empresas Trabajadores Beneficiarios', {
        views: [{ state: 'frozen', ySplit: 1 }]
    });

    // Definir columnas - igual que en 2 ReporteEmpresas
    worksheet.columns = [
        { header: 'Cedtra', key: 'cedtra', width: 12 },
        { header: 'Nombre Trabajador', key: 'nomtra', width: 35 },
        { header: 'Edad Trabajador', key: 'edadtra', width: 8 },
        { header: 'Telefono', key: 'teltra', width: 15 },
        { header: 'Cedcon', key: 'cedcon', width: 12 },
        { header: 'Nombre Conyuge', key: 'nomcon', width: 35 },
        { header: 'Edad Conyuge', key: 'edadcon', width: 8 },
        { header: 'TelConyuge', key: 'telcon', width: 15 },
        { header: 'CodBen', key: 'codben', width: 12 },
        { header: 'Nombre Beneficiario', key: 'nomben', width: 35 },
        { header: 'Edad Beneficiario', key: 'edadben', width: 8 },
        { header: 'FecIngreso', key: 'fecafi', width: 12 },
        { header: 'Cat', key: 'codcat', width: 6 },
        { header: 'Estado', key: 'estado', width: 8 }
    ];

    // Centrar horizontalmente las columnas que se combinan
    const columnasCentradas = ['cedtra', 'nomtra', 'edadtra', 'teltra', 'cedcon', 'nomcon', 'edadcon', 'telcon', 'codcat', 'estado'];
    columnasCentradas.forEach((key) => {
        const col = worksheet.getColumn(key);
        if (col) {
            col.alignment = { horizontal: 'center' };
        }
    });

    // Estilo del encabezado de columnas (fila 1)
    const row1 = worksheet.getRow(1);
    row1.font = { bold: true };
    row1.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFD9E1F2' }
    };
    row1.alignment = { horizontal: 'center' };

    let currentRow = 2;

    // Agregar fila de encabezado de empresa
    const empresaRow = worksheet.getRow(currentRow);
    empresaRow.getCell(1).value = `Empresa: ${empresa.nit} -- ${empresa.razsoc} | Direccion: ${empresa.diremp || ''} | Telefono: ${empresa.telemp || ''}`;
    worksheet.mergeCells(currentRow, 1, currentRow, 14); // A hasta N
    empresaRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    empresaRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF006C31' } // Verde personalizado
    };
    empresaRow.alignment = { horizontal: 'left' };
    currentRow++;

    if (trabajadores.length === 0) {
        const noDataRow = worksheet.addRow(['Sin trabajadores activos']);
        noDataRow.font = { italic: true, color: { argb: 'FF888888' } };
        worksheet.mergeCells(currentRow, 1, currentRow, 14);
        currentRow++;
    } else {
        for (const trabajador of trabajadores) {
            // Calcular edad del trabajador
            const edadTrabajador = calcularEdad(trabajador.fecnac);

            // Datos del cónyuge
            const conyuge = trabajador.conyuge;
            const edadConyuge = conyuge ? calcularEdad(conyuge.fecnac) : '';

            // Beneficiarios
            const beneficiarios = trabajador.beneficiarios || [];

            if (beneficiarios.length === 0) {
                // Trabajador sin beneficiarios
                worksheet.addRow({
                    cedtra: trabajador.cedtra,
                    nomtra: trabajador.nombre,
                    edadtra: edadTrabajador,
                    teltra: trabajador.telefono || '',
                    cedcon: conyuge ? conyuge.cedcon : '',
                    nomcon: conyuge ? conyuge.nombre : '',
                    edadcon: edadConyuge,
                    telcon: conyuge ? (conyuge.telefono || '') : '',
                    codben: '',
                    nomben: '',
                    edadben: '',
                    fecafi: trabajador.fecafi || '',
                    codcat: trabajador.codcat || '',
                    estado: trabajador.estado || ''
                });
                currentRow++;
            } else {
                const startRow = currentRow;

                for (let i = 0; i < beneficiarios.length; i++) {
                    const ben = beneficiarios[i];
                    const edadBen = calcularEdad(ben.fecnac);

                    worksheet.addRow({
                        cedtra: i === 0 ? trabajador.cedtra : '',
                        nomtra: i === 0 ? trabajador.nombre : '',
                        edadtra: i === 0 ? edadTrabajador : '',
                        teltra: i === 0 ? (trabajador.telefono || '') : '',
                        cedcon: i === 0 ? (conyuge ? conyuge.cedcon : '') : '',
                        nomcon: i === 0 ? (conyuge ? conyuge.nombre : '') : '',
                        edadcon: i === 0 ? edadConyuge : '',
                        telcon: i === 0 ? (conyuge ? (conyuge.telefono || '') : '') : '',
                        codben: ben.codben || ben.documento || '',
                        nomben: ben.nombre || '',
                        edadben: edadBen,
                        fecafi: ben.fecafi || trabajador.fecafi || '',
                        codcat: i === 0 ? (trabajador.codcat || '') : '',
                        estado: i === 0 ? (trabajador.estado || '') : ''
                    });
                    currentRow++;
                }

                // Combinar celdas del trabajador y de la cónyuge si tiene múltiples beneficiarios
                if (beneficiarios.length > 1) {
                    const endRow = currentRow - 1;
                    
                    // Combinar columnas del trabajador (cedtra, nomtra, edadtra, teltra)
                    worksheet.mergeCells(startRow, 1, endRow, 1); // Cedtra
                    worksheet.mergeCells(startRow, 2, endRow, 2); // Nombre Trabajador
                    worksheet.mergeCells(startRow, 3, endRow, 3); // Edad Trabajador
                    worksheet.mergeCells(startRow, 4, endRow, 4); // Telefono

                    // Combinar columnas de la cónyuge (cedcon, nomcon, edadcon, telcon)
                    worksheet.mergeCells(startRow, 5, endRow, 5); // Cedcon
                    worksheet.mergeCells(startRow, 6, endRow, 6); // Nombre Conyuge
                    worksheet.mergeCells(startRow, 7, endRow, 7); // Edad Conyuge
                    worksheet.mergeCells(startRow, 8, endRow, 8); // TelConyuge

                    worksheet.mergeCells(startRow, 13, endRow, 13); // Cat
                    worksheet.mergeCells(startRow, 14, endRow, 14); // Estado

                    // Alinear verticalmente al centro las celdas combinadas
                    for (let col = 1; col <= 8; col++) {
                        worksheet.getCell(startRow, col).alignment = { vertical: 'middle', horizontal: 'center' };
                    }
                    worksheet.getCell(startRow, 13).alignment = { vertical: 'middle', horizontal: 'center' };
                    worksheet.getCell(startRow, 14).alignment = { vertical: 'middle', horizontal: 'center' };
                }
            }
        }
    }

    // Aplicar bordes a todas las celdas con datos
    for (let row = 1; row < currentRow; row++) {
        for (let col = 1; col <= 14; col++) {
            const cell = worksheet.getCell(row, col);
            if (cell.value !== null && cell.value !== undefined) {
                cell.border = {
                    top: { style: 'thin' },
                    left: { style: 'thin' },
                    bottom: { style: 'thin' },
                    right: { style: 'thin' }
                };
            }
        }
    }

    // Generar nombre de archivo
    const timestamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
    const filename = `emtraben_${empresa.nit}_${timestamp}.xlsx`;
    
    // Directorio de salida
    const outputDir = path.join(__dirname, '..', 'downloads');
    
    // Crear directorio si no existe
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    const filePath = path.join(outputDir, filename);
    await workbook.xlsx.writeFile(filePath);

    return {
        filename: filename,
        filePath: filePath
    };
}
