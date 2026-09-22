import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/db/database.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/ui.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';

const _cNecesidades = Color(0xFF38BDF8);
const _cDeseos = Color(0xFFFB923C);
const _cAhorro = Color(0xFF34D399);

class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.mes, required this.dia, required this.txMes, required this.cuentas});

  final DateTime mes;
  final String? dia;
  final List<Transaccion> txMes;
  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final resumen = ResumenFinanciero(cuentas: cuentas, txMes: txMes);
    final regla = calcular503020(txMes);
    final nombreCat = ref.watch(nombreCategoriaProvider);
    final consejos = resumen.consejos(nombreCat);
    var i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dia != null) ...[
          Entrance(index: i++, child: _ResumenDia(fecha: dia!, txMes: txMes)),
          const VGap.md(),
          if (dia!.compareTo(hoyYmd()) > 0) ...[
            Entrance(index: i++, child: _ProyeccionCdt(fecha: dia!, cuentas: cuentas)),
          ],
        ],
        Entrance(
          index: i++,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader('Resumen de ${mesesLargos[mes.month - 1].toLowerCase()}', icon: Icons.account_balance_wallet_rounded),
                Row(
                  children: [
                    Expanded(child: StatTile(label: 'Ingresos', value: AnimatedMoney(resumen.ingresosMes), icon: Icons.north_east_rounded, color: p.success)),
                    const HGap.xs(),
                    Expanded(child: StatTile(label: 'Gastos', value: AnimatedMoney(resumen.gastosMes), icon: Icons.south_east_rounded, color: p.danger)),
                  ],
                ),
                const VGap.xs(),
                StatTile(
                  label: 'Balance neto',
                  value: AnimatedMoney(resumen.balanceMes, signed: true),
                  icon: Icons.balance_rounded,
                  color: resumen.balanceMes >= 0 ? p.success : p.danger,
                  caption: resumen.ingresosMes > 0 ? 'Tasa de ahorro: ${resumen.tasaAhorro.toStringAsFixed(1)}%' : null,
                ),
              ],
            ),
          ),
        ),
        const VGap.md(),
        Entrance(index: i++, child: _Regla503020Card(regla: regla)),
        const VGap.md(),
        SectionHeader('Consejos del experto económico', icon: Icons.support_agent_rounded),
        for (final c in consejos)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Entrance(index: i++, child: _ConsejoCard(consejo: c)),
          ),
      ],
    );
  }
}

class _ResumenDia extends StatelessWidget {
  const _ResumenDia({required this.fecha, required this.txMes});
  final String fecha;
  final List<Transaccion> txMes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final delDia = txMes.where((t) => t.fecha == fecha);
    final ing = delDia.where((t) => t.tipo == 'ingreso').fold(0.0, (s, t) => s + t.monto);
    final gas = delDia.where((t) => t.tipo == 'gasto').fold(0.0, (s, t) => s + t.monto);
    return AppCard(
      borderColor: p.accent.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(fechaConDia(fecha), icon: Icons.today_rounded, subtitle: fechaRelativa(fecha)),
          Row(children: [
            Expanded(child: StatTile(label: 'Ingresos', value: AnimatedMoney(ing), color: p.success)),
            const HGap.xs(),
            Expanded(child: StatTile(label: 'Gastos', value: AnimatedMoney(gas), color: p.danger)),
            const HGap.xs(),
            Expanded(child: StatTile(label: 'Balance', value: AnimatedMoney(ing - gas), color: ing - gas >= 0 ? p.success : p.danger)),
          ]),
          const VGap.sm(),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.tips_and_updates_rounded, size: IconSizes.md, color: p.gold),
            const HGap.xs(),
            Expanded(child: Text(consejoDelDia(ing, gas), style: context.text.bodySmall)),
          ]),
        ],
      ),
    );
  }
}

