export function calculateEaster(year: number): Date {
    const a = year % 19;
    const b = Math.floor(year / 100);
    const c = year % 100;
    const d = Math.floor(b / 4);
    const e = b % 4;
    const f = Math.floor((b + 8) / 25);
    const g = Math.floor((b - f + 1) / 3);
    const h = (19 * a + b - d - g + 15) % 30;
    const i = Math.floor(c / 4);
    const k = c % 4;
    const l = (32 + 2 * e + 2 * i - h - k) % 7;
    const m = Math.floor((a + 11 * h + 22 * l) / 451);
    const month = Math.floor((h + l - 7 * m + 114) / 31);
    const day = ((h + l - 7 * m + 114) % 31) + 1;
    return new Date(year, month - 1, day);
}

export function addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
}

export function getLastWeekdayOfMonth(year: number, month: number, targetDay: number): Date {
    const date = new Date(year, month, 0); // último día del mes
    while (date.getDay() !== targetDay) {
        date.setDate(date.getDate() - 1);
    }
    return date;
}

export function getNthWeekdayOfMonth(year: number, month: number, targetDay: number, n: number): Date | null {
    const date = new Date(year, month - 1, 1);
    let count = 0;
    while (date.getMonth() === month - 1) {
        if (date.getDay() === targetDay) {
            count++;
            if (count === n) {
                return new Date(date);
            }
        }
        date.setDate(date.getDate() + 1);
    }
    return null;
}

export function calculateImportantDate(rule: string, year: number): Date | null {
    if (!rule) return null;
    const [rawType, rawValue] = rule.split(':');
    const type = rawType && rawType.trim().toLowerCase();
    const value = rawValue && rawValue.trim();
    if (!type || !value) return null;

    if (type === 'fixed') {
        const [monthStr, dayStr] = value.split('-');
        const month = Number(monthStr);
        const day = Number(dayStr);
        if (!month || !day) return null;
        return new Date(year, month - 1, day);
    }

    const weekdayMap: Record<string, number> = {
        sunday: 0,
        monday: 1,
        tuesday: 2,
        wednesday: 3,
        thursday: 4,
        friday: 5,
        saturday: 6
    };

    if (Object.prototype.hasOwnProperty.call(weekdayMap, type)) {
        const [nStr, monthStr] = value.split('-');
        const month = Number(monthStr);
        if (!month) return null;
        const targetDay = weekdayMap[type];
        if (nStr === 'last') {
            return getLastWeekdayOfMonth(year, month, targetDay);
        }
        const n = Number(nStr);
        if (!n) return null;
        return getNthWeekdayOfMonth(year, month, targetDay, n);
    }

    if (type === 'easter') {
        const offset = Number(value) || 0;
        return addDays(calculateEaster(year), offset);
    }

    return null;
}
