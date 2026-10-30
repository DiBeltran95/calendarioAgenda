import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/fab_animado.dart';
import '../../core/dates.dart';
import '../../core/db/database.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../data/sync.dart';
import '../../core/widgets/month_calendar.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import 'cycle_engine.dart';
import 'cycle_repository.dart';
import 'widgets/cycle_ring.dart';
import 'widgets/cycle_sheets.dart';

class CycleScreen extends ConsumerWidget {
  const CycleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cycleStatsProvider);
    final sel = ref.watch(diaCicloProvider) ?? hoyYmd();
    final registros = ref.watch(registrosDiaProvider).value ?? const <String, RegistroDia>{};
    final detalles = getCycleDetails(sel, stats);
    final inicios = {for (final l in stats.logs) l.fechaInicio};

    void registrar([String? fecha]) => abrirPeriodo(context, ref, fecha ?? sel);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FabAnimado(heroTag: 'fab-ciclo', onPressed: registrar, icono: Icons.water_drop_rounded, etiqueta: 'Registrar periodo'),
      body: SafeArea(
        bottom: false,
        child: ModuleLayout(
          onRefresh: () => ref.read(sincronizadorProvider).refrescarTodo(),
          primary: [
            EncabezadoPantalla(
              contexto: 'Tu cuerpo, tu ritmo',
              titulo: AppModule.ciclo.label,
              acciones: [
                IconButton(
                  tooltip: 'Leyenda de colores',
                  onPressed: () => showAppSheet(context, (_) => const _LeyendaSheet()),
                  icon: const Icon(Icons.palette_outlined),
                ),
              ],
            ),
            Entrance(
              child: stats.vacio ? _SinRegistros(onRegistrar: registrar) : _Hero(fecha: sel, detalles: detalles, stats: stats),
            ),
            const VGap.sm(),
            Entrance(
              index: 1,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.sm),
                child: MonthCalendar(
                  cursor: mesCicloProvider,
                  selected: sel,
                  onTap: (f) => ref.read(diaCicloProvider.notifier).seleccionar(f),
                  onLongPress: (f) {
                    ref.read(diaCicloProvider.notifier).seleccionar(f);
                    registrar(f);
                  },
                  semantics: (d) {
                    final det = getCycleDetails(d.fecha, stats);
                    return '${fechaConDia(d.fecha)}${det != null ? ', ${det.fase.nombre}, día ${det.diaDelCiclo}' : ''}';
                  },
                  cellBuilder: (context, d) => _CycleDayCell(
                    day: d,
                    detalles: getCycleDetails(d.fecha, stats),
                    esInicio: inicios.contains(d.fecha),
                    tieneRegistro: registros.containsKey(d.fecha),
                  ),
                  footer: const _LeyendaCompacta(),
                ),
              ),
            ),
          ],
          secondary: [
            const VGap.md(),
            if (!stats.vacio) ...[
              SmoothSwitcher(
                child: _Consejo(key: ValueKey(sel), fecha: sel, detalles: detalles, sinDatos: stats.vacio),
              ),
              const VGap.md(),
              _Pronostico(stats: stats),
              const VGap.md(),
            ],
            _RegistroDiaCard(fecha: sel, registro: registros[sel]),
            const VGap.md(),
            _Historial(stats: stats),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Hero ───────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.fecha, required this.detalles, required this.stats});
  final String fecha;
  final CycleDetails? detalles;
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = detalles;
    if (d == null) {
      return AppCard(
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Fuera del rango analizable',
          message: 'El ${fechaCorta(fecha)} es anterior a tu primer registro o está demasiado lejos para predecirlo con fiabilidad.',
          compact: true,
        ),
      );
    }
    final color = colorFase(d.fase);
    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(color.withValues(alpha: context.isDark ? 0.14 : 0.1), p.surface),
          p.surface,
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // En columna (teléfono) la rueda puede ser más grande que en fila.
          final ring = CycleRing(details: d, size: c.maxWidth < 420 ? (c.maxWidth * 0.8).clamp(200.0, 280.0) : 220);
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fecha == hoyYmd() ? 'Hoy' : fechaConDia(fecha), style: context.text.labelLarge?.copyWith(color: p.accent)),
              const SizedBox(height: 6),
              _Dato(
                icon: Icons.child_care_rounded,
                label: 'Probabilidad de embarazo',
                valor: d.probabilidad,
                color: switch (d.probabilidad) {
                  'Máxima' => PhaseColors.ovulation,
                  'Alta' => PhaseColors.fertile,
                  _ => p.text,
                },
              ),
              const VGap.sm(),
              _Dato(
                icon: Icons.water_drop_outlined,
                label: 'Próximo periodo',
                valor: d.fase == Fase.periodoRetrasado
                    ? '${d.diasRetraso} día${d.diasRetraso == 1 ? '' : 's'} de retraso'
                    : 'En ${d.proximoPeriodoEn} día${d.proximoPeriodoEn == 1 ? '' : 's'}',
                color: d.fase == Fase.periodoRetrasado ? PhaseColors.late : null,
              ),
              const VGap.sm(),
              _Dato(icon: Icons.loop_rounded, label: d.esCicloObservado ? 'Ciclo de referencia' : 'Ciclo estimado', valor: '${d.duracionCiclo} días'),
            ],
          );
          if (c.maxWidth < 420) {
            return Column(children: [ring, const VGap.md(), info]);
          }
          return Row(
            children: [
              ring,
              const HGap.md(),
              Expanded(child: info),
            ],
          );
        },
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.label, required this.valor, this.color});
  final IconData icon;
  final String label;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon, size: 36, color: color),
        const HGap.sm(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.bodySmall),
              SmoothSwitcher(
                child: Text(
                  valor,
                  key: ValueKey(valor),
                  style: context.text.titleSmall?.copyWith(color: color == null ? null : context.legible(color!)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SinRegistros extends StatelessWidget {
  const _SinRegistros({required this.onRegistrar});
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: EmptyState(
        icon: Icons.spa_rounded,
        title: 'Empieza a conocer tu ciclo',
        message: 'Registra el primer día de tu último periodo. Con cada registro las predicciones se vuelven más precisas.',
        actionLabel: 'Registrar mi último periodo',
        onAction: onRegistrar,
      ),
    );
  }
}

// ─────────────────────────── Celda ───────────────────────────

class _CycleDayCell extends StatelessWidget {
  const _CycleDayCell({required this.day, required this.detalles, required this.esInicio, required this.tieneRegistro});
  final CalendarDay day;
  final CycleDetails? detalles;
  final bool esInicio;
  final bool tieneRegistro;

  @override
  Widget build(BuildContext context) {
    final f = detalles?.fase;
    final color = f == null ? null : colorFase(f);
    final (fill, strong, ring) = switch (f) {
      Fase.periodo => (color, true, null),
      Fase.periodoRetrasado => (color, false, color),
      Fase.periodoPrevisto => (color, false, color),
      Fase.ovulacion => (color, true, null),
      Fase.fertil => (color, false, null),
      _ => (null, false, null),
    };
    return DayCellFrame(
      day: day,
      fill: fill,
      strong: strong,
      ring: ring?.withValues(alpha: 0.8),
      fillOpacity: f == Fase.periodoPrevisto ? 0.1 : null,
      corner: esInicio
          ? Icon(Icons.water_drop_rounded, size: 12, color: textoSobre(color ?? PhaseColors.period))
          : f == Fase.ovulacion
          ? Icon(Icons.auto_awesome_rounded, size: 12, color: textoSobre(PhaseColors.ovulation))
          : f == Fase.periodoRetrasado
          ? Icon(Icons.hourglass_bottom_rounded, size: 12, color: context.legible(PhaseColors.late))
          : null,
      markers: tieneRegistro ? Dot(strong ? textoSobre(color ?? PhaseColors.period) : context.palette.accent2) : null,
    );
  }
}

class _LeyendaCompacta extends StatelessWidget {
  const _LeyendaCompacta();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t, {bool outline = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : c,
            border: Border.all(color: c, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(letterSpacing: 0))),
      ],
    );
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.xs,
      alignment: WrapAlignment.center,
      children: [
        item(PhaseColors.period, 'Periodo'),
        item(PhaseColors.predicted, 'Previsto', outline: true),
        item(PhaseColors.fertile, 'Fértil'),
        item(PhaseColors.ovulation, 'Ovulación'),
        item(PhaseColors.late, 'Retraso', outline: true),
      ],
    );
  }
}

