import fs from 'fs';

const filePath = 'c:\\Users\\DiBeltran\\Music\\Calendario\\calendario-saas\\frontend\\src\\Dashboard.svelte';
const content = fs.readFileSync(filePath, 'utf-8');
const lines = content.split('\n');

lines.forEach((line, index) => {
    const lower = line.toLowerCase();
    if (lower.includes('presupuesto') || lower.includes('presupuestoslist')) {
        console.log(`${index + 1}: ${line.trim()}`);
    }
});
