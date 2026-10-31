import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/holidays.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/boton_perfil.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/vista_async.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../captura/captura_sheet.dart';
import '../citas/citas_models.dart';
import '../citas/citas_repository.dart';
import '../cycle/cycle_engine.dart';
import '../cycle/cycle_repository.dart';
import '../cycle/widgets/cycle_ring.dart';
import '../cycle/widgets/cycle_sheets.dart';
import '../events/event_categories.dart';
import '../events/widgets/event_form_sheet.dart';
import '../events/widgets/event_tiles.dart';
import '../events/widgets/pago_evento_sheet.dart';
import '../finance/finance_logic.dart';
import '../finance/inversiones/inversiones_repository.dart';
import '../finance/prestamos/prestamos_repository.dart';
import '../finance/pagos/pagos_repository.dart';
import '../finance/sheets/transaction_sheet.dart';
import '../notifications/notification_service.dart';
import '../notifications/reminder_planner.dart';
import '../../core/widgets/sheets.dart';

/// Pantalla de inicio: lo que importa hoy, de un vistazo. Solo muestra lo de
/// los módulos que la persona usa.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value?.usuario;
    final activos = ref.watch(modulosActivosProvider);
    final conAgenda = activos.contains(AppModule.eventos);
    final conFinanzas = activos.contains(AppModule.finanzas);
    final conCiclo = activos.contains(AppModule.ciclo);
    final conCitas = activos.contains(AppModule.citas);

    final hoy = hoyYmd();
    final ahora = DateTime.now();
    final sig = DateTime(ahora.year, ahora.month + 1);
    final mesAsync = ref.watch(monthProvider((ahora.year, ahora.month)));
    final mes = mesAsync.value;
    final mesSig = ref.watch(monthProvider((sig.year, sig.month))).value;
    final boot = ref.watch(bootstrapProvider).value ?? Bootstrap.vacio;
    final eventos = [...?mes?.eventos, ...?mesSig?.eventos];
    final cargando = mes == null && mesAsync.isLoading;
    final fallo = mes == null && !mesAsync.isLoading && mesAsync.hasError;

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

    final celdas = [
      if (conFinanzas) CeldaBento(_FinanzasMini(cuentas: boot.cuentas, tx: mes?.transacciones ?? const [], inversiones: ref.watch(valorInversionesProvider) + ref.watch(porCobrarProvider)), ancha: !conCiclo),
      if (conCiclo) CeldaBento(const _CicloMini(), ancha: !conFinanzas),
    ];

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
                        const _BarraCaptura(),
                        const VGap.sm(),
                        Entrance(index: i++, child: _Acciones(conAgenda: conAgenda, conFinanzas: conFinanzas, conCiclo: conCiclo, conCitas: conCitas)),
                        const VGap.md(),
                        if (fallo) ...[
                          EstadoError(error: mesAsync.error, onReintentar: () => ref.read(sincronizadorProvider).refrescarTodo()),
                          const VGap.lg(),
                        ] else if (conAgenda) ...[
                          Entrance(index: i++, child: cargando ? const EsqueletoTarjeta(alto: 148) : _Proximo(evento: proximo)),
                          const VGap.lg(),
                        ],
                        if (conFinanzas) ...[
                          const _PagosPorClasificar(),
                        ],
                        if (conCitas) const _CitasHoy(),
                        if (conAgenda && !fallo) ...[
                          Entrance(
                            index: i++,
                            child: cargando
                                ? const EsqueletoLista(alturas: [72, 72])
                                : _Hoy(eventos: deHoy, cumples: cumplesHoy, festivo: festivo),
                          ),
                          const VGap.lg(),
                        ],
                        if ((conAgenda || conFinanzas) && pagos.isNotEmpty) ...[
                          Entrance(index: i++, child: _Pagos(pagos: pagos)),
                          const VGap.lg(),
                        ],
                        if (celdas.isNotEmpty) Entrance(index: i++, child: BentoGrid(celdas: celdas)),
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

class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.usuario});
  final Usuario? usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xxs, Gap.xs, 0, Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fechaConDia(hoyYmd()), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text(saludo(usuario?.primerNombre ?? ''), style: context.text.headlineMedium)),
                const SizedBox(height: Gap.xxs),
                const EstadoSincronizacion(),
              ],
            ),
          ),
          const HGap.xs(),
          const BotonPerfil(size: 48),
        ],
      ),
    );
  }
}