class _LeyendaSheet extends StatelessWidget {
  const _LeyendaSheet();

  @override
  Widget build(BuildContext context) {
    const filas = [
      (Fase.periodo, 'Días de sangrado registrados.'),
      (Fase.periodoPrevisto, 'Predicción según el promedio de tus ciclos recientes.'),
      (Fase.periodoRetrasado, 'El periodo se esperaba y aún no se ha registrado.'),
      (Fase.fertil, 'Los días con más probabilidad de embarazo.'),
      (Fase.ovulacion, '14 días antes del siguiente periodo.'),
      (Fase.folicular, 'Después del periodo: sube la energía.'),
      (Fase.lutea, 'Después de la ovulación y hasta el siguiente periodo.'),
    ];
    return SheetScaffold(
      title: 'Leyenda del ciclo',
      icon: Icons.palette_outlined,
      children: [
        for (var i = 0; i < filas.length; i++)
          Entrance(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Row(
                children: [
                  IconBadge(iconoFase(filas[i].$1), color: colorFase(filas[i].$1), size: 40),
                  const HGap.sm(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(filas[i].$1.nombre, style: context.text.titleSmall),
                        Text(filas[i].$2, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const VGap.sm(),
        Text(
          'Las predicciones son estimaciones basadas en tus registros; no reemplazan un método anticonceptivo ni la consulta médica.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

// ─────────────────────────── Consejo del día ───────────────────────────

class _Consejo extends StatelessWidget {
  const _Consejo({super.key, required this.fecha, required this.detalles, required this.sinDatos});
  final String fecha;
  final CycleDetails? detalles;
  final bool sinDatos;

  @override
  Widget build(BuildContext context) {
    final d = detalles;
    if (d == null) return const SizedBox.shrink();
    final color = colorFase(d.fase);
    return AppCard(
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(iconoFase(d.fase), color: color, size: 40),
              const HGap.sm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.fase.nombre, style: context.text.titleMedium?.copyWith(color: color)),
                    Text(
                      fecha == hoyYmd() ? 'Hoy es el día ${d.diaDelCiclo} de tu ciclo' : '${fechaConDia(fecha)} · día ${d.diaDelCiclo}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const VGap.sm(),
          ProgressBar(value: d.progreso, color: color, height: 6),
          const VGap.sm(),
          Text(d.descripcion, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}

// ─────────────────────────── Pronóstico ───────────────────────────

class _Pronostico extends StatelessWidget {
  const _Pronostico({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final pr = pronostico(stats);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Pronóstico', icon: Icons.insights_rounded),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Próximo periodo',
                value: Text(pr.proximoPeriodo == null ? '—' : fechaCorta(pr.proximoPeriodo!)),
                icon: Icons.water_drop_rounded,
                color: PhaseColors.period,
                caption: pr.proximoPeriodo == null ? null : fechaRelativa(pr.proximoPeriodo!),
              ),
            ),
            const HGap.xs(),
            Expanded(
              child: StatTile(
                label: 'Ventana fértil',
                value: Text(pr.fertilDesde == null ? '—' : '${fechaCorta(pr.fertilDesde!)} – ${parseYmd(pr.fertilHasta!).day}'),
                icon: Icons.local_florist_rounded,
                color: PhaseColors.fertile,
                caption: pr.ovulacion == null ? null : 'Ovulación ${fechaCorta(pr.ovulacion!)}',
              ),
            ),
          ],
        ),
        const VGap.xs(),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Ciclo promedio',
                value: Text('${stats.avgCycleLength} días'),
                icon: Icons.loop_rounded,
                caption: stats.ciclosUsados == 0 ? 'Estándar (28)' : 'De ${stats.ciclosUsados} ${stats.ciclosUsados == 1 ? 'ciclo' : 'ciclos'}',
              ),
            ),
            const HGap.xs(),
            Expanded(
              child: StatTile(
                label: 'Sangrado promedio',
                value: Text('${stats.avgPeriodLength} días'),
                icon: Icons.opacity_rounded,
                caption: stats.sangradosUsados == 0 ? 'Estimado' : 'De ${stats.sangradosUsados} registro(s)',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── Registro del día ───────────────────────────

class _RegistroDiaCard extends StatelessWidget {
  const _RegistroDiaCard({required this.fecha, required this.registro});
  final String fecha;
  final RegistroDia? registro;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = registro;
    final sintomas = r?.sintomas.split(',').where((s) => s.isNotEmpty).toList() ?? const [];
    String etiqueta(List<(String, String)> lista, String k) => lista.firstWhere((e) => e.$1 == k, orElse: () => (k, k)).$2;
    return AppCard(
      onTap: () => showAppSheet(context, (_) => DayLogSheet(fecha: fecha, registro: r)),
      semanticLabel: 'Registro del día: síntomas y estado de ánimo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(Icons.favorite_rounded, color: p.accent2, size: 40),
              const HGap.sm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Síntomas y ánimo', style: context.text.titleSmall),
                    Text(r == null ? 'Toca para registrar cómo te sientes' : fechaConDia(fecha), style: context.text.bodySmall),
                  ],
                ),
              ),
              Icon(r == null ? Icons.add_circle_outline_rounded : Icons.edit_rounded, color: p.textSecondary),
            ],
          ),
          if (r != null) ...[
            const VGap.sm(),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (r.flujo > 0) Tag('Flujo ${nivelesFlujo[r.flujo].toLowerCase()}', color: PhaseColors.period, icon: Icons.water_drop_rounded),
                if (r.animo != null) Tag(etiqueta(animosDisponibles, r.animo!), color: p.accent2, icon: Icons.mood_rounded),
                for (final s in sintomas) Tag(etiqueta(sintomasDisponibles, s)),
              ],
            ),
            if (r.nota.isNotEmpty) ...[const VGap.xs(), Text(r.nota, style: context.text.bodySmall)],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Historial ───────────────────────────

class _Historial extends ConsumerWidget {
  const _Historial({required this.stats});
  final CycleStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final h = getCycleHistory(stats);
    if (h.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Historial de ciclos', icon: Icons.history_rounded, subtitle: '${h.length} registro(s) · toca uno para editarlo'),
        for (var i = 0; i < h.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Entrance(
              index: i,
              child: AppCard(
                padding: const EdgeInsets.all(Gap.sm),
                onTap: () {
                  final f = h[i].registro.fechaInicio;
                  ref.read(diaCicloProvider.notifier).seleccionar(f);
                  ref.read(mesCicloProvider.notifier).ir(parseYmd(f));
                  abrirPeriodo(context, ref, f);
                },
                child: Row(
                  children: [
                    const IconBadge(Icons.water_drop_rounded, color: PhaseColors.period, size: 40),
                    const HGap.sm(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${fechaCorta(h[i].registro.fechaInicio)} ${parseYmd(h[i].registro.fechaInicio).year}', style: context.text.titleSmall),
                          Text(
                            [
                              if (h[i].duracion != null) 'Ciclo de ${h[i].duracion} días',
                              h[i].diasSangrado != null ? '${h[i].diasSangrado} días de sangrado' : 'Sangrado sin especificar',
                            ].join(' · '),
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (h[i].enCurso) Tag('En curso', color: p.accent),
                    if (h[i].anomalo) Tag('Atípico', color: p.warning, icon: Icons.warning_amber_rounded),
                    Icon(Icons.chevron_right_rounded, color: p.textSecondary),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
