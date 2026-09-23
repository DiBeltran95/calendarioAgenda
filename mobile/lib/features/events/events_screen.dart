import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../core/holidays.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/sync.dart';
import '../../core/widgets/month_calendar.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import 'event_categories.dart';
import 'events_repository.dart';
import 'widgets/event_form_sheet.dart';
import 'widgets/event_tiles.dart';

const _festivoColor = Color(0xFFF59E0B);
const _especialColor = Color(0xFF60A5FA);
const _cumpleColor = Color(0xFFF472B6);

/// Cumpleaños que caen en un MM-DD dado.
List<Cumple> cumplesDelDia(List<Cumple> todos, String fecha) =>
    todos.where((c) => c.fecha.length >= 10 && c.fecha.substring(5) == fecha.substring(5)).toList();

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesEventosProvider);
    final sel = ref.watch(diaEventosProvider);
    final eventosAsync = ref.watch(eventosMesProvider((mes.year, mes.month)));
    final eventos = eventosAsync.value ?? const <Evento>[];
    final especiales = ref.watch(diasImportantesProvider(mes.year)).value ?? const <DiaImportante>[];
    final cumples = ref.watch(cumplesProvider).value ?? const <Cumple>[];
    final nombre = ref.watch(sesionProvider).value?.usuario.primerNombre ?? '';

    final porDia = <String, List<Evento>>{};
    for (final e in eventos) {
      (porDia[e.fecha] ??= []).add(e);
    }

    void crear([String? fecha]) => abrirFormularioEvento(context, fecha: fecha ?? sel ?? hoyYmd());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-eventos',
        onPressed: crear,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo evento'),
      ),
      body: SafeArea(
        bottom: false,
        child: ModuleLayout(
          onRefresh: () => ref.read(sincronizadorProvider).refrescarTodo(),
          primary: [
            ModuleHeader(
              overline: saludo(nombre),
              title: AppModule.eventos.label,
              actions: [
                IconButton(
                  tooltip: 'Buscar eventos',
                  onPressed: () => showAppSheet(context, (_) => const _BuscarSheet()),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            CargandoBarra(visible: eventosAsync.isLoading && !eventosAsync.hasValue),
            Entrance(child: _ResumenMes(eventos: eventos)),
            const VGap.sm(),
            Entrance(
              index: 1,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.sm),
                child: MonthCalendar(
                  cursor: mesEventosProvider,
                  selected: sel,
                  onTap: (f) => ref.read(diaEventosProvider.notifier).alternar(f),
                  onLongPress: (f) {
                    ref.read(diaEventosProvider.notifier).seleccionar(f);
                    crear(f);
                  },
                  semantics: (d) {
                    final n = porDia[d.fecha]?.length ?? 0;
                    final fest = festivoEn(d.fecha);
                    return '${fechaConDia(d.fecha)}${fest != null ? ', festivo: ${fest.nombre}' : ''}${n > 0 ? ', $n evento(s)' : ''}';
                  },
                  cellBuilder: (context, d) => _EventDayCell(
                    day: d,
                    especial: diaImportanteEn(especiales, d.fecha),
                    eventos: porDia[d.fecha] ?? const [],
                    cumples: cumplesDelDia(cumples, d.fecha).length,
                  ),
                  footer: const _Leyenda(),
                ),
              ),
            ),
          ],
          secondary: [
            const VGap.md(),
            SmoothSwitcher(
              child: sel == null
                  ? _AgendaMes(key: ValueKey('agenda-${mes.month}'), mes: mes, eventos: eventos, cumples: cumples, especiales: especiales)
                  : _DetalleDia(
                      key: ValueKey(sel),
                      fecha: sel,
                      eventos: porDia[sel] ?? const [],
                      cumples: cumplesDelDia(cumples, sel),
                      especial: diaImportanteEn(especiales, sel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Celda ───────────────────────────

class _EventDayCell extends StatelessWidget {
  const _EventDayCell({required this.day, required this.eventos, required this.cumples, this.especial});
  final DiaImportante? especial;

  final CalendarDay day;
  final List<Evento> eventos;
  final int cumples;

  @override
  Widget build(BuildContext context) {
    final festivo = festivoEn(day.fecha);
    final especial = festivo == null ? this.especial : null;
    // Los eventos anuales se pintan con el ícono de su categoría (moto, casa…).
    final anuales = eventos.where((e) => esAnual(e.frecuencia)).toList();
    final otros = eventos.where((e) => !esAnual(e.frecuencia)).toList();

    final markers = <Widget>[
      for (final e in anuales.take(2)) Icon(categoriaEvento(e.categoria).icon, size: 12, color: categoriaEvento(e.categoria).color),
      if (anuales.length > 2)
        Text('+${anuales.length - 2}', style: context.text.labelSmall?.copyWith(fontSize: 9, letterSpacing: 0)),
      for (final e in otros.take(anuales.isEmpty ? 3 : 1)) Dot(categoriaEvento(e.categoria).color),
    ];

    return DayCellFrame(
      day: day,
      fill: festivo != null ? _festivoColor : null,
      fillOpacity: context.isDark ? 0.16 : 0.14,
      ring: especial != null ? _especialColor.withValues(alpha: 0.5) : null,
      corner: festivo != null
          ? const Icon(Icons.celebration_rounded, size: 11, color: _festivoColor)
          : cumples > 0
              ? const Icon(Icons.cake_rounded, size: 11, color: _cumpleColor)
              : especial != null
                  ? const Icon(Icons.star_rounded, size: 11, color: _especialColor)
                  : null,
      markers: markers.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: markers),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget icon, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 4),
          Text(t, style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
        ]);
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.xs,
      alignment: WrapAlignment.center,
      children: [
        item(const Icon(Icons.celebration_rounded, size: 13, color: _festivoColor), 'Festivo'),
        item(const Icon(Icons.star_rounded, size: 13, color: _especialColor), 'Día especial'),
        item(const Icon(Icons.cake_rounded, size: 13, color: _cumpleColor), 'Cumpleaños'),
        item(Icon(Icons.two_wheeler_rounded, size: 13, color: context.palette.textSecondary), 'Anual'),
      ],
    );
  }
}

// ─────────────────────────── Resumen del mes ───────────────────────────

class _ResumenMes extends StatelessWidget {
  const _ResumenMes({required this.eventos});
  final List<Evento> eventos;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    var pagado = 0.0, pendiente = 0.0, ingresos = 0.0;
    for (final e in eventos) {
      if (e.tipoTransaccion == 'gasto') {
        if (e.estadoPago == 'pagado') {
          pagado += e.costo;
        } else {
          pendiente += e.costo;
        }
      } else if (e.tipoTransaccion == 'ingreso') {
        ingresos += e.costo;
      }
    }
    return Row(
      children: [
        Expanded(child: StatTile(label: 'Eventos', value: Text('${eventos.length}'), icon: Icons.event_rounded)),
        const HGap.xs(),
        Expanded(child: StatTile(label: 'Por pagar', value: AnimatedMoney(pendiente), icon: Icons.schedule_rounded, color: p.warning)),
        const HGap.xs(),
        Expanded(
          child: StatTile(
            label: pagado > 0 ? 'Pagado' : 'Por cobrar',
            value: AnimatedMoney(pagado > 0 ? pagado : ingresos),
            icon: pagado > 0 ? Icons.check_circle_rounded : Icons.north_east_rounded,
            color: p.success,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Detalle del día ───────────────────────────

class _DetalleDia extends ConsumerWidget {
  const _DetalleDia({super.key, required this.fecha, required this.eventos, required this.cumples, this.especial});
  final DiaImportante? especial;

  final String fecha;
  final List<Evento> eventos;
  final List<Cumple> cumples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final festivo = festivoEn(fecha);
    final anio = int.parse(fecha.substring(0, 4));
    final vacio = eventos.isEmpty && cumples.isEmpty && festivo == null && especial == null;
    var i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fechaRelativa(fecha).toUpperCase(), style: context.text.labelSmall?.copyWith(color: p.accent)),
                  Semantics(header: true, child: Text(fechaConDia(fecha), style: context.text.titleLarge)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ver agenda del mes',
              onPressed: () => ref.read(diaEventosProvider.notifier).seleccionar(null),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const VGap.sm(),
        if (festivo != null)
          Entrance(
            index: i++,
            child: _InfoDia(
              color: _festivoColor,
              icon: Icons.celebration_rounded,
              titulo: festivo.nombre,
              texto: festivo.trasladado ? 'Festivo nacional · trasladado al lunes (Ley Emiliani) · Día no laboral' : 'Festivo nacional · Día no laboral',
            ),
          ),
        if (especial != null)
          Entrance(
            index: i++,
            child: _InfoDia(
              color: _especialColor,
              icon: Icons.star_rounded,
              titulo: especial!.nombre,
              texto: [especial!.categoria, especial!.descripcion].where((t) => t.isNotEmpty).join(' · '),
            ),
          ),
        for (final e in eventos)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Entrance(index: i++, child: EventTile(evento: e)),
          ),
        if (cumples.isNotEmpty) ...[
          const VGap.xs(),
          SectionHeader('Cumpleaños', icon: Icons.cake_rounded),
          for (final c in cumples)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Entrance(index: i++, child: BirthdayTile(cumple: c, anio: anio)),
            ),
        ],
        if (vacio)
          EmptyState(
            icon: Icons.wb_sunny_rounded,
            title: 'Día libre',
            message: 'No tienes eventos ni cumpleaños este día.',
            actionLabel: 'Crear evento',
            onAction: () => abrirFormularioEvento(context, fecha: fecha),
          )
        else ...[
          const VGap.xs(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirFormularioEvento(context, fecha: fecha),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Evento'),
                ),
              ),
              const HGap.xs(),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirFormularioEvento(context, fecha: fecha, categoriaInicial: 'cumpleanos'),
                  icon: const Icon(Icons.cake_outlined),
                  label: const Text('Cumpleaños'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoDia extends StatelessWidget {
  const _InfoDia({required this.color, required this.icon, required this.titulo, required this.texto});
  final Color color;
  final IconData icon;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: AppCard(
        color: Color.alphaBlend(color.withValues(alpha: 0.08), context.palette.surface),
        borderColor: color.withValues(alpha: 0.35),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 44),
            const HGap.sm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: context.text.titleSmall),
                  Text(texto, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Agenda del mes ───────────────────────────

class _ItemAgenda {
  const _ItemAgenda({required this.fecha, required this.hora, required this.titulo, required this.detalle, required this.icon, required this.color, this.evento});
  final String fecha;
  final String hora;
  final String titulo;
  final String detalle;
  final IconData icon;
  final Color color;
  final Evento? evento;
}

/// Lo que queda del mes visible, en orden: eventos, festivos, días especiales y
/// cumpleaños (la misma idea que se agregó a la web).
class _AgendaMes extends ConsumerWidget {
  const _AgendaMes({super.key, required this.mes, required this.eventos, required this.cumples, required this.especiales});
  final List<DiaImportante> especiales;

  final DateTime mes;
  final List<Evento> eventos;
  final List<Cumple> cumples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final hoy = hoyYmd();
    final prefijo = prefijoMes(mes.year, mes.month);
    // Mes futuro: completo. Mes pasado: nada pendiente. Mes actual: desde hoy.
    final desde = prefijo.compareTo(hoy.substring(0, 7)) > 0 ? '$prefijo-00' : hoy;

    final items = <_ItemAgenda>[
      for (final e in eventos.where((e) => e.fecha.compareTo(desde) >= 0))
        _ItemAgenda(
          fecha: e.fecha,
          hora: e.hora ?? '',
          titulo: e.titulo,
          detalle: [
            categoriaEvento(e.categoria).label,
            if (esAnual(e.frecuencia)) 'Cada año',
            if (e.hora != null) hora12(e.hora) else 'Todo el día',
          ].join(' · '),
          icon: categoriaEvento(e.categoria).icon,
          color: categoriaEvento(e.categoria).color,
          evento: e,
        ),
      for (final f in festivosColombia(mes.year).where((f) => f.fecha.startsWith(prefijo) && f.fecha.compareTo(desde) >= 0))
        _ItemAgenda(fecha: f.fecha, hora: '', titulo: f.nombre, detalle: 'Festivo · Día no laboral', icon: Icons.celebration_rounded, color: _festivoColor),
      for (final d in especiales.where((d) => d.fecha.startsWith(prefijo) && d.fecha.compareTo(desde) >= 0))
        _ItemAgenda(fecha: d.fecha, hora: '', titulo: d.nombre, detalle: d.categoria.isEmpty ? 'Día especial' : d.categoria, icon: Icons.star_rounded, color: _especialColor),
      for (final c in cumples)
        if (c.fecha.length >= 10 && c.fecha.substring(5, 7) == prefijo.substring(5) && '$prefijo${c.fecha.substring(7)}'.compareTo(desde) >= 0)
          _ItemAgenda(
            fecha: '$prefijo${c.fecha.substring(7)}',
            hora: '',
            titulo: c.nombre,
            detalle: c.anioNacimiento != null ? 'Cumple ${mes.year - c.anioNacimiento!} años' : 'Cumpleaños',
            icon: Icons.cake_rounded,
            color: _cumpleColor,
          ),
    ]..sort((a, b) => a.fecha == b.fecha ? a.hora.compareTo(b.hora) : a.fecha.compareTo(b.fecha));

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_rounded,
        title: 'Nada pendiente en ${mesesLargos[mes.month - 1]}',
        message: 'Toca un día para ver su detalle o mantenlo presionado para crear un evento.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Próximos en ${mesesLargos[mes.month - 1]}',
          icon: Icons.upcoming_rounded,
          subtitle: '${items.length} ${items.length == 1 ? 'elemento' : 'elementos'} · toca uno para ver su día',
        ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Entrance(
              index: i,
              child: AppCard(
                padding: const EdgeInsets.all(Gap.sm),
                onTap: () => ref.read(diaEventosProvider.notifier).seleccionar(items[i].fecha),
                semanticLabel: '${items[i].titulo}, ${fechaConDia(items[i].fecha)}',
                child: Row(
                  children: [
                    _FechaChip(fecha: items[i].fecha, color: items[i].color),
                    const HGap.sm(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].titulo, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(items[i].icon, size: 13, color: items[i].color),
                            const SizedBox(width: 4),
                            Expanded(child: Text(items[i].detalle, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      ),
                    ),
                    Text(fechaRelativa(items[i].fecha, hoy), style: context.text.labelSmall?.copyWith(color: p.textSecondary)),
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

class _FechaChip extends StatelessWidget {
  const _FechaChip({required this.fecha, required this.color});
  final String fecha;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final d = parseYmd(fecha);
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.14 : 0.1),
        borderRadius: Radii.rSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('${d.day}', style: context.text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800, height: 1)),
          Text(mesesCortos[d.month - 1].toUpperCase(), style: context.text.labelSmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Búsqueda ───────────────────────────

class _BuscarSheet extends ConsumerStatefulWidget {
  const _BuscarSheet();

  @override
  ConsumerState<_BuscarSheet> createState() => _BuscarSheetState();
}

class _BuscarSheetState extends ConsumerState<_BuscarSheet> {
  final _q = TextEditingController();
  List<Evento> _res = const [];
  bool _buscado = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _buscar(String t) async {
    if (t.trim().length < 2) {
      setState(() {
        _res = const [];
        _buscado = false;
      });
      return;
    }
    final r = await ref.read(eventsRepoProvider).buscar(t);
    if (mounted) {
      setState(() {
        _res = r;
        _buscado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Buscar eventos',
      icon: Icons.search_rounded,
      children: [
        TextField(
          controller: _q,
          autofocus: true,
          onChanged: _buscar,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Título, lugar o nota…', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const VGap.md(),
        if (_buscado && _res.isEmpty)
          const EmptyState(icon: Icons.search_off_rounded, title: 'Sin resultados', message: 'Prueba con otra palabra.', compact: true),
        for (var i = 0; i < _res.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Entrance(
              index: i,
              child: AppCard(
                padding: const EdgeInsets.all(Gap.sm),
                onTap: () {
                  final d = parseYmd(_res[i].fecha);
                  ref.read(mesEventosProvider.notifier).ir(d);
                  ref.read(diaEventosProvider.notifier).seleccionar(_res[i].fecha);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    _FechaChip(fecha: _res[i].fecha, color: categoriaEvento(_res[i].categoria).color),
                    const HGap.sm(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_res[i].titulo, style: context.text.titleSmall),
                          Text('${categoriaEvento(_res[i].categoria).label} · ${parseYmd(_res[i].fecha).year}', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
