import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/holidays.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models.dart';
import '../event_categories.dart';
import '../events_repository.dart';
import 'event_form_sheet.dart';
import 'event_tiles.dart';

const _diasCortos = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

/// Domingo de la semana a la que pertenece una fecha.
DateTime inicioSemana(DateTime d) => DateTime(d.year, d.month, d.day - d.weekday % 7);

/// Agenda de la semana: tira de 7 días y línea de tiempo del día elegido.
class VistaSemana extends ConsumerWidget {
  const VistaSemana({super.key, required this.cumples});
  final List<Cumple> cumples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = hoyYmd();
    final sel = ref.watch(diaEventosProvider) ?? hoy;
    final partes = sel.split('-').map(int.parse).toList();
    final inicio = inicioSemana(DateTime(partes[0], partes[1], partes[2]));
    final fin = inicio.add(const Duration(days: 6));

    // Una semana puede cruzar dos meses.
    final porDia = <String, List<Evento>>{};
    for (final k in {(inicio.year, inicio.month), (fin.year, fin.month)}) {
      for (final e in ref.watch(eventosMesProvider(k)).value ?? const <Evento>[]) {
        (porDia[e.fecha] ??= []).add(e);
      }
    }
    final delDia = [...?porDia[sel]]..sort((a, b) => (a.hora ?? '').compareTo(b.hora ?? ''));

    void elegir(String f) {
      HapticFeedback.selectionClick();
      ref.read(diaEventosProvider.notifier).seleccionar(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.xs, Gap.sm),
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: 'Semana anterior', onPressed: () => elegir(sumarDiasYmd(sel, -7)), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(
                  _rango(inicio, fin),
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall,
                ),
              ),
              IconButton(tooltip: 'Semana siguiente', onPressed: () => elegir(sumarDiasYmd(sel, 7)), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            const VGap.xs(),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _Dia(fecha: inicio.add(Duration(days: i)), hoy: hoy, sel: sel, porDia: porDia, onTap: elegir)),
            ]),
          ]),
        ),
        const VGap.lg(),
        SmoothSwitcher(
          child: _LineaDelDia(
            key: ValueKey(sel),
            fecha: sel,
            esHoy: sel == hoy,
            eventos: delDia,
            cumples: cumples.where((c) => c.fecha.length >= 10 && c.fecha.substring(5) == sel.substring(5)).toList(),
          ),
        ),
      ],
    );
  }

  static String _rango(DateTime a, DateTime b) => a.month == b.month
      ? '${a.day} al ${b.day} de ${mesesLargos[a.month - 1].toLowerCase()}'
      : '${a.day} de ${mesesLargos[a.month - 1].toLowerCase()} al ${b.day} de ${mesesLargos[b.month - 1].toLowerCase()}';
}

class _Dia extends StatelessWidget {
  const _Dia({required this.fecha, required this.hoy, required this.sel, required this.porDia, required this.onTap});
  final DateTime fecha;
  final String hoy;
  final String sel;
  final Map<String, List<Evento>> porDia;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = ymd(fecha);
    final elegido = f == sel;
    final esHoy = f == hoy;
    final eventos = porDia[f] ?? const <Evento>[];
    final festivo = festivoEn(f) != null;
    final colorTexto = elegido ? p.onAccent : p.text;
    return Semantics(
      button: true,
      selected: elegido,
      label: '${fechaConDia(f)}${eventos.isNotEmpty ? ', ${eventos.length} ${eventos.length == 1 ? 'evento' : 'eventos'}' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => onTap(f),
        haptic: false,
        scale: 0.94,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.standard,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          decoration: BoxDecoration(
            color: elegido ? p.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: esHoy && !elegido ? p.accent : Colors.transparent),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_diasCortos[fecha.weekday % 7], style: context.text.labelSmall?.copyWith(color: elegido ? p.onAccent : (festivo ? p.warning : p.textSecondary))),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${fecha.day}', style: context.text.titleMedium?.copyWith(color: colorTexto, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            const SizedBox(height: Gap.xxs),
            SizedBox(
              height: 6,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final e in eventos.take(3))
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: elegido ? p.onAccent : categoriaEvento(e.categoria).colorDe(context)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Lo del día en orden: primero lo que no tiene hora y luego por hora, con una
/// marca de "Ahora" si es hoy.
class _LineaDelDia extends StatelessWidget {
  const _LineaDelDia({super.key, required this.fecha, required this.esHoy, required this.eventos, required this.cumples});
  final String fecha;
  final bool esHoy;
  final List<Evento> eventos;
  final List<Cumple> cumples;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final festivo = festivoEn(fecha);
    final anio = int.parse(fecha.substring(0, 4));
    final ahora = DateTime.now();
    final horaAhora = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
    final conHora = eventos.where((e) => e.hora != null).toList();
    final sinHora = eventos.where((e) => e.hora == null).toList();
    final indiceAhora = esHoy && conHora.isNotEmpty ? conHora.indexWhere((e) => e.hora!.compareTo(horaAhora) >= 0) : -2;
    final vacio = eventos.isEmpty && cumples.isEmpty && festivo == null;

    Widget marcaAhora() => Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: Row(children: [
            Text('Ahora', style: context.text.labelSmall?.copyWith(color: p.danger)),
            const HGap.xs(),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle)),
            Expanded(child: Container(height: 2, color: p.danger)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          fechaConDia(fecha),
          action: TextButton.icon(
            onPressed: () => abrirFormularioEvento(context, fecha: fecha),
            icon: const Icon(Icons.add_rounded, size: IconSizes.md),
            label: const Text('Evento'),
          ),
        ),
        if (festivo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(children: [
              Icon(Icons.celebration_rounded, color: p.warning, size: IconSizes.md),
              const HGap.xs(),
              Expanded(child: Text('Festivo: ${festivo.nombre}', style: context.text.bodySmall?.copyWith(color: p.text))),
            ]),
          ),
        if (vacio)
          AppCard(
            child: EmptyState(
              icon: Icons.self_improvement_rounded,
              title: 'Día libre',
              message: 'No tienes nada agendado.',
              actionLabel: 'Agendar algo',
              onAction: () => abrirFormularioEvento(context, fecha: fecha),
              compact: true,
            ),
          ),
        for (final e in sinHora) Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: EventTile(evento: e)),
        for (final c in cumples) Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: BirthdayTile(cumple: c, anio: anio)),
        for (final (i, e) in conHora.indexed) ...[
          if (i == indiceAhora) marcaAhora(),
          Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: EventTile(evento: e)),
        ],
        if (indiceAhora == -1) marcaAhora(),
      ],
    );
  }
}
