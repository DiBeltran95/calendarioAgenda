import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/fab_animado.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/sync.dart';
import '../../core/widgets/month_calendar.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import '../events/events_repository.dart';
import 'finance_logic.dart';
import 'finance_providers.dart';
import 'pagos/pagos_repository.dart';
import 'sheets/finance_sheets.dart';
import 'sheets/transaction_sheet.dart';
import 'tabs/accounts_tab.dart';
import 'tabs/charts_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/planning_tabs.dart';
import 'tabs/summary_tab.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesFinanzasProvider);
    final sel = ref.watch(diaFinanzasProvider);
    final tab = ref.watch(finTabProvider);
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final txMes = ref.watch(txMesProvider((mes.year, mes.month))).value ?? const <Transaccion>[];
    final eventos = ref.watch(eventosMesProvider((mes.year, mes.month))).value ?? const <Evento>[];
    final ocurrencias = ref.watch(ocurrenciasMesProvider((mes.year, mes.month)));
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();

    // Neto por día y pendientes para la rejilla.
    final neto = <String, double>{};
    for (final t in txMes) {
      neto[t.fecha] = (neto[t.fecha] ?? 0) + (t.tipo == 'ingreso' ? t.monto : -t.monto);
    }
    final pagosPendientes = {
      for (final e in eventos)
        if (e.tipoTransaccion != 'ninguno' && e.estadoPago == 'pendiente') e.fecha,
    };
    final ingresosEsperados = {
      for (final o in ocurrencias)
        if (!o.verificado) o.fechaEsperada,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FabAnimado(
        heroTag: 'fab-finanzas',
        onPressed: () => abrirTransaccion(context, fecha: sel ?? hoyYmd()),
        icono: Icons.add_rounded,
        etiqueta: 'Movimiento',
      ),
      body: SafeArea(
        bottom: false,
        child: ModuleLayout(
          onRefresh: () => ref.read(sincronizadorProvider).refrescarTodo(),
          primary: [
            ModuleHeader(
              overline: saludo(ref.watch(sesionProvider).value?.usuario.primerNombre ?? ''),
              title: AppModule.finanzas.label,
              actions: [
                const _BotonPagos(),
                if (cuentas.length >= 2)
                  IconButton(
                    tooltip: 'Transferir entre cuentas',
                    onPressed: () => showAppSheet(context, (_) => const TransferSheet()),
                    icon: const Icon(Icons.swap_horiz_rounded),
                  ),
              ],
            ),
            CargandoBarra(visible: ref.watch(monthProvider((mes.year, mes.month))).isLoading && !ref.watch(monthProvider((mes.year, mes.month))).hasValue),
            Entrance(
              child: _Patrimonio(cuentas: cuentas, txMes: txMes),
            ),
            if (!prefs.onboardingFinanzasOculto) ...[const VGap.sm(), const _Onboarding()],
            const VGap.sm(),
            Entrance(
              index: 1,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.sm),
                child: MonthCalendar(
                  cursor: mesFinanzasProvider,
                  selected: sel,
                  onTap: (f) => ref.read(diaFinanzasProvider.notifier).alternar(f),
                  onLongPress: (f) {
                    ref.read(diaFinanzasProvider.notifier).seleccionar(f);
                    abrirTransaccion(context, fecha: f);
                  },
                  semantics: (d) {
                    final n = neto[d.fecha];
                    return '${fechaConDia(d.fecha)}${n != null ? ', balance ${cop(n)}' : ''}'
                        '${pagosPendientes.contains(d.fecha) ? ', pago pendiente' : ''}'
                        '${ingresosEsperados.contains(d.fecha) ? ', ingreso esperado' : ''}';
                  },
                  cellBuilder: (context, d) => _FinDayCell(
                    day: d,
                    neto: neto[d.fecha],
                    pagoPendiente: pagosPendientes.contains(d.fecha),
                    ingresoEsperado: ingresosEsperados.contains(d.fecha),
                  ),
                  footer: const _LeyendaFin(),
                ),
              ),
            ),
          ],
          secondary: [
            const VGap.md(),
            const _Tabs(),
            const VGap.md(),
            SmoothSwitcher(
              child: KeyedSubtree(
                key: ValueKey('${tab.name}-${sel ?? ''}-${mes.month}'),
                child: switch (tab) {
                  FinTab.resumen => SummaryTab(mes: mes, dia: sel, txMes: txMes, cuentas: cuentas),
                  FinTab.cuentas => AccountsTab(cuentas: cuentas, mes: mes),
                  FinTab.metas => const GoalsTab(),
                  FinTab.presupuesto => BudgetTab(mes: mes, txMes: txMes),
                  FinTab.planificador => PlannerTab(mes: mes, dia: sel),
                  FinTab.historial => HistoryTab(mes: mes, dia: sel, txMes: txMes),
                  FinTab.graficos => ChartsTab(cuentas: cuentas),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Patrimonio ───────────────────────────

class _Patrimonio extends StatelessWidget {
  const _Patrimonio({required this.cuentas, required this.txMes});
  final List<Cuenta> cuentas;
  final List<Transaccion> txMes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = ResumenFinanciero(cuentas: cuentas, txMes: txMes);
    return AppCard(
      padding: const EdgeInsets.all(Gap.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(p.accent.withValues(alpha: context.isDark ? 0.22 : 0.14), p.surface),
          Color.alphaBlend(p.accent2.withValues(alpha: context.isDark ? 0.1 : 0.06), p.surface),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PATRIMONIO NETO', style: context.text.labelSmall?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 4),
          AnimatedMoney(
            r.patrimonio,
            style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: r.patrimonio < 0 ? p.danger : p.text),
          ),
          const VGap.md(),
          Row(
            children: [
              Expanded(
                child: _Mini(icon: Icons.savings_rounded, label: 'Ahorros e inversiones', valor: r.ahorros, color: p.success),
              ),
              Container(width: 1, height: 36, color: p.border),
              const HGap.md(),
              Expanded(
                child: _Mini(icon: Icons.credit_card_rounded, label: 'Deuda tarjetas', valor: r.deudaTarjetas, color: p.danger),
              ),
            ],
          ),
          if (r.cupoTarjetas > 0) ...[
            const VGap.sm(),
            ProgressBar(value: r.usoCredito / 100, color: r.usoCredito > 50 ? p.danger : (r.usoCredito > 30 ? p.warning : p.success), height: 6),
            const SizedBox(height: 4),
            Text('Uso de cupo: ${r.usoCredito.toStringAsFixed(0)}% de ${cop(r.cupoTarjetas)}', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.label, required this.valor, required this.color});
  final IconData icon;
  final String label;
  final double valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: IconSizes.md, color: color),
        const HGap.xs(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelSmall?.copyWith(letterSpacing: 0), maxLines: 1, overflow: TextOverflow.ellipsis),
              AnimatedMoney(valor, style: context.text.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Onboarding ───────────────────────────

/// Guía de primeros pasos (como la de la web): cuenta → ingreso → presupuesto.
class _Onboarding extends ConsumerWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cuentas = ref.watch(cuentasProvider).value ?? const [];
    final planes = ref.watch(planesProvider).value ?? const [];
    final pres = ref.watch(presupuestosProvider).value ?? const [];
    final pasos = [
      (cuentas.isNotEmpty, 'Agrega una cuenta', Icons.add_card_rounded, () => showAppSheet(context, (_) => const AccountSheet())),
      (planes.isNotEmpty, 'Planifica un ingreso', Icons.event_repeat_rounded, () => showAppSheet(context, (_) => const PlanSheet())),
      (pres.isNotEmpty, 'Fija un presupuesto', Icons.pie_chart_rounded, () => ref.read(finTabProvider.notifier).set(FinTab.presupuesto)),
    ];
    final hechos = pasos.where((s) => s.$1).length;
    final completo = hechos == pasos.length;

    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.enter,
      child: AppCard(
        borderColor: p.accent.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(completo ? Icons.emoji_events_rounded : Icons.rocket_launch_rounded, color: p.accent),
                const HGap.xs(),
                Expanded(
                  child: Text(
                    completo ? '¡Todo listo! Tus finanzas están configuradas' : 'Configura tus finanzas · $hechos de 3',
                    style: context.text.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Ocultar guía',
                  onPressed: () => ref.read(ajustesRepoProvider).setOnboardingFinanzasOculto(true),
                  icon: const Icon(Icons.close_rounded, size: IconSizes.md),
                ),
              ],
            ),
            ProgressBar(value: hechos / 3, height: 6),
            if (!completo) ...[
              const VGap.sm(),
              for (final (hecho, texto, icon, accion) in pasos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 4,
                  leading: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.medium),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(hecho ? Icons.check_circle_rounded : icon, key: ValueKey(hecho), color: hecho ? p.success : p.textSecondary),
                  ),
                  title: Text(
                    texto,
                    style: context.text.bodyMedium?.copyWith(decoration: hecho ? TextDecoration.lineThrough : null, color: hecho ? p.textSecondary : p.text),
                  ),
                  trailing: hecho ? null : Icon(Icons.chevron_right_rounded, color: p.textSecondary),
                  onTap: hecho ? null : accion,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Celda ───────────────────────────

class _FinDayCell extends StatelessWidget {
  const _FinDayCell({required this.day, required this.neto, required this.pagoPendiente, required this.ingresoEsperado});
  final CalendarDay day;
  final double? neto;
  final bool pagoPendiente;
  final bool ingresoEsperado;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final n = neto;
    return DayCellFrame(
      day: day,
      fill: n == null ? null : (n >= 0 ? p.success : p.danger),
      fillOpacity: context.isDark ? 0.12 : 0.1,
      corner: pagoPendiente
          ? Icon(Icons.schedule_rounded, size: 11, color: p.warning)
          : ingresoEsperado
          ? Icon(Icons.savings_rounded, size: 11, color: p.gold)
          : null,
      markers: n == null
          ? null
          : Text(
              '${n >= 0 ? '+' : '-'}${copCompacto(n.abs())}',
              style: context.text.labelSmall?.copyWith(fontSize: 9.5, letterSpacing: 0, fontWeight: FontWeight.w700, color: n >= 0 ? p.success : p.danger),
            ),
    );
  }
}

class _LeyendaFin extends StatelessWidget {
  const _LeyendaFin();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget item(Widget i, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        i,
        const SizedBox(width: 4),
        Text(t, style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
      ],
    );
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.xs,
      alignment: WrapAlignment.center,
      children: [
        item(Text('+50K', style: context.text.labelSmall?.copyWith(color: p.success, fontSize: 10)), 'Balance del día'),
        item(Icon(Icons.schedule_rounded, size: 13, color: p.warning), 'Pago pendiente'),
        item(Icon(Icons.savings_rounded, size: 13, color: p.gold), 'Ingreso esperado'),
      ],
    );
  }
}

// ─────────────────────────── Pestañas ───────────────────────────

class _Tabs extends ConsumerStatefulWidget {
  const _Tabs();

  @override
  ConsumerState<_Tabs> createState() => _TabsState();
}

class _TabsState extends ConsumerState<_Tabs> {
  final _keys = {for (final t in FinTab.values) t: GlobalKey()};

  void _mostrar(FinTab t) {
    final ctx = _keys[t]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Motion.of(context, Motion.medium), curve: Motion.standard);
    }
  }

  static const _iconos = {
    FinTab.resumen: Icons.dashboard_rounded,
    FinTab.cuentas: Icons.account_balance_rounded,
    FinTab.metas: Icons.flag_rounded,
    FinTab.presupuesto: Icons.pie_chart_rounded,
    FinTab.planificador: Icons.event_repeat_rounded,
    FinTab.historial: Icons.receipt_long_rounded,
    FinTab.graficos: Icons.insights_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final actual = ref.watch(finTabProvider);
    ref.listen(finTabProvider, (_, t) => WidgetsBinding.instance.addPostFrameCallback((_) => _mostrar(t)));
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in FinTab.values)
              Padding(
                key: _keys[t],
                padding: const EdgeInsets.only(right: Gap.xs),
                child: Semantics(
                  selected: t == actual,
                  button: true,
                  child: Pressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(finTabProvider.notifier).set(t);
                    },
                    child: AnimatedContainer(
                      duration: Motion.of(context, Motion.medium),
                      curve: Motion.enter,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t == actual ? p.accent : p.surfaceHigh,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: t == actual ? p.accent : p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(_iconos[t], size: IconSizes.sm, color: t == actual ? p.onAccent : p.textSecondary),
                          const SizedBox(width: 6),
                          Text(t.label, style: context.text.labelLarge?.copyWith(color: t == actual ? p.onAccent : p.text, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Acceso a "Pagos por clasificar" con el número de pendientes.
class _BotonPagos extends ConsumerWidget {
  const _BotonPagos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pagosPendientesProvider).value?.length ?? 0;
    return IconButton(
      tooltip: n == 0 ? 'Pagos automáticos' : '$n pagos por clasificar',
      onPressed: () => context.push(rutaPagos),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        child: const Icon(Icons.contactless_rounded),
      ),
    );
  }
}
