import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../finance_providers.dart';
import '../plan_ciclo.dart';

const _cFijos = ColorPar(Color(0xFF0369A1), Color(0xFF38BDF8));
const _cAhorro = ColorPar(Color(0xFF047857), Color(0xFF34D399));
const _cLibre = ColorPar(Color(0xFFB83D0B), Color(0xFFFB923C));

/// Cómo se ve cada ritmo: siempre con ícono y texto, no solo color.
({IconData icono, Color color, String texto}) aspectoRitmo(BuildContext context, PlanCiclo plan) {
  final p = context.palette;
  if (plan.libre <= 0) return (icono: Icons.error_rounded, color: p.danger, texto: 'No queda para el día a día');
  return switch (plan.ritmo) {
    Ritmo.bien => (icono: Icons.check_circle_rounded, color: p.success, texto: 'Vas bien'),
    Ritmo.pocoRapido => (icono: Icons.warning_amber_rounded, color: p.warning, texto: 'Vas un poco rápido'),
    Ritmo.rapido => (icono: Icons.error_rounded, color: p.danger, texto: 'Vas rápido'),
  };
}

/// "Faltan 12 días · pago el 15 nov" o, sin sueldo, hasta fin de mes.
String faltanParaElPago(PlanCiclo plan) {
  final n = plan.diasRestantes;
  final dias = n == 1 ? 'Último día' : 'Faltan $n días';
  return plan.conSueldo ? '$dias · pago el ${fechaCorta(plan.proximoPago)}' : '$dias para fin de mes';
}

/// Cuánto se puede gastar hoy y a dónde va el sueldo hasta el próximo pago.
class PlanCicloCard extends ConsumerWidget {
  const PlanCicloCard({super.key, required this.plan});
  final PlanCiclo plan;

