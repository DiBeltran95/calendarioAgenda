import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import 'citas_models.dart';
import 'citas_repository.dart';
import 'widgets/config_sheets.dart';
import 'widgets/enlace_card.dart';
import 'widgets/horario_editor.dart';

/// Ajustes del módulo de citas: página, servicios, equipo y días libres.
class AjustesAgendaScreen extends ConsumerWidget {
  const AjustesAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configAgendaProvider).value ?? ConfigAgenda.vacia;
    final n = config.negocio;
    final p = context.palette;
    var i = 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de citas'), backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
      body: n == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(agendaRepoProvider).refrescar(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xxxl),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // ── Página ──
                        Entrance(
                          index: i++,
                          child: AppCard(
                            onTap: () => showAppSheet(context, (_) => NegocioSheet(negocio: n)),
                            semanticLabel: 'Editar tu página de citas',
                            child: Row(children: [
                              Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Color(n.color), shape: BoxShape.circle),
                                child: Text(iniciales(n.nombre), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                              ),
                              const HGap.md(),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(n.nombre, style: context.text.titleMedium),
                                  Text('${rubrosAgenda[n.rubro] ?? 'Servicios'} · ${n.esEmpresa ? 'Con equipo' : 'Independiente'}', style: context.text.bodySmall),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: Gap.xs, runSpacing: 4, children: [
                                    Tag(n.activo ? 'Recibiendo reservas' : 'Pausada', color: n.activo ? p.success : p.warning),
                                    Tag('Cada ${n.intervaloMin} min', color: p.textSecondary),
                                    Tag(n.anticipacionMin == 0 ? 'Sin anticipación' : 'Mín. ${_anticipacion(n.anticipacionMin)}', color: p.textSecondary),
                                  ]),
                                ]),
                              ),
                              const Icon(Icons.edit_rounded),
                            ]),
                          ),
                        ),
                        const VGap.sm(),
                        Entrance(index: i++, child: TarjetaEnlace(negocio: n)),

                        // ── Tu horario (independiente) ──
                        if (!n.esEmpresa) ...[
                          for (final pr in config.profesionales.where((x) => x.esDueno).take(1)) ...[
                            const VGap.lg(),
                            const SectionHeader('Tu horario', icon: Icons.schedule_rounded),
                            Entrance(
                              index: i++,
                              child: AppCard(
                                onTap: () => showAppSheet(context, (_) => ProfesionalSheet(profesional: pr, config: config)),
                                child: Row(children: [
                                  const IconBadge(Icons.schedule_rounded),
                                  const HGap.sm(),
                                  Expanded(child: Text(resumenHorario(pr.horarios), style: context.text.bodyMedium)),
                                  const Icon(Icons.chevron_right_rounded),
                                ]),
                              ),
                            ),
                          ],
                        ],

                        // ── Servicios ──
                        const VGap.lg(),
                        SectionHeader(
                          'Servicios',
                          icon: Icons.spa_rounded,
                          action: TextButton.icon(
                            onPressed: () => showAppSheet(context, (_) => ServicioSheet(config: config)),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Agregar'),
                          ),
                        ),
                        if (config.servicios.isEmpty)
                          EmptyState(
                            icon: Icons.spa_outlined,
                            title: 'Sin servicios',
                            message: 'Agrega lo que ofreces, cuánto dura y su precio.',
                            actionLabel: 'Agregar servicio',
                            onAction: () => showAppSheet(context, (_) => ServicioSheet(config: config)),
                            compact: true,
                          ),
                        for (final s in config.servicios)
                          Entrance(
                            index: i++,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: Gap.xs),
                              child: AppCard(
                                onTap: () => showAppSheet(context, (_) => ServicioSheet(servicio: s, config: config)),
                                child: Row(children: [
                                  Container(width: 4, height: 40, decoration: BoxDecoration(color: Color(s.color), borderRadius: BorderRadius.circular(2))),
                                  const HGap.sm(),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(s.nombre, style: context.text.titleSmall),
                                      Text(
                                        [
                                          duracionTexto(s.duracionMin),
                                          if (s.precio > 0) cop(s.precio),
                                          if (config.profesionales.length > 1) '${s.profesionales.length} profesional(es)',
                                        ].join(' · '),
                                        style: context.text.bodySmall,
                                      ),
                                    ]),
                                  ),
                                  if (!s.activo) Tag('Oculto', color: p.textSecondary),
                                  const Icon(Icons.chevron_right_rounded),
                                ]),
                              ),
                            ),
                          ),

                        // ── Equipo ──
                        if (n.esEmpresa || config.profesionales.length > 1) ...[
                          const VGap.lg(),
                          SectionHeader(
                            'Equipo',
                            icon: Icons.groups_rounded,
                            action: TextButton.icon(
                              onPressed: () => showAppSheet(context, (_) => ProfesionalSheet(config: config)),
                              icon: const Icon(Icons.person_add_alt_rounded),
                              label: const Text('Agregar'),
                            ),
                          ),
                          if (config.profesionales.isEmpty)
                            EmptyState(
                              icon: Icons.groups_outlined,
                              title: 'Aún no hay profesionales',
                              message: 'Agrega a quienes atienden, con su horario y los servicios que prestan.',
                              actionLabel: 'Agregar profesional',
                              onAction: () => showAppSheet(context, (_) => ProfesionalSheet(config: config)),
                              compact: true,
                            ),
                          for (final pr in config.profesionales)
                            Entrance(
                              index: i++,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: Gap.xs),
                                child: AppCard(
                                  onTap: () => showAppSheet(context, (_) => ProfesionalSheet(profesional: pr, config: config)),
                                  child: Row(children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Color(pr.color),
                                      child: Text(pr.iniciales, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    ),
                                    const HGap.sm(),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Flexible(child: Text(pr.nombre, style: context.text.titleSmall, overflow: TextOverflow.ellipsis)),
                                          if (pr.usuarioId != null) ...[
                                            const SizedBox(width: 4),
                                            Tooltip(message: 'Usa la app', child: Icon(Icons.verified_rounded, size: 16, color: p.accent)),
                                          ],
                                        ]),
                                        Text(
                                          [if (pr.cargo != null && pr.cargo!.isNotEmpty) pr.cargo!, resumenHorario(pr.horarios)].join(' · '),
                                          style: context.text.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ]),
                                    ),
                                    if (!pr.activo) Tag('Inactivo', color: p.textSecondary),
                                    const Icon(Icons.chevron_right_rounded),
                                  ]),
                                ),
                              ),
                            ),
                        ],

                        // ── Días y horas bloqueados ──
                        const VGap.lg(),
                        SectionHeader(
                          'Tiempo bloqueado',
                          icon: Icons.event_busy_rounded,
                          subtitle: 'Vacaciones, diligencias, festivos propios',
                          action: TextButton.icon(
                            onPressed: () => showAppSheet(context, (_) => BloqueoSheet(config: config)),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Bloquear'),
                          ),
                        ),
                        if (config.bloqueos.isEmpty) Text('No tienes días bloqueados.', style: context.text.bodySmall),
                        for (final b in config.bloqueos)
                          Dismissible(
                            key: ValueKey('bloqueo-${b.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: Gap.lg),
                              decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.15), borderRadius: Radii.rLg),
                              child: Icon(Icons.delete_outline_rounded, color: p.danger),
                            ),
                            onDismissed: (_) async {
                              HapticFeedback.mediumImpact();
                              final toaster = Toaster.of(context);
                              try {
                                await ref.read(agendaRepoProvider).eliminarBloqueo(b.id);
                                toaster.show('Bloqueo eliminado');
                              } on AgendaError catch (e) {
                                toaster.show(e.mensaje, error: true);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: Gap.xs),
                              child: AppCard(
                                child: Row(children: [
                                  IconBadge(Icons.event_busy_rounded, color: p.warning),
                                  const HGap.sm(),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(fechaConDia(b.fecha), style: context.text.titleSmall),
                                      Text(
                                        [
                                          b.diaCompleto ? 'Todo el día' : '${hora12(b.inicio)} – ${hora12(b.fin)}',
                                          if (config.profesionales.length > 1) config.profesional(b.profesionalId)?.nombre ?? '',
                                          if (b.motivo != null && b.motivo!.isNotEmpty) b.motivo!,
                                        ].where((x) => x.isNotEmpty).join(' · '),
                                        style: context.text.bodySmall,
                                      ),
                                    ]),
                                  ),
                                  IconButton(
                                    tooltip: 'Quitar bloqueo',
                                    onPressed: () async {
                                      final toaster = Toaster.of(context);
                                      try {
                                        await ref.read(agendaRepoProvider).eliminarBloqueo(b.id);
                                        toaster.show('Bloqueo eliminado');
                                      } on AgendaError catch (e) {
                                        toaster.show(e.mensaje, error: true);
                                      }
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        const VGap.lg(),
                        Text(
                          'Las citas confirmadas aparecen también en tu calendario de eventos y te llegan recordatorios como a cualquier evento.',
                          style: context.text.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

String _anticipacion(int min) => min < 60 ? '$min min' : (min < 1440 ? '${min ~/ 60} h' : '${min ~/ 1440} día(s)');
