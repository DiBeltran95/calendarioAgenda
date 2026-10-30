import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../data/models.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/ui.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';

class ChartsTab extends ConsumerWidget {
  const ChartsTab({super.key, required this.cuentas});
  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final rango = ref.watch(rangoAnaliticaProvider);
    final txs = ref.watch(txAnaliticaProvider(rango)).value ?? const <Transaccion>[];
    final a = Analitica(cuentas: cuentas, transacciones: txs, rango: rango);
    final nombreCat = ref.watch(nombreCategoriaProvider);
    var i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedPill<RangoAnalitica>(
          options: [for (final r in RangoAnalitica.values) (r, r.label, null)],
          value: rango,
          onChanged: (r) => ref.read(rangoAnaliticaProvider.notifier).set(r),
        ),
        const VGap.md(),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Gap.xs,
          crossAxisSpacing: Gap.xs,
          childAspectRatio: 1.9,
          children: [
            StatTile(label: 'Ingresos', value: AnimatedMoney(a.ingresos), icon: Icons.north_east_rounded, color: p.success),
            StatTile(label: 'Gastos', value: AnimatedMoney(a.gastos), icon: Icons.south_east_rounded, color: p.danger),
            StatTile(label: 'Balance', value: AnimatedMoney(a.neto, signed: true), icon: Icons.balance_rounded, color: a.neto >= 0 ? p.success : p.danger),
            StatTile(label: 'Gasto diario', value: AnimatedMoney(a.gastoDiario), icon: Icons.calendar_view_day_rounded, color: p.warning),
          ],
        ),
        const VGap.md(),
        Entrance(index: i++, child: _Card(icon: Icons.show_chart_rounded, titulo: 'Patrimonio neto', sub: 'Ahorros + inversiones − tarjetas', child: _LineaPatrimonio(a: a))),
        const VGap.md(),
        if (a.porMes.isNotEmpty) ...[
          Entrance(index: i++, child: _Card(icon: Icons.bar_chart_rounded, titulo: 'Ingresos vs gastos', sub: 'Por mes', child: _BarrasMes(a: a))),
          const VGap.md(),
        ],
        Entrance(
          index: i++,
          child: _Card(icon: Icons.waterfall_chart_rounded, titulo: 'Flujo de caja diario', sub: 'Últimos ${a.flujoDiario.length} días', child: _FlujoDiario(a: a)),
        ),
        const VGap.md(),
        Entrance(
          index: i++,
          child: _Card(
            icon: Icons.donut_large_rounded,
            titulo: 'Gastos por categoría',
            sub: 'Toca una porción para ver el detalle',
            child: a.gastosPorCategoria.isEmpty ? const _SinDatos() : _Dona(datos: a.gastosPorCategoria, total: a.gastos, nombre: nombreCat),
          ),
        ),
        const VGap.md(),
        if (a.topGastos.isNotEmpty) ...[
          Entrance(
            index: i++,
            child: _Card(
              icon: Icons.leaderboard_rounded,
              titulo: 'Gastos más grandes',
              sub: 'Top ${a.topGastos.length} del periodo',
              child: Column(children: [
                for (final (k, t) in a.topGastos.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 22, child: Text('${k + 1}', style: context.text.labelMedium)),
                      Container(width: 4, height: 28, decoration: BoxDecoration(color: colorCategoria(context, t.categoria), borderRadius: BorderRadius.circular(2))),
                      const HGap.xs(),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.descripcion.isEmpty ? nombreCat(t.categoria) : t.descripcion,
                              style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${nombreCat(t.categoria)} · ${fechaCorta(t.fecha)}', style: context.text.bodySmall),
                        ]),
                      ),
                      Text(cop(t.monto), style: context.text.titleSmall?.copyWith(color: p.danger)),
                    ]),
                  ),
              ]),
            ),
          ),
          const VGap.md(),
        ],
        if (a.ingresosPorCategoria.isNotEmpty)
          Entrance(
            index: i++,
            child: _Card(
              icon: Icons.account_balance_rounded,
              titulo: 'Fuentes de ingreso',
              sub: 'Por categoría',
              child: Column(children: [
                for (final e in a.ingresosPorCategoria)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(nombreCat(e.key), style: context.text.bodyMedium)),
                        Text(cop(e.value), style: context.text.titleSmall),
                      ]),
                      const SizedBox(height: 4),
                      ProgressBar(value: a.ingresos > 0 ? e.value / a.ingresos : 0, color: p.success, height: 6),
                    ]),
                  ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.titulo, required this.sub, required this.child});
  final IconData icon;
  final String titulo;
  final String sub;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionHeader(titulo, icon: icon, subtitle: sub), child],
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos();
  @override
  Widget build(BuildContext context) =>
      const EmptyState(icon: Icons.query_stats_rounded, title: 'Sin datos en este periodo', message: 'Registra movimientos para ver tus gráficas.', compact: true);
}

