import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/fab_animado.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/vista_async.dart';
import 'citas_en_vivo.dart';
import 'citas_models.dart';
import 'citas_repository.dart';
import 'widgets/cita_sheets.dart';
import 'widgets/enlace_card.dart';

/// Día elegido en la tira de fechas del módulo.
class DiaCitas extends Notifier<String> {
  @override
  String build() => hoyYmd();
  void set(String f) => state = f;
}

final diaCitasProvider = NotifierProvider<DiaCitas, String>(DiaCitas.new);

/// Módulo "Citas": la página pública del usuario y su agenda de reservas.
class CitasScreen extends ConsumerWidget {
  const CitasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configAgendaProvider);
    final config = configAsync.value;
    final misReservas = ref.watch(misReservasProvider).value ?? const <CitaAgenda>[];
    final negocio = config?.negocio;
    final cargando = config == null && configAsync.isLoading;

    Future<void> refrescar() => ref.read(agendaRepoProvider).refrescar();

    // Al tocar un aviso en vivo: se abre esa cita en cuanto esté en la lista.
    final porAbrir = ref.watch(citaPorAbrirProvider);
    if (porAbrir != null) {
      final todas = [...?ref.watch(citasAgendaProvider).value, ...misReservas];
      final cita = todas.where((c) => c.id == porAbrir).firstOrNull;
      if (cita != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || ref.read(citaPorAbrirProvider) != porAbrir) return;
          ref.read(citaPorAbrirProvider.notifier).set(null);
          showAppSheet(context, (_) => CitaDetalleSheet(cita: cita));
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Siempre en el mismo lugar: crea la página o, si ya existe, una cita.
      floatingActionButton: cargando || configAsync.hasError && config == null
          ? null
          : negocio == null
              ? FabAnimado(heroTag: 'fab-citas', icono: Icons.rocket_launch_rounded, etiqueta: 'Crear página', onPressed: () => context.push('/citas/crear'))
              : FabAnimado(
                  heroTag: 'fab-citas',
                  icono: Icons.add_rounded,
                  etiqueta: 'Nueva cita',
                  onPressed: () => showAppSheet(context, (_) => NuevaCitaSheet(config: config!, fecha: ref.read(diaCitasProvider))),
                ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: refrescar,
          child: LayoutBuilder(builder: (context, c) {
            final lado = c.maxWidth < 600 ? Gap.md : Gap.xl;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(lado, Gap.xs, lado, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EncabezadoPantalla(
                          contexto: negocio?.nombre ?? 'Recibe reservas',
                          titulo: 'Citas',
                          acciones: [
                            if (negocio != null)
                              IconButton(
                                tooltip: 'Ajustes de citas',
                                onPressed: () => context.push('/citas/ajustes'),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                          ],
                        ),
                        if (configAsync.hasError && config == null)
                          EstadoError(error: configAsync.error, onReintentar: refrescar)
                        else if (cargando)
                          const EsqueletoLista(alturas: [150, 110, 78, 96])
                        else if (negocio == null)
                          const _Bienvenida()
                        else
                          _Agenda(config: config!),
                        if (misReservas.isNotEmpty) ...[
                          const VGap.xl(),
                          _MisReservas(reservas: misReservas),
                        ],
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

// ─────────────────────── Sin página: invitación ───────────────────────

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const ventajas = [
      (Icons.link_rounded, 'Tu propio enlace', 'Compártelo por WhatsApp, Instagram o con un código QR.'),
      (Icons.verified_rounded, 'Confirmación por WhatsApp', 'Cada cita se confirma con un código: menos inasistencias.'),
      (Icons.event_available_rounded, 'Sin choques de horario', 'Solo se ofrecen los espacios libres, también de tu calendario.'),
      (Icons.groups_rounded, 'Solo o con tu equipo', 'Psicólogos, peluquerías, spas, consultorios… cada quien con su horario.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          child: TarjetaHeroe(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Ilustracion(),
              const VGap.md(),
              Text('Que tus clientes agenden solos', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: p.onAccent)),
              const VGap.xs(),
              Text(
                'Crea tu página de citas en un minuto. Tus clientes eligen servicio, profesional y hora; tú solo recibes la notificación.',
                style: context.text.bodyMedium?.copyWith(color: p.onAccent.withValues(alpha: 0.88)),
              ),
              const VGap.lg(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/citas/crear'),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Crear mi página de citas'),
                  style: FilledButton.styleFrom(backgroundColor: p.onAccent, foregroundColor: p.accent),
                ),
              ),
            ]),
          ),
        ),
        const VGap.lg(),
        for (final (i, (icono, titulo, texto)) in ventajas.indexed)
          Entrance(
            index: i + 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconBadge(icono, size: 44),
                const HGap.md(),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo, style: context.text.titleSmall),
                    Text(texto, style: context.text.bodySmall),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Pequeña composición animada: un calendario con horas que se "reservan".
class _Ilustracion extends StatelessWidget {
  const _Ilustracion();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final horas = ['9:00', '10:30', '2:00', '4:30'];
    return Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
      for (final (i, h) in horas.indexed)
        ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
            decoration: BoxDecoration(
              color: i == 1 ? p.accent : p.surface,
              borderRadius: Radii.rMd,
              border: Border.all(color: p.accent.withValues(alpha: 0.4)),
            ),
            child: Text(h, style: context.text.labelLarge?.copyWith(color: i == 1 ? p.onAccent : p.accent, fontWeight: FontWeight.w700)),
          )
              .animate(delay: (120 * i).ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.4, curve: Motion.enter)
              .then(delay: i == 1 ? 400.ms : 0.ms)
              .shimmer(duration: i == 1 ? 1200.ms : 1.ms, color: p.onAccent.withValues(alpha: 0.5)),
        ),
    ]);
  }
}

