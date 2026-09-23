import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/holidays.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../cycle/cycle_engine.dart';
import '../cycle/cycle_repository.dart';
import '../cycle/widgets/cycle_ring.dart';
import '../cycle/widgets/cycle_sheets.dart';
import '../events/event_categories.dart';
import '../events/events_repository.dart';
import '../events/widgets/event_form_sheet.dart';
import '../events/widgets/event_tiles.dart';
import '../finance/finance_logic.dart';
import '../finance/sheets/transaction_sheet.dart';
import '../notifications/notification_service.dart';
import '../notifications/reminder_planner.dart';
import '../../core/widgets/sheets.dart';

/// Pantalla de inicio: lo que importa hoy, de un vistazo.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value?.usuario;
    final hoy = hoyYmd();
    final ahora = DateTime.now();
    final sig = DateTime(ahora.year, ahora.month + 1);
    final mesAsync = ref.watch(monthProvider((ahora.year, ahora.month)));
    final mes = mesAsync.value;
    final mesSig = ref.watch(monthProvider((sig.year, sig.month))).value;
    final boot = ref.watch(bootstrapProvider).value ?? Bootstrap.vacio;
    final eventos = [...?mes?.eventos, ...?mesSig?.eventos];
    final cargando = mes == null && mesAsync.isLoading;

    final deHoy = eventos.where((e) => e.fecha == hoy).toList()
      ..sort((a, b) => (a.hora ?? '').compareTo(b.hora ?? ''));
    final cumplesHoy = boot.cumples.where((c) => c.fecha.length >= 10 && c.fecha.substring(5) == hoy.substring(5)).toList();
    final festivo = festivoEn(hoy);
    final proximo = _proximoEvento(eventos, ahora);
    final fin7 = sumarDiasYmd(hoy, 7);
    final pagos = eventos
        .where((e) => e.tipoTransaccion == 'gasto' && !e.pagado && e.fecha.compareTo(hoy) >= 0 && e.fecha.compareTo(fin7) < 0)
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    var i = 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(sincronizadorProvider).refrescarTodo(),
          child: LayoutBuilder(builder: (context, c) {
            final side = c.maxWidth < 600 ? Gap.md : Gap.xl;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(side, Gap.xs, side, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Cabecera(usuario: usuario),
                        const _AvisoPermiso(),
                        Entrance(index: i++, child: _Proximo(evento: proximo, cargando: cargando)),
                        const VGap.lg(),
                        Entrance(
                          index: i++,
                          child: _Hoy(eventos: deHoy, cumples: cumplesHoy, festivo: festivo, cargando: cargando),
                        ),
                        if (pagos.isNotEmpty) ...[
                          const VGap.lg(),
                          Entrance(index: i++, child: _Pagos(pagos: pagos)),
                        ],
                        const VGap.lg(),
                        Entrance(
                          index: i++,
                          child: LayoutBuilder(builder: (context, c) {
                            final fin = _FinanzasMini(cuentas: boot.cuentas, tx: mes?.transacciones ?? const []);
                            final ciclo = boot.ciclos.isEmpty ? null : const _CicloMini();
                            if (ciclo == null) return fin;
                            if (c.maxWidth < 560) return Column(children: [fin, const VGap.sm(), ciclo]);
                            return IntrinsicHeight(
                              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Expanded(child: fin),
                                const HGap.sm(),
                                Expanded(child: ciclo),
                              ]),
                            );
                          }),
                        ),
                        const VGap.lg(),
                        Entrance(index: i++, child: const _Acciones()),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Siguiente evento con hora a partir de ahora (hoy o después).
Evento? _proximoEvento(List<Evento> eventos, DateTime ahora) {
  Evento? mejor;
  DateTime? cuando;
  for (final e in eventos) {
    if (e.hora == null) continue;
    final t = instanteBogota(e.fecha, e.hora);
    if (t.isBefore(ahora.subtract(const Duration(minutes: 5)))) continue;
    if (cuando == null || t.isBefore(cuando)) {
      mejor = e;
      cuando = t;
    }
  }
  return mejor;
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.usuario});
  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, 0, Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fechaConDia(hoyYmd()).toUpperCase(), style: context.text.labelSmall?.copyWith(color: p.accent, letterSpacing: 1)),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text(saludo(usuario?.primerNombre ?? ''), style: context.text.headlineMedium)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Perfil y ajustes',
            child: Pressable(
              onTap: () => context.go('/perfil'),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [p.accent, p.accent2]),
                ),
                child: Text(usuario?.iniciales ?? '', style: context.text.titleMedium?.copyWith(color: p.onAccent, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invitación a activar las notificaciones (con explicación antes del
/// diálogo del sistema, como recomiendan las guías de iOS y Android).
class _AvisoPermiso extends ConsumerWidget {
  const _AvisoPermiso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final permiso = ref.watch(permisoAvisosProvider).value;
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
    if (permiso != PermisoAvisos.denegado || !prefs.notificaciones) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: AppCard(
        color: Color.alphaBlend(p.accent.withValues(alpha: 0.1), p.surface),
        borderColor: p.accent.withValues(alpha: 0.4),
        child: Row(
          children: [
            IconBadge(Icons.notifications_active_rounded, color: p.accent, size: 44),
            const HGap.sm(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activa los avisos en este teléfono', style: context.text.titleSmall),
                Text('Además del WhatsApp, te avisaremos aquí 30 min antes y a la hora de cada evento.', style: context.text.bodySmall),
              ]),
            ),
            const HGap.xs(),
            FilledButton(
              onPressed: () async {
                final r = await ref.read(permisoAvisosProvider.notifier).pedir();
                if (context.mounted && r == PermisoAvisos.denegado) {
                  toast(context, 'Actívalas desde los ajustes del teléfono cuando quieras.', icon: Icons.info_outline_rounded);
                }
              },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: Gap.md)),
              child: const Text('Activar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Próximo evento ───────────────────────────

class _Proximo extends StatelessWidget {
  const _Proximo({required this.evento, required this.cargando});
  final Evento? evento;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = evento;
    if (e == null) {
      return AppCard(
        padding: const EdgeInsets.all(Gap.lg),
        gradient: LinearGradient(colors: [Color.alphaBlend(p.accent.withValues(alpha: 0.16), p.surface), p.surface]),
        child: Row(children: [
          IconBadge(cargando ? Icons.hourglass_top_rounded : Icons.wb_sunny_rounded, color: p.accent, size: 52),
          const HGap.md(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cargando ? 'Cargando tu agenda…' : 'Sin compromisos próximos', style: context.text.titleMedium),
              Text(cargando ? 'Un momento.' : 'Crea un evento y te avisaremos por WhatsApp y aquí.', style: context.text.bodySmall),
            ]),
          ),
        ]),
      );
    }
    final cat = categoriaEvento(e.categoria);
    return AppCard(
      padding: const EdgeInsets.all(Gap.lg),
      onTap: () => showAppSheet(context, (_) => EventDetailSheet(evento: e, parentContext: context)),
      semanticLabel: 'Próximo: ${e.titulo}',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.alphaBlend(cat.color.withValues(alpha: context.isDark ? 0.28 : 0.18), p.surface), p.surface],
      ),
      borderColor: cat.color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Tag('PRÓXIMO', color: cat.color, icon: Icons.bolt_rounded),
            const Spacer(),
            _CuentaRegresiva(cuando: instanteBogota(e.fecha, e.hora)),
          ]),
          const VGap.md(),
          Row(children: [
            IconBadge(cat.icon, color: cat.color, size: 52),
            const HGap.md(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.titulo, style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [fechaRelativa(e.fecha), hora12(e.hora), if (e.ubicacion.isNotEmpty) e.ubicacion].join(' · '),
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ]),
        ],
      ),
    );
  }
}