FlTitlesData _titulos(BuildContext context, {required Widget Function(double, TitleMeta) bottom, double reserved = 44}) {
  final estilo = context.text.labelSmall?.copyWith(letterSpacing: 0);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reserved,
        getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(copCompacto(v), style: estilo)),
      ),
    ),
    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: bottom)),
  );
}

FlGridData _grid(Palette p) => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1),
    );

class _LineaPatrimonio extends StatelessWidget {
  const _LineaPatrimonio({required this.a});
  final Analitica a;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pts = a.patrimonio;
    if (pts.isEmpty) return const _SinDatos();
    final vals = pts.map((e) => e.valor).toList();
    var mn = vals.reduce(math.min), mx = vals.reduce(math.max);
    var d = mx - mn;
    if (d == 0) d = mx.abs() > 0 ? mx.abs() * 0.2 : 100000;
    mn -= d * 0.1;
    mx += d * 0.1;
    final estilo = context.text.labelSmall?.copyWith(letterSpacing: 0);
    final paso = math.max(1, (pts.length / 4).floor());
    return SizedBox(
      height: 200,
      child: LineChart(
        duration: Motion.of(context, const Duration(milliseconds: 600)),
        curve: Motion.enter,
        LineChartData(
          minY: mn,
          maxY: mx,
          gridData: _grid(p),
          borderData: FlBorderData(show: false),
          titlesData: _titulos(
            context,
            bottom: (v, meta) {
              final i = v.round();
              if (i < 0 || i >= pts.length || i % paso != 0) return const SizedBox.shrink();
              return SideTitleWidget(meta: meta, child: Text(fechaCorta(pts[i].fecha), style: estilo));
            },
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => p.surfaceHighest,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem('${fechaCorta(pts[s.x.round()].fecha)}\n${cop(s.y)}', context.text.labelMedium!.copyWith(color: p.text)),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].valor)],
              isCurved: true,
              preventCurveOverShooting: true,
              color: p.accent,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.accent.withValues(alpha: 0.35), p.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarrasMes extends StatelessWidget {
  const _BarrasMes({required this.a});
  final Analitica a;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final estilo = context.text.labelSmall?.copyWith(letterSpacing: 0);
    final datos = a.porMes;
    final mx = datos.fold(0.0, (m, b) => math.max(m, math.max(b.ingresos, b.gastos)));
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: BarChart(
            duration: Motion.of(context, const Duration(milliseconds: 600)),
            curve: Motion.enter,
            BarChartData(
              maxY: mx == 0 ? 1 : mx * 1.15,
              gridData: _grid(p),
              borderData: FlBorderData(show: false),
              titlesData: _titulos(context, bottom: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= datos.length) return const SizedBox.shrink();
                final partes = datos[i].mes.split('-');
                return SideTitleWidget(meta: meta, child: Text('${mesesCortos[int.parse(partes[1]) - 1]} ${partes[0].substring(2)}', style: estilo));
              }),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => p.surfaceHighest,
                  getTooltipItem: (g, _, rod, ri) => BarTooltipItem(
                    '${ri == 0 ? 'Ingresos' : 'Gastos'}\n${cop(rod.toY)}',
                    context.text.labelMedium!.copyWith(color: p.text),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < datos.length; i++)
                  BarChartGroupData(x: i, barsSpace: 4, barRods: [
                    BarChartRodData(toY: datos[i].ingresos, color: p.success, width: 10, borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(toY: datos[i].gastos, color: p.danger, width: 10, borderRadius: BorderRadius.circular(3)),
                  ]),
              ],
            ),
          ),
        ),
        const VGap.xs(),
        _Leyenda(items: [('Ingresos', p.success), ('Gastos', p.danger)]),
      ],
    );
  }
}