  void _irAlPlanificador(WidgetRef ref) => ref.read(finTabProvider.notifier).set(FinTab.planificador);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final r = aspectoRitmo(context, plan);
    final cifras = context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    if (plan.ingresos <= 0) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader('Hasta tu próximo pago', icon: Icons.event_available_rounded, subtitle: faltanParaElPago(plan)),
          Text(
            'Agrega tu sueldo en el Planificador y te diremos cuánto puedes gastar cada día sin quedarte corto antes del pago.',
            style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
          ),
          const VGap.sm(),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(onPressed: () => _irAlPlanificador(ref), icon: const Icon(Icons.add_rounded), label: const Text('Agregar sueldo')),
          ),
        ]),
      );
    }

    final libre = plan.libre;
    final gastado = plan.gastadoLibre;
    Widget fila(String titulo, String detalle, double monto, Color color, {VoidCallback? alTocar}) {
      final contenido = Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const HGap.xs(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(titulo, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (alTocar != null) ...[
                  const SizedBox(width: Gap.xxs),
                  Icon(Icons.edit_rounded, size: IconSizes.sm, color: p.textSecondary),
                ],
              ]),
              // Que "$" no quede en una línea y la cifra en la otra.
              Text(detalle.replaceAll('\$ ', '\$ '), style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const HGap.xs(),
          Text(cop(monto), style: cifras),
        ]),
      );
      if (alTocar == null) return contenido;
      return Pressable(onTap: alTocar, borderRadius: Radii.rMd, semanticLabel: '$titulo, ${cop(monto)}. Toca para cambiarlo.', child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: contenido));
    }

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader('Hasta tu próximo pago', icon: Icons.event_available_rounded, subtitle: faltanParaElPago(plan)),
        Semantics(
          label: 'Puedes gastar hoy ${cop(plan.puedesHoy)}. ${r.texto}.',
          excludeSemantics: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Puedes gastar hoy', style: context.text.bodySmall),
            AnimatedMoney(plan.puedesHoy, style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
            if (plan.gastadoHoy > 0)
              Text(
                plan.puedesHoy > 0
                    ? 'De ${cop(plan.porDia)} al día · hoy ya van ${cop(plan.gastadoHoy)}'
                    : 'Hoy ya van ${cop(plan.gastadoHoy)}. Desde mañana: ${cop(plan.porDiaDesdeManana)} al día',
                style: context.text.bodySmall,
              ),
            const SizedBox(height: Gap.xs),
            Tag(r.texto, color: r.color, icon: r.icono),
          ]),
        ),
        const VGap.md(),
        Row(children: [
          Expanded(child: Text(plan.conSueldo ? 'Sueldo esperado' : 'Ingresos del mes', style: context.text.titleSmall)),
          Text(cop(plan.ingresos), style: cifras),
        ]),
        if (plan.conSueldo && plan.extras > 0) Text('Incluye ${cop(plan.extras)} de otros ingresos', style: context.text.bodySmall),
        const VGap.xs(),
        _BarraPlan(plan: plan),
        const VGap.xs(),
        fila(
          'Fijos',
          plan.fijos > 0 ? 'Pagado ${cop(plan.fijosPagados)} · falta ${cop(plan.fijosPendientes)}' : 'Agenda en Eventos el arriendo, los servicios y las cuotas',
          plan.fijos,
          context.par(_cFijos),
        ),
        fila(
          'Ahorro (${plan.ahorroPct}%)',
          plan.ahorroPct > 0 ? 'Apártalo apenas te paguen' : 'Toca para apartar una parte del sueldo',
          plan.ahorro,
          context.par(_cAhorro),
          alTocar: () => showAppSheet(context, (_) => _AhorroSheet(actual: plan.ahorroPct)),
        ),
        fila(
          'Libre',
          libre > 0 ? 'Gastado ${cop(gastado)} de ${cop(libre)}' : 'Tus fijos y tu ahorro superan lo que entra',
          libre,
          context.par(_cLibre),
        ),
        if (plan.conTarjeta > 0) ...[
          const VGap.xs(),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.credit_card_rounded, size: IconSizes.md, color: p.info),
            const HGap.xs(),
            Expanded(child: Text('Con tarjeta: ${cop(plan.conTarjeta)} en este ciclo. Se paga en cuotas, que aparecen en tus fijos cuando se cobran.', style: context.text.bodySmall)),
          ]),
        ],
        if (!plan.conSueldo) ...[
          const VGap.sm(),
          Container(
            padding: const EdgeInsets.all(Gap.sm),
            decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd),
            child: Row(children: [
              Icon(Icons.tips_and_updates_rounded, size: IconSizes.md, color: p.gold),
              const HGap.xs(),
              Expanded(child: Text('Agrega tu sueldo para contar de un pago al siguiente.', style: context.text.bodySmall?.copyWith(color: p.text))),
              TextButton(onPressed: () => _irAlPlanificador(ref), child: const Text('Agregar')),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Fijos, ahorro, lo gastado de lo libre y lo que queda, en una sola barra.
class _BarraPlan extends StatelessWidget {
  const _BarraPlan({required this.plan});
  final PlanCiclo plan;

  @override
  Widget build(BuildContext context) {
    final total = [plan.ingresos, plan.fijos + plan.ahorro + plan.gastadoLibre].reduce((a, b) => a > b ? a : b);
    final libre = plan.libre.clamp(0.0, double.infinity);
    final gastado = plan.gastadoLibre.clamp(0.0, libre > 0 ? double.infinity : 0.0);
    final partes = [
      (plan.fijos, context.par(_cFijos)),
      (plan.ahorro, context.par(_cAhorro)),
      (gastado, context.par(_cLibre)),
      ((libre - gastado).clamp(0.0, double.infinity), context.par(_cLibre).withValues(alpha: 0.3)),
    ];
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.of(context, const Duration(milliseconds: 900)),
            curve: Motion.enter,
            builder: (_, t, _) {
              final usado = partes.fold(0.0, (s, x) => s + x.$1) * t;
              return Row(children: [
                for (final (v, c) in partes)
                  if (v > 0 && total > 0) Expanded(flex: (v * t / total * 1000).round().clamp(1, 1000), child: Container(color: c)),
                if (total > usado) Expanded(flex: ((total - usado) / total * 1000).round().clamp(1, 1000), child: Container(color: context.palette.surfaceHighest)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _AhorroSheet extends ConsumerStatefulWidget {
  const _AhorroSheet({required this.actual});
  final int actual;

  @override
  ConsumerState<_AhorroSheet> createState() => _AhorroSheetState();
}

class _AhorroSheetState extends ConsumerState<_AhorroSheet> {
  late int _pct = widget.actual;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Págate primero',
      subtitle: 'Cuánto de cada sueldo apartas apenas te paguen',
      icon: Icons.savings_rounded,
      primaryLabel: 'Guardar',
      onPrimary: () async {
        final nav = Navigator.of(context);
        await ref.read(ajustesRepoProvider).setAhorroPct(_pct);
        HapticFeedback.lightImpact();
        nav.pop();
      },
      hayCambios: () => _pct != widget.actual,
      children: [
        Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
          for (final v in porcentajesAhorro) ChoiceChip(label: Text('$v%'), selected: _pct == v, onSelected: (_) => setState(() => _pct = v)),
        ]),
        const VGap.sm(),
        Text(
          'Lo recomendado es entre el 10% y el 20%. Si hoy no alcanza, empieza con poco: lo importante es apartarlo antes de gastar, no lo que sobre al final.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}
