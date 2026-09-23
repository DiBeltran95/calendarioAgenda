import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../data/models.dart';
import '../../../core/icon_map.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../finance_logic.dart';
import '../../../data/sync.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../sheets/finance_sheets.dart';

// ─────────────────────────── Metas ───────────────────────────

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metas = ref.watch(metasProvider).value ?? const <Meta>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => showAppSheet(context, (_) => const GoalSheet()),
          icon: const Icon(Icons.flag_rounded),
          label: const Text('Nueva meta de ahorro'),
        ),
        const VGap.md(),
        if (metas.isEmpty)
          const EmptyState(
            icon: Icons.savings_rounded,
            title: 'Ponle nombre a tus sueños',
            message: 'Crea una meta (un viaje, un carro, un fondo de emergencia) y ve cómo se llena con cada aporte.',
          ),
        for (var i = 0; i < metas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Entrance(index: i, child: _GoalCard(meta: metas[i])),
          ),
      ],
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.meta});
  final Meta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = meta;
    final color = Color(m.color);
    final pct = m.montoObjetivo > 0 ? (m.montoActual / m.montoObjetivo).clamp(0.0, 1.0) : 0.0;
    final dias = m.fechaObjetivo == null ? null : diffDias(m.fechaObjetivo!, hoyYmd());
    final falta = math.max(0.0, m.montoObjetivo - m.montoActual);
    final meses = dias == null || dias <= 0 ? null : math.max(1, (dias / 30).ceil());

    return AppCard(
      borderColor: m.completada ? color.withValues(alpha: 0.6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: Motion.of(context, const Duration(milliseconds: 900)),
                  curve: Motion.enter,
                  builder: (_, v, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: p.surfaceHighest,
                        ),
                      ),
                      Icon(m.completada ? Icons.emoji_events_rounded : iconoPorNombre(m.icono), color: color),
                    ],
                  ),
                ),
              ),
              const HGap.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(m.nombre, style: context.text.titleMedium, overflow: TextOverflow.ellipsis)),
                      if (m.completada) ...[const HGap.xs(), Tag('Cumplida', color: color, icon: Icons.check_rounded)],
                    ]),
                    Text('${cop(m.montoActual)} de ${cop(m.montoObjetivo)}', style: context.text.bodySmall),
                    Text('${(pct * 100).toStringAsFixed(0)}%', style: context.text.titleSmall?.copyWith(color: color)),
                  ],
                ),
              ),
              PopupMenuButton<int>(
                tooltip: 'Opciones de la meta',
                onSelected: (i) async {
                  if (i == 0) showAppSheet(context, (_) => GoalSheet(meta: m));
                  if (i == 1) {
                    final ok = await confirmar(context,
                        titulo: '¿Eliminar la meta?', mensaje: 'Los aportes registrados se conservan en el historial.', confirmar: 'Eliminar', destructivo: true);
                    if (ok) await ref.read(financeRepoProvider).eliminarMeta(m.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Editar'))),
                  PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Eliminar'))),
                ],
              ),
            ],
          ),
          if (m.descripcion.isNotEmpty) ...[const VGap.xs(), Text(m.descripcion, style: context.text.bodySmall)],
          if (!m.completada) ...[
            const VGap.sm(),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: IconSizes.sm, color: dias != null && dias < 0 ? p.danger : p.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dias == null
                        ? 'Sin fecha límite · faltan ${cop(falta)}'
                        : dias < 0
                            ? 'La fecha objetivo pasó hace ${-dias} días'
                            : 'Faltan $dias días · ahorra ${cop(falta / meses!)} al mes',
                    style: context.text.bodySmall?.copyWith(color: dias != null && dias < 0 ? p.danger : null),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showAppSheet(context, (_) => ContributionSheet(meta: m, parentContext: context)),
                  style: FilledButton.styleFrom(backgroundColor: color.withValues(alpha: 0.18), foregroundColor: color, minimumSize: const Size(0, 40)),
                  icon: const Icon(Icons.add_rounded, size: IconSizes.md),
                  label: const Text('Aportar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Presupuesto ───────────────────────────

class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key, required this.mes, required this.txMes});
  final DateTime mes;
  final List<Transaccion> txMes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cats = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final pres = ref.watch(presupuestosProvider).value ?? const <Presupuesto>[];
    final vigentes = presupuestosVigentes(pres, mes.year, mes.month);
    final estados = {for (final c in cats) c.valor: estadoCategoria(c.valor, vigentes, txMes)};
    final totalLimite = estados.values.fold(0.0, (s, e) => s + e.limite);
    final totalGastadoConLimite = estados.values.where((e) => e.limite > 0).fold(0.0, (s, e) => s + e.gastado);
    // Primero las que tienen límite (las más comprometidas arriba).
    final orden = [...cats]..sort((a, b) {
        final ea = estados[a.valor]!, eb = estados[b.valor]!;
        if ((ea.limite > 0) != (eb.limite > 0)) return ea.limite > 0 ? -1 : 1;
        return eb.pct.compareTo(ea.pct);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalLimite > 0) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader('Presupuesto de ${mesesLargos[mes.month - 1].toLowerCase()}', icon: Icons.pie_chart_rounded),
                Row(children: [
                  Expanded(child: AnimatedMoney(totalGastadoConLimite, style: context.text.headlineSmall)),
                  Text('de ${cop(totalLimite)}', style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
                ]),
                const VGap.xs(),
                ProgressBar(
                  value: totalGastadoConLimite / totalLimite,
                  color: totalGastadoConLimite / totalLimite >= 1 ? p.danger : (totalGastadoConLimite / totalLimite >= 0.8 ? p.warning : p.success),
                  height: 10,
                ),
              ],
            ),
          ),
          const VGap.md(),
        ],
        Row(
          children: [
            Expanded(child: Text('Toca una categoría para fijar su límite mensual.', style: context.text.bodySmall)),
            TextButton.icon(
              onPressed: () => showAppSheet(context, (_) => const CategoriesSheet()),
              icon: const Icon(Icons.category_rounded, size: IconSizes.md),
              label: const Text('Categorías'),
            ),
          ],
        ),
        const VGap.xs(),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 520 ? 3 : 2;
          final w = (c.maxWidth - Gap.xs * (cols - 1)) / cols;
          return Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (var i = 0; i < orden.length; i++)
                SizedBox(
                  width: w,
                  child: Entrance(
                    index: i,
                    child: _BudgetTile(categoria: orden[i], estado: estados[orden[i].valor]!, mes: mes),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.categoria, required this.estado, required this.mes});
  final CategoriaFinanzas categoria;
  final EstadoCategoria estado;
  final DateTime mes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = estado;
    final color = switch (e.estado) {
      EstadoPresupuesto.excedido => p.danger,
      EstadoPresupuesto.alerta => p.warning,
      EstadoPresupuesto.ok => p.success,
      EstadoPresupuesto.sinLimite => p.textSecondary,
    };
    return AppCard(
      padding: const EdgeInsets.all(Gap.sm),
      borderColor: e.estado == EstadoPresupuesto.excedido ? p.danger.withValues(alpha: 0.5) : null,
      onTap: () => showAppSheet(context, (_) => BudgetSheet(categoria: categoria, estado: e, mes: mes)),
      semanticLabel: '${categoria.label}: gastado ${cop(e.gastado)}${e.limite > 0 ? ' de ${cop(e.limite)}' : ', sin límite'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconBadge(iconoPorNombre(categoria.icono), color: colorCategoria(categoria.valor), size: 34),
            const Spacer(),
            if (e.estado == EstadoPresupuesto.excedido) Icon(Icons.error_rounded, color: p.danger, size: IconSizes.md),
            if (e.estado == EstadoPresupuesto.alerta) Icon(Icons.warning_amber_rounded, color: p.warning, size: IconSizes.md),
          ]),
          const VGap.xs(),
          Text(categoria.label, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(cop(e.gastado), style: context.text.titleMedium?.copyWith(color: e.limite > 0 ? color : p.text)),
          const SizedBox(height: 6),
          if (e.limite > 0) ...[
            ProgressBar(value: e.pct, color: color, height: 6),
            const SizedBox(height: 4),
            Text(
              '${(e.pct * 100).toStringAsFixed(0)}% de ${cop(e.limite)}${e.heredado ? ' · mes anterior' : ''}',
              style: context.text.labelSmall?.copyWith(letterSpacing: 0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            Text('Sin límite · tocar para fijar', style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Planificador ───────────────────────────

class PlannerTab extends ConsumerWidget {
  const PlannerTab({super.key, required this.mes, required this.dia});
  final DateTime mes;
  final String? dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final ocurrencias = ref.watch(ocurrenciasMesProvider((mes.year, mes.month)));
    final planes = ref.watch(planesProvider).value ?? const <IngresoPlanificado>[];
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final visibles = dia == null ? ocurrencias : ocurrencias.where((o) => o.fechaEsperada == dia).toList();
    final pendiente = ocurrencias.where((o) => !o.verificado).fold(0.0, (s, o) => s + o.plan.monto);
    final recibido = ocurrencias.where((o) => o.verificado).fold(0.0, (s, o) => s + o.verificacion!.montoReal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => showAppSheet(context, (_) => const PlanSheet()),
          icon: const Icon(Icons.event_repeat_rounded),
          label: const Text('Nuevo ingreso planificado'),
        ),
        const VGap.md(),
        if (ocurrencias.isNotEmpty) ...[
          Row(children: [
            Expanded(child: StatTile(label: 'Por recibir', value: AnimatedMoney(pendiente), icon: Icons.hourglass_top_rounded, color: p.gold)),
            const HGap.xs(),
            Expanded(child: StatTile(label: 'Recibido', value: AnimatedMoney(recibido), icon: Icons.verified_rounded, color: p.success)),
          ]),
          const VGap.md(),
        ],
        SectionHeader(
          dia == null ? 'Esperados en ${mesesLargos[mes.month - 1].toLowerCase()}' : 'Esperados el ${fechaCorta(dia!)}',
          icon: Icons.inbox_rounded,
        ),
        if (visibles.isEmpty)
          EmptyState(
            icon: Icons.event_available_rounded,
            title: planes.isEmpty ? 'Planifica tus ingresos' : 'Nada esperado aquí',
            message: planes.isEmpty
                ? 'Registra tu salario u otros pagos recurrentes y confírmalos cuando lleguen: el saldo se actualiza solo.'
                : 'No hay ingresos planificados para ${dia == null ? 'este mes' : 'este día'}.',
            compact: true,
          ),
        for (var i = 0; i < visibles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Entrance(index: i, child: _OcurrenciaTile(o: visibles[i])),
          ),
        if (planes.isNotEmpty) ...[
          const VGap.md(),
          const SectionHeader('Ingresos recurrentes', icon: Icons.settings_suggest_rounded),
          for (final pl in planes)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.xxs, Gap.xs),
                child: Row(children: [
                  IconBadge(Icons.work_rounded, color: pl.activo ? p.gold : p.textSecondary, size: 38),
                  const HGap.sm(),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pl.descripcion, style: context.text.titleSmall),
                      Text(
                        [
                          cop(pl.monto),
                          frecuenciaIngresoLabel(pl.frecuencia),
                          if (pl.cuentaId != null) cuentas.where((c) => c.id == pl.cuentaId).map((c) => c.nombre).firstOrNull ?? '',
                          if (!pl.activo) 'Pausado',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: context.text.bodySmall,
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                    onPressed: () async {
                      final ok = await confirmar(context,
                          titulo: '¿Eliminar "${pl.descripcion}"?',
                          mensaje: 'Se borra la planificación y sus confirmaciones. Los ingresos ya registrados se conservan.',
                          confirmar: 'Eliminar',
                          destructivo: true);
                      if (ok) await ref.read(financeRepoProvider).eliminarPlan(pl.id);
                    },
                  ),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

class _OcurrenciaTile extends ConsumerWidget {
  const _OcurrenciaTile({required this.o});
  final OcurrenciaIngreso o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final v = o.verificacion;
    final vencido = !o.verificado && o.fechaEsperada.compareTo(hoyYmd()) < 0;
    return AppCard(
      padding: const EdgeInsets.all(Gap.sm),
      borderColor: o.verificado ? p.success.withValues(alpha: 0.4) : (vencido ? p.warning.withValues(alpha: 0.5) : null),
      child: Row(
        children: [
          IconBadge(o.verificado ? Icons.verified_rounded : Icons.hourglass_top_rounded, color: o.verificado ? p.success : p.gold, size: 40),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.plan.descripcion, style: context.text.titleSmall),
              Text(
                o.verificado
                    ? 'Recibido ${cop(v!.montoReal)} el ${fechaCorta(v.fechaReal)}'
                    : '${cop(o.plan.monto)} · ${fechaConDia(o.fechaEsperada)}${vencido ? ' · atrasado' : ''}',
                style: context.text.bodySmall?.copyWith(color: vencido ? p.warning : null),
              ),
            ]),
          ),
          if (o.verificado)
            TextButton(
              onPressed: () async {
                final ok = await confirmar(context,
                    titulo: '¿Deshacer la confirmación?',
                    mensaje: 'Se eliminará el ingreso registrado y se restará del saldo de la cuenta.',
                    confirmar: 'Deshacer',
                    destructivo: true);
                if (ok) await ref.read(financeRepoProvider).deshacerVerificacion(v!);
              },
              child: const Text('Deshacer'),
            )
          else
            FilledButton(
              onPressed: () => showAppSheet(context, (_) => VerifySheet(ocurrencia: o)),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: Gap.md)),
              child: const Text('Confirmar'),
            ),
        ],
      ),
    );
  }
}