// ─────────────────────── Agenda del negocio ───────────────────────

class _Agenda extends ConsumerWidget {
  const _Agenda({required this.config});
  final ConfigAgenda config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negocio = config.negocio!;
    final resumen = ref.watch(resumenCitasProvider);
    final porDia = ref.watch(citasPorDiaProvider);
    final dia = ref.watch(diaCitasProvider);
    final citasDia = porDia[dia] ?? const <CitaAgenda>[];
    final sinServicios = config.serviciosActivos.isEmpty;
    var i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(index: i++, child: _HeroCitas(resumen: resumen)),
        const VGap.sm(),
        Entrance(index: i++, child: TarjetaEnlace(negocio: negocio)),
        if (sinServicios) ...[
          const VGap.sm(),
          Entrance(
            index: i++,
            child: AppCard(
              onTap: () => context.push('/citas/ajustes'),
              borderColor: context.palette.warning.withValues(alpha: 0.5),
              child: Row(children: [
                IconBadge(Icons.warning_amber_rounded, color: context.palette.warning),
                const HGap.sm(),
                const Expanded(child: Text('Agrega al menos un servicio para que puedan agendar.')),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ],
        const VGap.lg(),
        Entrance(index: i++, child: _TiraDias(porDia: porDia)),
        const VGap.md(),
        Row(children: [
          Expanded(child: Text(dia == hoyYmd() ? 'Hoy · ${fechaConDia(dia)}' : fechaConDia(dia), style: context.text.titleMedium)),
          if (citasDia.isNotEmpty) Text(_cuentaCitas(citasDia.where((c) => c.estado != EstadoCita.cancelada).length), style: context.text.bodySmall),
        ]),
        const VGap.sm(),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          switchInCurve: Motion.enter,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child),
          ),
          child: citasDia.isEmpty
              ? EmptyState(
                  key: ValueKey('vacio$dia'),
                  icon: Icons.free_cancellation_rounded,
                  title: 'Día libre',
                  message: 'Comparte tu enlace para llenar tu agenda, o agenda una cita a mano.',
                  actionLabel: 'Compartir enlace',
                  onAction: () => compartirEnlace(context, negocio),
                  compact: true,
                )
              : Column(
                  key: ValueKey('dia$dia'),
                  children: [for (final (j, c) in citasDia.indexed) Entrance(index: j, child: _TarjetaCita(cita: c, conEquipo: config.profesionales.length > 1))],
                ),
        ),
      ],
    );
  }
}