class _FlujoDiario extends StatelessWidget {
  const _FlujoDiario({required this.a});
  final Analitica a;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = a.flujoDiario;
    final estilo = context.text.labelSmall?.copyWith(letterSpacing: 0);
    final mx = d.fold(0.0, (m, x) => math.max(m, math.max(x.$2, x.$3)));
    if (mx == 0) return const _SinDatos();
    final paso = math.max(1, (d.length / 5).floor());
    return Column(children: [
      SizedBox(
        height: 180,
        child: BarChart(
          duration: Motion.of(context, const Duration(milliseconds: 600)),
          BarChartData(
            maxY: mx * 1.15,
            minY: -mx * 1.15,
            gridData: _grid(p),
            borderData: FlBorderData(show: false),
            titlesData: _titulos(context, bottom: (v, meta) {
              final i = v.round();
              if (i < 0 || i >= d.length || i % paso != 0) return const SizedBox.shrink();
              return SideTitleWidget(meta: meta, child: Text('${parseYmd(d[i].$1).day}', style: estilo));
            }),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => p.surfaceHighest,
                getTooltipItem: (g, _, rod, ri) => BarTooltipItem(
                  '${fechaCorta(d[g.x].$1)}\n${ri == 0 ? '+' : '-'}${cop(rod.toY.abs())}',
                  context.text.labelMedium!.copyWith(color: p.text),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < d.length; i++)
                BarChartGroupData(x: i, groupVertically: true, barRods: [
                  BarChartRodData(toY: d[i].$2, color: p.success, width: 6, borderRadius: BorderRadius.circular(2)),
                  BarChartRodData(toY: -d[i].$3, color: p.danger, width: 6, borderRadius: BorderRadius.circular(2)),
                ]),
            ],
          ),
        ),
      ),
      const VGap.xs(),
      _Leyenda(items: [('Entradas', p.success), ('Salidas', p.danger)]),
    ]);
  }
}

class _Dona extends StatefulWidget {
  const _Dona({required this.datos, required this.total, required this.nombre});
  final List<MapEntry<String, double>> datos;
  final double total;
  final String Function(String) nombre;

  @override
  State<_Dona> createState() => _DonaState();
}

class _DonaState extends State<_Dona> {
  int _tocado = -1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final datos = widget.datos;
    final sel = _tocado >= 0 && _tocado < datos.length ? datos[_tocado] : null;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                duration: Motion.of(context, const Duration(milliseconds: 500)),
                curve: Motion.enter,
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 58,
                  pieTouchData: PieTouchData(
                    touchCallback: (e, r) {
                      if (!e.isInterestedForInteractions || r?.touchedSection == null) return;
                      setState(() => _tocado = r!.touchedSection!.touchedSectionIndex);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < datos.length; i++)
                      PieChartSectionData(
                        value: datos[i].value,
                        color: colorCategoria(context, datos[i].key),
                        radius: i == _tocado ? 34 : 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              SmoothSwitcher(
                child: Column(
                  key: ValueKey(_tocado),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sel == null ? 'Total' : widget.nombre(sel.key), style: context.text.labelMedium),
                    Text(cop(sel?.value ?? widget.total), style: context.text.titleMedium),
                    if (sel != null) Text('${(sel.value / widget.total * 100).toStringAsFixed(1)}%', style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VGap.sm(),
        for (var i = 0; i < datos.length; i++)
          InkWell(
            borderRadius: Radii.rSm,
            onTap: () => setState(() => _tocado = _tocado == i ? -1 : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colorCategoria(context, datos[i].key), borderRadius: BorderRadius.circular(3))),
                const HGap.xs(),
                Expanded(
                  child: Text(widget.nombre(datos[i].key),
                      style: context.text.bodyMedium?.copyWith(fontWeight: i == _tocado ? FontWeight.w700 : null)),
                ),
                Text('${(datos[i].value / widget.total * 100).toStringAsFixed(0)}%', style: context.text.bodySmall),
                const HGap.sm(),
                Text(cop(datos[i].value), style: context.text.titleSmall?.copyWith(color: p.text)),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: Gap.md, alignment: WrapAlignment.center, children: [
      for (final (l, c) in items)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(l, style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
        ]),
    ]);
  }
}
