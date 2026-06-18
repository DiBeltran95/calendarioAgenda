// Utility functions for Menstrual Cycle calculations, ported exactly from legacy app.js

export function getCyclePhase(dateStr: string, cycleLogs: any[], cycleLength = 28, periodLength = 5) {
    if (!cycleLogs || cycleLogs.length === 0) return null;

    // Sort logs descending
    const logs = [...cycleLogs].sort((a, b) => new Date(b.fecha_inicio).getTime() - new Date(a.fecha_inicio).getTime());
    const targetDate = new Date(dateStr + 'T00:00:00');

    let currentLog = null;
    let nextLog = null;
    
    for (let i = 0; i < logs.length; i++) {
        if (new Date(logs[i].fecha_inicio + 'T00:00:00') <= targetDate) {
            currentLog = logs[i];
            if (i > 0) {
                nextLog = logs[i - 1];
            }
            break;
        }
    }

    if (!currentLog) return null;

    const startDate = new Date(currentLog.fecha_inicio + 'T00:00:00');
    const diffTime = Math.abs(targetDate.getTime() - startDate.getTime());
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    const dayOfCycle = diffDays + 1;

    // Si hay un ciclo siguiente (histórico)
    if (nextLog) {
        const nextDate = new Date(nextLog.fecha_inicio + 'T00:00:00');
        const cycleDiffTime = Math.abs(nextDate.getTime() - startDate.getTime());
        const actualCycleLength = Math.floor(cycleDiffTime / (1000 * 60 * 60 * 24));
        
        if (dayOfCycle <= periodLength) return 'period';

        let predictedCycleLength = cycleLength;
        const logIndex = logs.indexOf(currentLog);
        if (logs.length - 1 > logIndex) {
            let totalDays = 0, validCycles = 0;
            for (let j = logIndex; j < logs.length - 1; j++) {
                const end = new Date(logs[j].fecha_inicio + 'T00:00:00');
                const start = new Date(logs[j+1].fecha_inicio + 'T00:00:00');
                const days = Math.floor(Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
                if (days >= 20 && days <= 45) { totalDays += days; validCycles++; }
            }
            if (validCycles > 0) {
                let average = totalDays / validCycles;
                if (validCycles < 3) {
                    const standardDays = 28;
                    const weight = 3 - validCycles;
                    average = (totalDays + weight * standardDays) / 3;
                }
                predictedCycleLength = Math.round(average);
            }
        }

        if (dayOfCycle >= predictedCycleLength + 1 && dayOfCycle <= predictedCycleLength + periodLength) {
            return 'predicted-period';
        }
        
        const ovulationDay = actualCycleLength - 14;
        if (dayOfCycle === ovulationDay) return 'ovulation';
        if (dayOfCycle >= ovulationDay - 5 && dayOfCycle <= ovulationDay + 1) return 'fertile';
        
        return 'luteal';
    }

    // Ciclo actual o futuro
    let calcCycleLength = cycleLength;
    
    if (logs.length >= 2) {
        let totalDays = 0;
        let validCycles = 0;
        for (let i = 0; i < logs.length - 1; i++) {
            const end = new Date(logs[i].fecha_inicio + 'T00:00:00');
            const start = new Date(logs[i+1].fecha_inicio + 'T00:00:00');
            const days = Math.floor(Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
            if (days >= 20 && days <= 45) {
                totalDays += days;
                validCycles++;
            }
        }
        if (validCycles > 0) {
            let average = totalDays / validCycles;
            if (validCycles < 3) {
                const standardDays = 28;
                const weight = 3 - validCycles;
                average = (totalDays + weight * standardDays) / 3;
            }
            calcCycleLength = Math.round(average);
        }
    }

    const isPredictedCycle = dayOfCycle > calcCycleLength;
    const dayInCurrentCycle = ((dayOfCycle - 1) % calcCycleLength) + 1;

    if (dayInCurrentCycle <= periodLength) {
        return isPredictedCycle ? 'predicted-period' : 'period';
    }

    const ovulationDay = calcCycleLength - 14;
    if (dayInCurrentCycle === ovulationDay) return 'ovulation';
    if (dayInCurrentCycle >= ovulationDay - 5 && dayInCurrentCycle <= ovulationDay + 1) return 'fertile';

    return 'luteal';
}

// Funciones de consejos exportadas o locales
const tipsMenstruation = [
    "Día 1: Tu cuerpo está trabajando intensamente hoy. Si experimentas cólicos, no te exijas al 100%. Date el permiso de ir a tu propio ritmo, tomar algo caliente y priorizar lo más urgente en tu día.",
    "Día 2: Es normal sentir un bajón de energía hoy. Trata de incluir en tus comidas hierro extra (como espinacas, lentejas o carne) para compensar la pérdida y evitar el cansancio extremo.",
    "Día 3: La pesadez suele empezar a disminuir. Hoy puede ser un buen momento para una caminata corta y respirar profundo. Tu intuición está muy conectada, escúchala.",
    "Día 4: Vas recuperando la energía poco a poco. Puedes retomar algunas tareas que habías pospuesto. Recuerda mantenerte muy bien hidratada.",
    "Día 5: Tu mente comienza a sentirse más despejada y ligera. Si haces ejercicio, puedes subir levemente la intensidad. ¡Celebra este nuevo aire!",
    "Día 6+: Tu periodo está terminando o ha terminado. Empiezas a sentirte lista para la acción. Aprovecha para organizar tus metas para las próximas semanas."
];

const tipsFollicular = [
    "A medida que sube tu estrógeno, notarás un impulso en tu estado de ánimo. Hoy es un día ideal para planificar proyectos nuevos y ser creativa.",
    "Te sientes más resiliente y social. Si tienes una reunión importante, una presentación o quieres salir, tu carisma natural jugará a tu favor.",
    "Estás en una fase de alta productividad. Aprovecha tu concentración para sacar adelante tareas complejas o aprender algo nuevo.",
    "Tu piel luce mejor y tienes más resistencia física. Es un gran día para entrenamientos de fuerza o actividades que te reten un poco más."
];

const tipsFertile = [
    "Inicia tu ventana fértil. Tu libido puede empezar a subir naturalmente y tus sentidos se agudizan. Disfruta de esta conexión con tu cuerpo.",
    "Estás brillando. Biológicamente tu cuerpo te prepara para la ovulación, dándote un magnetismo especial. Si no deseas embarazo, maximiza tus precauciones.",
    "Tienes gran fluidez verbal y facilidad para conectar con otras personas. Hoy eres un imán natural, excelente para el trabajo en equipo o ventas.",
    "Tu nivel de energía está cerca del máximo. Físicamente te sientes fuerte, por lo que puedes disfrutar de actividades intensas o aventureras.",
    "Pico estrogénico a la vista. Confía en tu intuición y agilidad mental hoy; tu cerebro está trabajando a toda velocidad.",
    "Estás a un paso de la ovulación. Es normal notar mayor flujo cervical. Te sientes plena, segura y capaz de cualquier cosa."
];

const tipOvulation = "¡Día de ovulación! Estás en la cima de tu ciclo. Tu confianza, energía vital y sociabilidad están al máximo. Aprovecha para brillar en cualquier ámbito, pero cuídate si tu objetivo no es concebir.";

const tipsLuteal = [
    "La ovulación ha pasado y empiezas una transición. Es momento de enfocar tu energía hacia adentro. Ideal para trabajos detallados y de escritorio.",
    "Tu metabolismo está ligeramente acelerado, pero también pueden surgir antojos. Mantén snacks saludables a la mano, como nueces o fruta oscura.",
    "Si empiezas a sentir que tu paciencia disminuye, recuerda que es normal por el aumento de progesterona. Respira y no te tomes todo personal.",
    "Es un buen momento para ordenar tu espacio, organizar tu casa o tu oficina. El cuerpo busca el 'nido' y el orden te dará paz mental.",
    "Si notas tensión emocional o sensibilidad (SPM), reduce la cafeína y la sal. Un baño caliente y un libro pueden ser tu mejor medicina hoy."
];

export function getCycleDetails(dateStr: string, cycleLogs: any[], cycleLength = 28, periodLength = 5) {
    if (!cycleLogs || cycleLogs.length === 0) return null;

    const logs = [...cycleLogs].sort((a, b) => new Date(b.fecha_inicio).getTime() - new Date(a.fecha_inicio).getTime());
    const targetDate = new Date(dateStr + 'T00:00:00');

    let currentLog = null;
    let nextLog = null;
    
    for (let i = 0; i < logs.length; i++) {
        if (new Date(logs[i].fecha_inicio + 'T00:00:00') <= targetDate) {
            currentLog = logs[i];
            if (i > 0) nextLog = logs[i - 1];
            break;
        }
    }

    if (!currentLog) return null;

    const startDate = new Date(currentLog.fecha_inicio + 'T00:00:00');
    const diffTime = Math.abs(targetDate.getTime() - startDate.getTime());
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    const dayOfCycle = diffDays + 1;

    let calcCycleLength = cycleLength;
    if (logs.length >= 2) {
        let totalDays = 0, validCycles = 0;
        for (let i = 0; i < logs.length - 1; i++) {
            const end = new Date(logs[i].fecha_inicio + 'T00:00:00');
            const start = new Date(logs[i+1].fecha_inicio + 'T00:00:00');
            const days = Math.floor(Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
            if (days >= 20 && days <= 45) { totalDays += days; validCycles++; }
        }
        if (validCycles > 0) {
            let average = totalDays / validCycles;
            if (validCycles < 3) {
                average = (totalDays + (3 - validCycles) * 28) / 3;
            }
            calcCycleLength = Math.round(average);
        }
    }

    const actualCycleLength = nextLog ? Math.floor(Math.abs(new Date(nextLog.fecha_inicio + 'T00:00:00').getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) : calcCycleLength;

    const ovulationDay = actualCycleLength - 14;
    let isPredictedPeriod = false;
    let phaseKey = 'luteal';
    
    let dayInCurrentCycle = dayOfCycle;
    if (!nextLog && dayOfCycle > actualCycleLength) {
        dayInCurrentCycle = ((dayOfCycle - 1) % actualCycleLength) + 1;
        if (dayInCurrentCycle <= periodLength) isPredictedPeriod = true;
    } else if (nextLog && dayOfCycle > actualCycleLength) {
        // Historically, if day is beyond the actual cycle length, it technically shouldn't happen because it belongs to nextLog
        dayInCurrentCycle = actualCycleLength; // just cap it
    }

    if (dayInCurrentCycle <= periodLength && !isPredictedPeriod) phaseKey = 'period';
    else if (isPredictedPeriod) phaseKey = 'predicted-period';
    else if (dayInCurrentCycle === ovulationDay) phaseKey = 'ovulation';
    else if (dayInCurrentCycle >= ovulationDay - 5 && dayInCurrentCycle <= ovulationDay + 1) phaseKey = 'fertile';
    else if (dayInCurrentCycle < ovulationDay - 5) phaseKey = 'follicular';
    else phaseKey = 'luteal';

    let phase = 'Fase Lútea';
    let fertilityChance = 'Baja';
    let fertilityColor = '#03a9f4';
    let description = '';

    if (isPredictedPeriod) {
        phase = 'Periodo Previsto (Retraso)';
        fertilityChance = 'Baja';
        fertilityColor = '#03a9f4';
        description = 'Este es el día en que tu periodo estaba previsto pero experimentaste un retraso o cambio en tu ciclo. El estrés, cambios de rutina o alteraciones hormonales son causas comunes.';
    } else if (phaseKey === 'period') {
        phase = 'Menstruación';
        fertilityChance = 'Baja';
        fertilityColor = '#03a9f4';
        description = tipsMenstruation[Math.min(dayInCurrentCycle - 1, tipsMenstruation.length - 1)];
    } else if (phaseKey === 'ovulation') {
        phase = 'Ovulación';
        fertilityChance = 'Máxima';
        fertilityColor = '#e91e63';
        description = tipOvulation;
    } else if (phaseKey === 'fertile') {
        phase = 'Ventana Fértil';
        fertilityChance = 'Alta';
        fertilityColor = '#ff9800';
        description = tipsFertile[Math.min(dayInCurrentCycle - (ovulationDay - 5), tipsFertile.length - 1)];
    } else if (phaseKey === 'follicular') {
        phase = 'Fase Folicular';
        fertilityChance = 'Media-Baja';
        fertilityColor = '#29b6f6';
        description = tipsFollicular[Math.max(0, (dayInCurrentCycle - periodLength - 1) % tipsFollicular.length)];
    } else {
        phase = 'Fase Lútea';
        fertilityChance = 'Baja';
        fertilityColor = '#03a9f4';
        description = tipsLuteal[Math.max(0, (dayInCurrentCycle - ovulationDay - 1) % tipsLuteal.length)];
    }

    let nextPeriodIn = actualCycleLength - dayInCurrentCycle + 1;
    if (nextPeriodIn <= 0) nextPeriodIn = 0;
    
    const progressPercent = Math.min((dayInCurrentCycle / actualCycleLength) * 100, 100);
    const isToday = dateStr === new Date().toISOString().split('T')[0];
    const dateTitle = isToday ? `Hoy es el Día ${dayInCurrentCycle} del Ciclo` : `El ${dateStr} (Día ${dayInCurrentCycle} del Ciclo)`;

    return {
        phaseKey,
        phase,
        description,
        fertilityChance,
        fertilityColor,
        dayInCurrentCycle,
        nextPeriodIn,
        progressPercent,
        dateTitle,
        actualCycleLength
    };
}