/// Cuánto habrán rendido los CDT / cajitas en una fecha futura.
class _ProyeccionCdt extends StatelessWidget {
  const _ProyeccionCdt({required this.fecha, required this.cuentas});
  final String fecha;
  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cdts = cuentas.where((c) => c.tipo == 'cdt' && c.interesTasa > 0).toList();
    if (cdts.isEmpty) return const SizedBox.shrink();
    final actual = cdts.fold(0.0, (s, c) => s + c.saldo);
    final proyectado = cdts.fold(0.0, (s, c) => s + saldoProyectado(c, fecha));
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: AppCard(
        gradient: LinearGradient(colors: [Color.alphaBlend(p.gold.withValues(alpha: 0.12), p.surface), p.surface]),
        borderColor: p.gold.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Proyección de rendimientos', icon: Icons.insights_rounded, subtitle: 'Al ${fechaLarga(fecha)}'),
            Text('Interés acumulado estimado', style: context.text.bodySmall),
            AnimatedMoney(proyectado - actual, signed: true, style: context.text.headlineSmall?.copyWith(color: p.gold)),
            Text('Saldo proyectado: ${cop(proyectado)}', style: context.text.bodySmall),
            const VGap.sm(),
            for (final c in cdts)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Row(children: [
                  Expanded(child: Text('${c.nombre} · ${c.interesTasa}% E.A.', style: context.text.bodyMedium)),
                  Text('+${cop(saldoProyectado(c, fecha) - c.saldo)}', style: context.text.titleSmall?.copyWith(color: p.success)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Regla503020Card extends StatelessWidget {
  const _Regla503020Card({required this.regla});
  final Regla503020 regla;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = regla;
    Widget estado(Semaforo s) => Icon(
          switch (s) { Semaforo.ok => Icons.check_circle_rounded, Semaforo.alerta => Icons.warning_amber_rounded, Semaforo.mal => Icons.error_rounded },
          size: IconSizes.md,
          color: switch (s) { Semaforo.ok => p.success, Semaforo.alerta => p.warning, Semaforo.mal => p.danger },
        );
    Widget fila(String titulo, String sub, String ideal, Color c, double pct, double val, Semaforo s) => Padding(
          padding: const EdgeInsets.only(top: Gap.sm),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
              const HGap.xs(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: context.text.titleSmall),
                    Text(sub, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${pct.toStringAsFixed(0)}% / $ideal', style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  Text(cop(val), style: context.text.bodySmall),
                ],
              ),
              const HGap.xs(),
              estado(s),
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Regla 50 / 30 / 20', icon: Icons.donut_small_rounded, subtitle: '50% necesidades · 30% deseos · 20% ahorro'),
          if (!r.hayDatos)
            Text('Registra ingresos este mes para ver cómo se distribuye tu dinero.', style: context.text.bodyMedium?.copyWith(color: p.textSecondary))
          else ...[
            // Barra apilada que crece con animación.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.of(context, const Duration(milliseconds: 900)),
                  curve: Motion.enter,
                  builder: (_, t, _) {
                    final n = (r.pctNecesidades * t).clamp(0, 100).toDouble();
                    final d = (r.pctDeseos * t).clamp(0, 100 - n).toDouble();
                    final a = (r.pctAhorro.clamp(0, 100) * t).clamp(0, 100 - n - d).toDouble();
                    return Row(children: [
                      if (n > 0) Expanded(flex: (n * 10).round().clamp(1, 1000), child: Container(color: _cNecesidades)),
                      if (d > 0) Expanded(flex: (d * 10).round().clamp(1, 1000), child: Container(color: _cDeseos)),
                      if (a > 0) Expanded(flex: (a * 10).round().clamp(1, 1000), child: Container(color: _cAhorro)),
                      if (100 - n - d - a > 0.5) Expanded(flex: ((100 - n - d - a) * 10).round(), child: Container(color: p.surfaceHighest)),
                    ]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.ahorro < 0 ? 'Estás gastando más de lo que ingresas' : 'Distribución de ${cop(r.ingresos)} en ingresos',
              style: context.text.bodySmall?.copyWith(color: r.ahorro < 0 ? p.danger : null),
            ),
            fila('Necesidades', 'Vivienda, comida, servicios, salud', '50%', _cNecesidades, r.pctNecesidades, r.necesidades, r.estadoNecesidades),
            fila('Deseos', 'Ocio, entretenimiento, antojos', '30%', _cDeseos, r.pctDeseos, r.deseos, r.estadoDeseos),
            fila('Ahorro / deuda', 'Lo que no gastas + aportes', '20%', _cAhorro, r.pctAhorro, r.ahorro, r.estadoAhorro),
            const VGap.sm(),
            Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.tips_and_updates_rounded, size: IconSizes.md, color: p.gold),
                const HGap.xs(),
                Expanded(child: Text(r.diagnostico, style: context.text.bodySmall?.copyWith(color: p.text))),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsejoCard extends StatelessWidget {
  const _ConsejoCard({required this.consejo});
  final Consejo consejo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = switch (consejo.tipo) {
      TipoConsejo.exito => p.success,
      TipoConsejo.info => p.info,
      TipoConsejo.alerta => p.warning,
      TipoConsejo.peligro => p.danger,
    };
    return AppCard(
      color: Color.alphaBlend(c.withValues(alpha: 0.06), p.surface),
      borderColor: c.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(consejo.icon, color: c, size: 40),
          const HGap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consejo.titulo, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(consejo.texto, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