/// "en 2 h 15 min", actualizado cada 30 s.
class _CuentaRegresiva extends StatefulWidget {
  const _CuentaRegresiva({required this.cuando});
  final DateTime cuando;

  @override
  State<_CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<_CuentaRegresiva> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  String _texto() {
    final d = widget.cuando.difference(DateTime.now());
    if (d.inMinutes <= 0) return 'Ahora';
    if (d.inMinutes < 60) return 'en ${d.inMinutes} min';
    if (d.inHours < 24) return 'en ${d.inHours} h ${d.inMinutes % 60} min';
    return 'en ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: SmoothSwitcher(
        child: Text(_texto(), key: ValueKey(_texto()), style: context.text.titleSmall?.copyWith(color: p.accent, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ─────────────────────────── Hoy ───────────────────────────

class _Hoy extends StatelessWidget {
  const _Hoy({required this.eventos, required this.cumples, required this.festivo, required this.cargando});
  final List<Evento> eventos;
  final List<Cumple> cumples;
  final Festivo? festivo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final vacio = eventos.isEmpty && cumples.isEmpty && festivo == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Hoy',
          icon: Icons.today_rounded,
          subtitle: vacio ? null : '${eventos.length} evento(s)${cumples.isNotEmpty ? ' · ${cumples.length} cumpleaños' : ''}',
          action: TextButton(onPressed: () => context.go('/eventos'), child: const Text('Calendario')),
        ),
        if (festivo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: AppCard(
              color: Color.alphaBlend(p.warning.withValues(alpha: 0.1), p.surface),
              borderColor: p.warning.withValues(alpha: 0.4),
              child: Row(children: [
                IconBadge(Icons.celebration_rounded, color: p.warning, size: 40),
                const HGap.sm(),
                Expanded(child: Text('Festivo: ${festivo!.nombre}', style: context.text.titleSmall)),
              ]),
            ),
          ),
        if (vacio && !cargando)
          AppCard(
            child: EmptyState(
              icon: Icons.self_improvement_rounded,
              title: 'Día libre',
              message: 'No tienes nada agendado para hoy.',
              actionLabel: 'Agendar algo',
              onAction: () => abrirFormularioEvento(context, fecha: hoyYmd()),
              compact: true,
            ),
          ),
        for (final e in eventos)
          Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: EventTile(evento: e)),
        for (final c in cumples)
          Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: BirthdayTile(cumple: c, anio: DateTime.now().year)),
      ],
    );
  }
}

