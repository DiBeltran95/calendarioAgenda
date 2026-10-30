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
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/vista_async.dart';
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

/// Secciones de Finanzas. "Planear" agrupa metas, presupuesto y planificador.
const _secciones = <(FinTab, String, IconData)>[
  (FinTab.resumen, 'Resumen', Icons.dashboard_rounded),
  (FinTab.historial, 'Historial', Icons.receipt_long_rounded),
  (FinTab.cuentas, 'Cuentas', Icons.account_balance_rounded),
  (FinTab.metas, 'Planear', Icons.flag_rounded),
  (FinTab.graficos, 'Gráficos', Icons.insights_rounded),
];

const _subPlanear = {FinTab.metas, FinTab.presupuesto, FinTab.planificador};

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesFinanzasProvider);
    final sel = ref.watch(diaFinanzasProvider);
    final tab = ref.watch(finTabProvider);
    final cuentasAsync = ref.watch(cuentasProvider);
    final cuentas = cuentasAsync.value ?? const <Cuenta>[];
    final txMes = ref.watch(txMesProvider((mes.year, mes.month))).value ?? const <Transaccion>[];
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
    final calendario = ref.watch(finCalendarioProvider);
    void reintentar() => ref.read(sincronizadorProvider).refrescarTodo();

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
          onRefresh: () async => reintentar(),
          primary: [
            EncabezadoPantalla(
              contexto: 'Tu dinero',
              titulo: AppModule.finanzas.label,
              acciones: [
                const _BotonPagos(),
                if (cuentas.length >= 2)
                  IconButton(
                    tooltip: 'Transferir entre cuentas',
                    onPressed: () => showAppSheet(context, (_) => const TransferSheet()),
                    icon: const Icon(Icons.swap_horiz_rounded),
                  ),
              ],
            ),
            if (cuentasAsync.hasError && !cuentasAsync.hasValue)
              EstadoError(error: cuentasAsync.error, onReintentar: reintentar)
            else if (!cuentasAsync.hasValue)
              const EsqueletoTarjeta(alto: 190)
            else
              Entrance(child: _Patrimonio(cuentas: cuentas, txMes: txMes)),
            if (!prefs.onboardingFinanzasOculto && cuentasAsync.hasValue) ...[const VGap.sm(), const _Onboarding()],
          ],
          secondary: [
            const VGap.md(),
            const _Secciones(),
            if (_subPlanear.contains(tab)) ...[
              const VGap.sm(),
              SegmentedPill<FinTab>(
                value: tab,
                onChanged: (t) => ref.read(finTabProvider.notifier).set(t),
                options: const [
                  (FinTab.metas, 'Metas', null),
                  (FinTab.presupuesto, 'Presupuesto', null),
                  (FinTab.planificador, 'Planificador', null),
                ],
              ),
            ],
            if (tab != FinTab.graficos && !(tab == FinTab.historial && calendario)) ...[
              const VGap.sm(),
              _SelectorMes(mes: mes),
            ],
            const VGap.sm(),
            SmoothSwitcher(
              child: KeyedSubtree(
                key: ValueKey('${tab.name}-${tab == FinTab.historial ? '' : mes.month}'),
                child: switch (tab) {
                  FinTab.resumen => SummaryTab(mes: mes, dia: null, txMes: txMes, cuentas: cuentas),
                  FinTab.cuentas => AccountsTab(cuentas: cuentas, mes: mes),
                  FinTab.metas => const GoalsTab(),
                  FinTab.presupuesto => BudgetTab(mes: mes, txMes: txMes),
                  FinTab.planificador => PlannerTab(mes: mes, dia: null),
                  FinTab.historial => _Movimientos(mes: mes, sel: sel, txMes: txMes),
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

/// ¿El historial se ve como calendario?
class FinCalendario extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final finCalendarioProvider = NotifierProvider<FinCalendario, bool>(FinCalendario.new);

/// Mes que se está viendo, con flechas para cambiarlo.
class _SelectorMes extends ConsumerWidget {
  const _SelectorMes({required this.mes});
  final DateTime mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(mesFinanzasProvider.notifier);
    return Row(children: [
      IconButton(tooltip: 'Mes anterior', onPressed: () => n.mover(-1), icon: const Icon(Icons.chevron_left_rounded)),
      Expanded(
        child: Text('${mesesLargos[mes.month - 1]} ${mes.year}', textAlign: TextAlign.center, style: context.text.titleSmall),
      ),
      IconButton(tooltip: 'Mes siguiente', onPressed: () => n.mover(1), icon: const Icon(Icons.chevron_right_rounded)),
    ]);
  }
}

/// Historial del mes, como lista o sobre el calendario.
class _Movimientos extends ConsumerWidget {
  const _Movimientos({required this.mes, required this.sel, required this.txMes});
  final DateTime mes;
  final String? sel;
  final List<Transaccion> txMes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendario = ref.watch(finCalendarioProvider);
    final eventos = ref.watch(eventosMesProvider((mes.year, mes.month))).value ?? const <Evento>[];
    final ocurrencias = ref.watch(ocurrenciasMesProvider((mes.year, mes.month)));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedPill<bool>(
          value: calendario,
          onChanged: (v) {
            if (!v) ref.read(diaFinanzasProvider.notifier).seleccionar(null);
            ref.read(finCalendarioProvider.notifier).set(v);
          },
          options: const [
            (false, 'Lista', Icons.view_list_rounded),
            (true, 'Calendario', Icons.calendar_month_rounded),
          ],
        ),
        const VGap.sm(),
        if (calendario) ...[
          AppCard(
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
          const VGap.md(),
        ],
        SmoothSwitcher(
          child: KeyedSubtree(
            key: ValueKey('${mes.month}-${sel ?? ''}'),
            child: HistoryTab(mes: mes, dia: calendario ? sel : null, txMes: txMes),
          ),
        ),
      ],
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
    final suave = p.onAccent.withValues(alpha: 0.86);
    return TarjetaHeroe(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Patrimonio neto', style: context.text.labelLarge?.copyWith(color: suave)),
          const SizedBox(height: 4),
          AnimatedMoney(r.patrimonio, style: context.text.displaySmall?.copyWith(color: p.onAccent)),
          const VGap.md(),
          Row(
            children: [
              Expanded(child: _Mini(icon: Icons.savings_rounded, label: 'Ahorros e inversiones', valor: r.ahorros)),
              Container(width: 1, height: 36, color: p.onAccent.withValues(alpha: 0.3)),
              const HGap.md(),
              Expanded(child: _Mini(icon: Icons.credit_card_rounded, label: 'Deuda tarjetas', valor: r.deudaTarjetas)),
            ],
          ),
          if (r.cupoTarjetas > 0) ...[
            const VGap.sm(),
            ProgressBar(value: r.usoCredito / 100, color: p.onAccent, background: p.onAccent.withValues(alpha: 0.25), height: 6),
            const SizedBox(height: 4),
            Text('Uso de cupo: ${r.usoCredito.toStringAsFixed(0)}% de ${cop(r.cupoTarjetas)}', style: context.text.bodySmall?.copyWith(color: suave)),
          ],
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.label, required this.valor});
  final IconData icon;
  final String label;
  final double valor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: IconSizes.md, color: p.onAccent),
        const HGap.xs(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelSmall?.copyWith(letterSpacing: 0, color: p.onAccent.withValues(alpha: 0.86)), maxLines: 1, overflow: TextOverflow.ellipsis),
              AnimatedMoney(valor, style: context.text.titleSmall?.copyWith(color: p.onAccent)),
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
          ? Dot(p.warning, size: 8)
          : ingresoEsperado
          ? Dot(p.info, size: 8)
          : null,
      markers: n == null
          ? null
          : Text(
              '${n >= 0 ? '+' : '-'}${copCompacto(n.abs())}',
              style: context.text.labelSmall?.copyWith(letterSpacing: 0, fontWeight: FontWeight.w700, color: n >= 0 ? p.success : p.danger),
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
        Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(letterSpacing: 0))),
      ],
    );
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.xs,
      alignment: WrapAlignment.center,
      children: [
        item(Text('+50K', style: context.text.labelSmall?.copyWith(color: p.success)), 'Balance del día'),
        item(Dot(p.warning, size: 8), 'Pago pendiente'),
        item(Dot(p.info, size: 8), 'Ingreso esperado'),
      ],
    );
  }
}