/// Punto que dice si lo que se ve está al día con el servidor.
class EstadoSincronizacion extends ConsumerWidget {
  const EstadoSincronizacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final offline = ref.watch(redProvider) == EstadoRed.sinConexion;
    final ultima = ref.watch(ultimaSincronizacionProvider);
    final (color, texto) = offline
        ? (p.warning, 'Sin conexión')
        : ultima == null
            ? (p.textSecondary, 'Sincronizando…')
            : (p.success, 'Al día');
    return Semantics(
      liveRegion: true,
      label: texto,
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall)),
      ]),
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
  const _Proximo({required this.evento});
  final Evento? evento;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = evento;
    final sobreColor = p.onAccent;
    final textoSuave = sobreColor.withValues(alpha: 0.86);
    Widget insignia(IconData icono) => Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: sobreColor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.md)),
          child: Icon(icono, color: sobreColor),
        );
    if (e == null) {
      return TarjetaHeroe(
        child: Row(children: [
          insignia(Icons.wb_sunny_rounded),
          const HGap.md(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sin compromisos próximos', style: context.text.titleMedium?.copyWith(color: sobreColor)),
              Text('Crea un evento y te avisaremos por WhatsApp y aquí.', style: context.text.bodySmall?.copyWith(color: textoSuave)),
            ]),
          ),
        ]),
      );
    }
    final cat = categoriaEvento(e.categoria);
    return TarjetaHeroe(
      onTap: () => showAppSheet(context, (_) => EventDetailSheet(evento: e, parentContext: context)),
      semanticLabel: 'Próximo: ${e.titulo}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Próximo', style: context.text.labelLarge?.copyWith(color: textoSuave)),
            const HGap.sm(),
            // Con texto grande y cuentas largas ("en 23 h 59 min") se reduce
            // en vez de desbordar la fila.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: _CuentaRegresiva(cuando: instanteBogota(e.fecha, e.hora), color: sobreColor)),
              ),
            ),
          ]),
          const VGap.md(),
          Row(children: [
            insignia(cat.icon),
            const HGap.md(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.titulo, style: context.text.titleLarge?.copyWith(color: sobreColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [fechaRelativa(e.fecha), hora12(e.hora), if (e.ubicacion.isNotEmpty) e.ubicacion].join(' · '),
                  style: context.text.bodySmall?.copyWith(color: textoSuave),
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
  const _CuentaRegresiva({required this.cuando, required this.color});
  final DateTime cuando;
  final Color color;

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
    return Semantics(
      liveRegion: true,
      child: SmoothSwitcher(
        child: Text(_texto(), key: ValueKey(_texto()), style: context.text.titleSmall?.copyWith(color: widget.color, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ─────────────────────────── Hoy ───────────────────────────

class _Hoy extends StatelessWidget {
  const _Hoy({required this.eventos, required this.cumples, required this.festivo});
  final List<Evento> eventos;
  final List<Cumple> cumples;
  final Festivo? festivo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final vacio = eventos.isEmpty && cumples.isEmpty && festivo == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Hoy',
          subtitle: vacio ? null : '${_cuenta(eventos.length, 'evento', 'eventos')}${cumples.isNotEmpty ? ' · ${_cuenta(cumples.length, 'cumpleaños', 'cumpleaños')}' : ''}',
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
        if (vacio)
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
        SectionHeader('Pagos de la semana', subtitle: '${_cuenta(pagos.length, 'pendiente', 'pendientes')} · ${cop(total)}'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            children: [
              for (final (k, e) in pagos.indexed) ...[
                if (k > 0) Divider(indent: Gap.md, endIndent: Gap.md, color: p.border),
                ListTile(
                  leading: IconBadge(categoriaEvento(e.categoria).icon, color: categoriaEvento(e.categoria).colorDe(context), size: 38),
                  title: Text(e.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${fechaRelativa(e.fecha)} · ${fechaCorta(e.fecha)}', style: context.text.bodySmall),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cop(e.costo), style: context.text.titleSmall?.copyWith(color: p.danger)),
                    IconButton(
                      tooltip: 'Marcar como pagado',
                      icon: Icon(Icons.check_circle_outline_rounded, color: p.success),
                      onPressed: () => gestionarPagoEvento(context, e),
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
  const _FinanzasMini({required this.cuentas, required this.tx, required this.inversiones});
  final List<Cuenta> cuentas;
  final List<Transaccion> tx;
  final double inversiones;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = ResumenFinanciero(cuentas: cuentas, txMes: tx, inversiones: inversiones);
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
    final color = d == null ? p.textSecondary : context.legible(colorFase(d.fase));
    return AppCard(
      onTap: () => context.go('/ciclo'),
      semanticLabel: 'Tu ciclo hoy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.water_drop_rounded, color: context.legible(PhaseColors.period), size: IconSizes.md),
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

String _cuenta(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// Entrada a la captura rápida: parece un campo de texto, con micrófono.
class _BarraCaptura extends StatelessWidget {
  const _BarraCaptura();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.bordeTarjeta),
        boxShadow: p.sombraSuave,
      ),
      child: Row(children: [
        Expanded(
          child: Pressable(
            onTap: () => abrirCaptura(context),
            semanticLabel: 'Registrar algo rápido escribiéndolo',
            scale: 0.99,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.xs, Gap.md),
              child: Row(children: [
                Icon(Icons.bolt_rounded, color: p.accent, size: IconSizes.md),
                const HGap.sm(),
                Expanded(
                  child: Text('Escribe o di lo que quieras registrar…', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
                ),
              ]),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Dictar',
          onPressed: () => abrirCaptura(context, escuchar: true),
          icon: Icon(Icons.mic_rounded, color: p.accent),
        ),
        const SizedBox(width: Gap.xxs),
      ]),
    );
  }
}

/// Lo que más se registra, siempre a un toque.
class _Acciones extends ConsumerWidget {
  const _Acciones({required this.conAgenda, required this.conFinanzas, required this.conCiclo, required this.conCitas});
  final bool conAgenda;
  final bool conFinanzas;
  final bool conCiclo;
  final bool conCitas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final b = Theme.of(context).brightness;
    Widget accion(IconData icon, String label, Color color, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: Gap.xs),
          child: Pressable(
            onTap: onTap,
            semanticLabel: label,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: p.bordeTarjeta),
                boxShadow: p.sombraSuave,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: IconSizes.md),
                const HGap.xs(),
                Text(label, style: context.text.labelLarge),
              ]),
            ),
          ),
        );
    final acciones = [
      if (conAgenda) accion(AppModule.eventos.iconSelected, 'Nuevo evento', AppModule.eventos.accent(b), () => abrirFormularioEvento(context, fecha: hoyYmd())),
      if (conFinanzas) accion(Icons.receipt_long_rounded, 'Registrar gasto', AppModule.finanzas.accent(b), () => abrirTransaccion(context, fecha: hoyYmd())),
      if (conCitas) accion(AppModule.citas.iconSelected, 'Nueva cita', AppModule.citas.accent(b), () => context.go('/citas')),
      if (conCiclo) accion(AppModule.ciclo.iconSelected, 'Registrar periodo', AppModule.ciclo.accent(b), () => abrirPeriodo(context, ref, hoyYmd())),
    ];
    if (acciones.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: Gap.xxs),
        children: acciones,
      ),
    );
  }
}

/// Pagos leídos del banco o de Apple Pay que esperan su categoría.
class _PagosPorClasificar extends ConsumerWidget {
  const _PagosPorClasificar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final pagos = ref.watch(pagosPendientesProvider).value ?? const [];
    if (pagos.isEmpty) return const SizedBox.shrink();
    final total = pagos.fold(0.0, (s, c) => s + c.monto);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: AppCard(
        onTap: () => context.push(rutaPagos),
        semanticLabel: 'Pagos por clasificar: ${pagos.length}',
        child: Row(children: [
          IconBadge(Icons.bolt_rounded, color: p.warning, size: 44),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pagos.length == 1 ? '1 pago por clasificar' : '${pagos.length} pagos por clasificar', style: context.text.titleSmall),
              Text('${cop(total)} · ponles categoría en un toque', style: context.text.bodySmall),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary),
        ]),
      ),
    );
  }
}

/// Citas de hoy del negocio (solo si ya tiene su página).
class _CitasHoy extends ConsumerWidget {
  const _CitasHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final negocio = ref.watch(configAgendaProvider).value?.negocio;
    if (negocio == null) return const SizedBox.shrink();
    final citas = (ref.watch(citasPorDiaProvider)[hoyYmd()] ?? const <CitaAgenda>[])
        .where((c) => c.estado == EstadoCita.confirmada || c.estado == EstadoCita.pendiente)
        .toList();
    final acento = AppModule.citas.accent(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(
          'Citas de hoy',
          subtitle: citas.isEmpty ? null : _cuenta(citas.length, 'cita', 'citas'),
          action: TextButton(onPressed: () => context.go('/citas'), child: const Text('Ver agenda')),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: citas.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
                  child: Row(children: [
                    IconBadge(AppModule.citas.iconSelected, color: acento, size: 40),
                    const HGap.sm(),
                    Expanded(child: Text('Sin citas hoy. Comparte tu enlace para recibir reservas.', style: context.text.bodySmall)),
                  ]),
                )
              : Column(children: [
                  for (final (k, c) in citas.take(3).indexed) ...[
                    if (k > 0) Divider(indent: Gap.md, endIndent: Gap.md, color: p.border),
                    ListTile(
                      onTap: () => context.go('/citas'),
                      leading: SizedBox(
                        width: 76,
                        child: Text(hora12(c.horaInicio), maxLines: 1, softWrap: false, style: context.text.labelLarge?.copyWith(color: acento, fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                      title: Text(c.clienteNombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                      subtitle: Text(c.servicioNombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }
}