// ─────────────────────────── Pagos de la semana ───────────────────────────

class _Pagos extends ConsumerWidget {
  const _Pagos({required this.pagos});
  final List<Evento> pagos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final total = pagos.fold(0.0, (s, e) => s + e.costo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Pagos de los próximos 7 días', icon: Icons.payments_rounded, subtitle: '${pagos.length} pendiente(s) · ${cop(total)}'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            children: [
              for (final (k, e) in pagos.indexed) ...[
                if (k > 0) Divider(indent: Gap.md, endIndent: Gap.md, color: p.border),
                ListTile(
                  leading: IconBadge(categoriaEvento(e.categoria).icon, color: categoriaEvento(e.categoria).color, size: 38),
                  title: Text(e.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${fechaRelativa(e.fecha)} · ${fechaCorta(e.fecha)}', style: context.text.bodySmall),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cop(e.costo), style: context.text.titleSmall?.copyWith(color: p.danger)),
                    IconButton(
                      tooltip: 'Marcar como pagado',
                      icon: Icon(Icons.check_circle_outline_rounded, color: p.success),
                      onPressed: () async {
                        final toaster = Toaster.of(context);
                        try {
                          await ref.read(eventsRepoProvider).alternarPago(e);
                          toaster.show('Marcado como pagado', icon: Icons.check_circle_rounded);
                        } catch (err) {
                          toaster.show('$err', error: true);
                        }
                      },
                    ),
                  ]),
                  onTap: () => showAppSheet(context, (_) => EventDetailSheet(evento: e, parentContext: context)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Finanzas y ciclo ───────────────────────────

class _FinanzasMini extends StatelessWidget {
  const _FinanzasMini({required this.cuentas, required this.tx});
  final List<Cuenta> cuentas;
  final List<Transaccion> tx;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = ResumenFinanciero(cuentas: cuentas, txMes: tx);
    final usoGastos = r.ingresosMes > 0 ? r.gastosMes / r.ingresosMes : (r.gastosMes > 0 ? 1.0 : 0.0);
    return AppCard(
      onTap: () => context.go('/finanzas'),
      semanticLabel: 'Finanzas del mes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: p.info, size: IconSizes.md),
            const HGap.xs(),
            Expanded(child: Text('Finanzas de ${mesesLargos[DateTime.now().month - 1].toLowerCase()}', style: context.text.titleSmall)),
            Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          ]),
          const VGap.sm(),
          Text('Patrimonio', style: context.text.bodySmall),
          AnimatedMoney(r.patrimonio, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const VGap.sm(),
          Row(children: [
            Expanded(child: _Dato('Ingresos', r.ingresosMes, p.success)),
            Expanded(child: _Dato('Gastos', r.gastosMes, p.danger)),
          ]),
          const VGap.xs(),
          ProgressBar(value: usoGastos, color: usoGastos > 1 ? p.danger : (usoGastos > 0.8 ? p.warning : p.success), height: 6),
          const SizedBox(height: 4),
          Text(
            r.ingresosMes > 0 ? 'Has gastado el ${(usoGastos * 100).toStringAsFixed(0)}% de lo que ingresó' : 'Registra tus ingresos para ver tu balance',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.label, this.valor, this.color);
  final String label;
  final double valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.text.labelSmall),
        AnimatedMoney(valor, style: context.text.titleSmall?.copyWith(color: color)),
      ]);
}

class _CicloMini extends ConsumerWidget {
  const _CicloMini();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = getCycleDetails(hoyYmd(), ref.watch(cycleStatsProvider));
    final color = d == null ? p.textSecondary : colorFase(d.fase);
    return AppCard(
      onTap: () => context.go('/ciclo'),
      semanticLabel: 'Tu ciclo hoy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.water_drop_rounded, color: PhaseColors.period, size: IconSizes.md),
            const HGap.xs(),
            Expanded(child: Text('Tu ciclo hoy', style: context.text.titleSmall)),
            Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          ]),
          const VGap.sm(),
          if (d == null)
            Text('Registra tu periodo para ver predicciones.', style: context.text.bodySmall)
          else ...[
            Row(children: [
              IconBadge(iconoFase(d.fase), color: color, size: 44),
              const HGap.sm(),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.fase.nombre, style: context.text.titleMedium?.copyWith(color: color)),
                  Text('Día ${d.diaDelCiclo} de ${d.duracionCiclo}', style: context.text.bodySmall),
                ]),
              ),
            ]),
            const VGap.sm(),
            ProgressBar(value: d.progreso, color: color, height: 6),
            const SizedBox(height: 4),
            Text(
              d.fase == Fase.periodoRetrasado ? '${d.diasRetraso} día(s) de retraso' : 'Próximo periodo en ${d.proximoPeriodoEn} días',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Acciones extends ConsumerWidget {
  const _Acciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    Widget accion(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.xs),
            onTap: onTap,
            semanticLabel: label,
            child: Column(children: [
              IconBadge(icon, color: color, size: 44),
              const VGap.xs(),
              Text(label, textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(color: p.text), maxLines: 2),
            ]),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Acciones rápidas', icon: Icons.bolt_rounded),
        Row(children: [
          accion(Icons.event_available_rounded, 'Nuevo evento', const Color(0xFF25D366), () => abrirFormularioEvento(context, fecha: hoyYmd())),
          const HGap.xs(),
          accion(Icons.receipt_long_rounded, 'Registrar gasto', const Color(0xFF60A5FA), () => abrirTransaccion(context, fecha: hoyYmd())),
          const HGap.xs(),
          accion(Icons.water_drop_rounded, 'Registrar periodo', PhaseColors.period, () => abrirPeriodo(context, ref, hoyYmd())),
        ]),
      ],
    );
  }
}