// ─────────────────────────── Secciones ───────────────────────────

/// Selector fijo de secciones: siempre se ven todas, sin desplazar.
class _Secciones extends ConsumerWidget {
  const _Secciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final actual = ref.watch(finTabProvider);
    final activa = _subPlanear.contains(actual) ? FinTab.metas : actual;
    return Container(
      padding: const EdgeInsets.all(Gap.xxs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.bordeTarjeta),
        boxShadow: p.sombraSuave,
      ),
      child: Row(children: [
        for (final (t, etiqueta, icono) in _secciones)
          Expanded(
            child: Semantics(
              button: true,
              selected: t == activa,
              label: etiqueta,
              excludeSemantics: true,
              child: Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(finTabProvider.notifier).set(t);
                },
                haptic: false,
                scale: 0.95,
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.standard,
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(vertical: Gap.xs, horizontal: 2),
                  decoration: BoxDecoration(
                    color: t == activa ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.lg - Gap.xxs),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icono, size: IconSizes.md, color: t == activa ? p.onAccent : p.textSecondary),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(etiqueta, maxLines: 1, style: context.text.labelSmall?.copyWith(letterSpacing: 0, color: t == activa ? p.onAccent : p.textSecondary)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
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
        child: const Icon(Icons.contactless_outlined),
      ),
    );
  }
}