String _cuentaCitas(int n) => '$n ${n == 1 ? 'cita' : 'citas'}';

/// El día del negocio de un vistazo: números y la próxima cita.
class _HeroCitas extends StatelessWidget {
  const _HeroCitas({required this.resumen});
  final ResumenCitas resumen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final suave = p.onAccent.withValues(alpha: 0.86);
    final proxima = resumen.proxima;
    Widget dato(String etiqueta, String valor) => Expanded(
          child: Semantics(
            label: '$etiqueta: $valor',
            excludeSemantics: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(etiqueta, style: context.text.labelMedium?.copyWith(color: suave)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: context.text.headlineSmall?.copyWith(color: p.onAccent, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ]),
          ),
        );
    return TarjetaHeroe(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          dato('Hoy', '${resumen.hoy}'),
          dato('Esta semana', '${resumen.semana}'),
          dato('Ingresos', copCompacto(resumen.ingresosSemana)),
        ]),
        if (proxima != null) ...[
          const VGap.md(),
          Pressable(
            onTap: () => showAppSheet(context, (_) => CitaDetalleSheet(cita: proxima)),
            semanticLabel: 'Próxima cita: ${proxima.clienteNombre}, ${fechaRelativa(proxima.fecha)} a las ${hora12(proxima.horaInicio)}',
            scale: 0.985,
            child: Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(color: p.onAccent.withValues(alpha: 0.14), borderRadius: Radii.rMd),
              child: Row(children: [
                Icon(Icons.schedule_rounded, color: p.onAccent, size: IconSizes.md),
                const HGap.xs(),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Próxima: ${fechaRelativa(proxima.fecha)}, ${hora12(proxima.horaInicio)}', style: context.text.labelMedium?.copyWith(color: suave)),
                    Text(proxima.clienteNombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(color: p.onAccent)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.onAccent),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Tira horizontal de 3 semanas con un punto por cada día con citas.
class _TiraDias extends ConsumerWidget {
  const _TiraDias({required this.porDia});
  final Map<String, List<CitaAgenda>> porDia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final hoy = hoyYmd();
    final sel = ref.watch(diaCitasProvider);
    final dias = [for (var d = -1; d < 21; d++) sumarDiasYmd(hoy, d)];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (_, _) => const HGap.xs(),
        controller: ScrollController(initialScrollOffset: 0),
        itemBuilder: (context, i) {
          final f = dias[i];
          final d = parseYmd(f);
          final activas = (porDia[f] ?? const []).where((c) => c.estado.activa || c.estado == EstadoCita.completada).length;
          final elegido = f == sel;
          return Semantics(
            button: true,
            selected: elegido,
            label: '${fechaConDia(f)}, $activas citas',
            excludeSemantics: true,
            child: Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(diaCitasProvider.notifier).set(f);
              },
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.standard,
                width: 56,
                decoration: BoxDecoration(
                  color: elegido ? p.accent : p.surface,
                  borderRadius: Radii.rMd,
                  border: Border.all(color: elegido ? p.accent : (f == hoy ? p.accent.withValues(alpha: 0.5) : p.border)),
                  boxShadow: elegido ? p.sombraMedia : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_dias[d.weekday % 7], style: context.text.labelSmall?.copyWith(color: elegido ? p.onAccent : p.textSecondary)),
                  Text('${d.day}', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: elegido ? p.onAccent : p.text)),
                  AnimatedOpacity(
                    duration: Motion.of(context, Motion.fast),
                    opacity: activas > 0 ? 1 : 0,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var k = 0; k < activas.clamp(0, 3); k++)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: elegido ? p.onAccent : p.accent),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

const _dias = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];

class _TarjetaCita extends ConsumerWidget {
  const _TarjetaCita({required this.cita, required this.conEquipo});
  final CitaAgenda cita;
  final bool conEquipo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final (colorEstado, iconoEstado) = estiloEstado(context, cita.estado);
    final apagada = cita.estado == EstadoCita.cancelada || cita.estado == EstadoCita.noAsistio;
    // Recién llegada en vivo: borde de acento y etiqueta "Nueva" por 2 minutos.
    final reciente = !apagada && ref.watch(citasRecientesProvider.select((s) => s.contains(cita.id)));
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 58,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const SizedBox(height: Gap.sm),
              Text(hora12(cita.horaInicio).split(' ').first, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
              Text(hora12(cita.horaInicio).split(' ').skip(1).join(' '), style: context.text.labelSmall),
            ]),
          ),
          const HGap.sm(),
          Expanded(
            child: AnimatedOpacity(
              duration: Motion.of(context, Motion.medium),
              opacity: apagada ? 0.55 : 1,
              child: AppCard(
                padding: EdgeInsets.zero,
                onTap: () => showAppSheet(context, (_) => CitaDetalleSheet(cita: cita)),
                borderColor: reciente ? p.success.withValues(alpha: 0.7) : null,
                semanticLabel: '${reciente ? 'Nueva. ' : ''}${hora12(cita.horaInicio)}, ${cita.clienteNombre}, ${cita.servicioNombre}, ${cita.estado.etiqueta}',
                child: ClipRRect(
                  borderRadius: Radii.rLg,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(width: 5, color: Color(cita.profesionalColor)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.sm),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            cita.clienteNombre,
                            style: context.text.titleSmall?.copyWith(decoration: apagada ? TextDecoration.lineThrough : null),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: Gap.xxs),
                          Wrap(spacing: Gap.xxs, runSpacing: Gap.xxs, children: [
                            if (reciente)
                              Tag('Nueva', color: p.success, icon: Icons.fiber_new_rounded)
                                  .animate()
                                  .fadeIn(duration: Motion.of(context, Motion.medium))
                                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: Motion.of(context, Motion.slow)),
                            Tag(cita.estado.etiqueta, color: colorEstado, icon: iconoEstado),
                          ]),
                          const SizedBox(height: Gap.xxs),
                          Text(
                            [cita.servicioNombre, if (conEquipo || cita.rol == 'equipo') cita.profesionalNombre, if (cita.precio > 0) cop(cita.precio)].join(' · '),
                            style: context.text.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (cita.rol == 'equipo')
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('En ${cita.negocioNombre}', style: context.text.labelSmall?.copyWith(color: p.accent)),
                            ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────── Mis reservas (como cliente) ───────────────────────

class _MisReservas extends StatelessWidget {
  const _MisReservas({required this.reservas});
  final List<CitaAgenda> reservas;

  @override
  Widget build(BuildContext context) {
    final hoy = hoyYmd();
    final proximas = reservas.where((r) => r.fecha.compareTo(hoy) >= 0 && r.estado.activa).toList()
      ..sort((a, b) => '${a.fecha}${a.horaInicio}'.compareTo('${b.fecha}${b.horaInicio}'));
    final anteriores = reservas.where((r) => !proximas.contains(r)).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Mis reservas', icon: Icons.bookmark_added_rounded, subtitle: 'Citas que agendaste en otros negocios'),
        for (final (i, r) in [...proximas, ...anteriores].indexed)
          Entrance(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: AppCard(
                onTap: () => showAppSheet(context, (_) => CitaDetalleSheet(cita: r)),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Color(r.negocioColor), shape: BoxShape.circle),
                    child: Text(iniciales(r.negocioNombre), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const HGap.sm(),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.negocioNombre, style: context.text.titleSmall),
                      Text('${r.servicioNombre} · ${fechaRelativa(r.fecha)} ${hora12(r.horaInicio)}', style: context.text.bodySmall),
                    ]),
                  ),
                  Tag(r.estado.etiqueta, color: estiloEstado(context, r.estado).$1),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

