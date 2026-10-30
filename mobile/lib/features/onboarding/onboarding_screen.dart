import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/widgets/ui.dart';
import '../auth/auth_widgets.dart' show AuroraBackground;
import '../notifications/notification_service.dart';

/// Lo que se le ofrece a quien recién crea su cuenta: cada opción habla de lo
/// que la persona quiere hacer, no del nombre de la pestaña.
class OpcionModulo {
  const OpcionModulo(this.modulo, this.titulo, this.detalle);
  final AppModule modulo;
  final String titulo;
  final String detalle;
}

const opcionesModulos = [
  OpcionModulo(AppModule.eventos, 'Mi agenda personal', 'Reuniones, cumpleaños, SOAT, arriendo y citas médicas, con aviso por WhatsApp.'),
  OpcionModulo(AppModule.finanzas, 'Mis finanzas', 'Cuentas, tarjetas, gastos y metas, y tus compras se registran casi solas.'),
  OpcionModulo(AppModule.ciclo, 'Mi ciclo', 'Predicción del periodo, días fértiles y registro de síntomas.'),
  OpcionModulo(AppModule.citas, 'Mi negocio o servicio', 'Tu página para que los clientes reserven solos y confirmen por WhatsApp.'),
];

/// Bienvenida tras verificar la cuenta: elegir módulos y activar avisos.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _elegidos = <AppModule>{};
  int _paso = 0;
  bool _guardando = false;

  static const _pasos = 2;

  void _alternar(AppModule m) {
    HapticFeedback.selectionClick();
    setState(() => _elegidos.contains(m) ? _elegidos.remove(m) : _elegidos.add(m));
  }

  Future<void> _terminar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    await ref.read(ajustesRepoProvider).setModulos(_elegidos);
    ref.read(bienvenidaPendienteProvider.notifier).set(false);
    if (mounted) context.go('/hoy');
  }

  Future<void> _activarAvisos() async {
    await ref.read(permisoAvisosProvider.notifier).pedir();
    await _terminar();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) setState(() => _paso = 0);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuroraBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                      child: _Progreso(paso: _paso, total: _pasos),
                    ),
                    Expanded(
                      child: SmoothSwitcher(
                        axis: Axis.horizontal,
                        child: _paso == 0
                            ? _PasoModulos(key: const ValueKey(0), elegidos: _elegidos, onAlternar: _alternar)
                            : const _PasoAvisos(key: ValueKey(1)),
                      ),
                    ),
                    _Acciones(
                      paso: _paso,
                      puedeSeguir: _elegidos.isNotEmpty,
                      ocupado: _guardando,
                      onSeguir: () => setState(() => _paso = 1),
                      onAtras: () => setState(() => _paso = 0),
                      onActivar: _activarAvisos,
                      onOmitir: _terminar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso, required this.total});
  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Paso ${paso + 1} de $total',
      excludeSemantics: true,
      child: Row(children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const HGap.xs(),
          Expanded(child: ProgressBar(value: i <= paso ? 1 : 0, height: 6, color: p.accent)),
        ],
      ]),
    );
  }
}

class _PasoModulos extends StatelessWidget {
  const _PasoModulos({super.key, required this.elegidos, required this.onAlternar});
  final Set<AppModule> elegidos;
  final ValueChanged<AppModule> onAlternar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.md),
      children: [
        Semantics(header: true, child: Text('¿Para qué usarás Agendaservi?', style: context.text.headlineMedium)),
        const VGap.xs(),
        Text('Elige todo lo que quieras. Puedes cambiarlo cuando quieras en tu perfil.', style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary)),
        const VGap.lg(),
        for (final (i, o) in opcionesModulos.indexed) ...[
          if (i > 0) const VGap.sm(),
          Entrance(
            index: i,
            child: _TarjetaModulo(opcion: o, elegido: elegidos.contains(o.modulo), onTap: () => onAlternar(o.modulo)),
          ),
        ],
      ],
    );
  }
}

class _TarjetaModulo extends StatelessWidget {
  const _TarjetaModulo({required this.opcion, required this.elegido, required this.onTap});
  final OpcionModulo opcion;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = opcion.modulo.accent(Theme.of(context).brightness);
    return Semantics(
      checked: elegido,
      button: true,
      label: '${opcion.titulo}. ${opcion.detalle}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.985,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.standard,
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: elegido ? Color.alphaBlend(color.withValues(alpha: 0.10), p.surface) : p.surface,
            borderRadius: Radii.rLg,
            border: Border.all(color: elegido ? color : p.bordeTarjeta, width: elegido ? 2 : 1),
            boxShadow: p.sombraSuave,
          ),
          child: Row(children: [
            IconBadge(opcion.modulo.iconSelected, color: color, size: 48),
            const HGap.md(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(opcion.titulo, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(opcion.detalle, style: context.text.bodySmall),
              ]),
            ),
            const HGap.sm(),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: Icon(
                elegido ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                key: ValueKey(elegido),
                color: elegido ? color : p.textSecondary,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PasoAvisos extends StatelessWidget {
  const _PasoAvisos({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.md),
      children: [
        IconBadge(Icons.notifications_active_rounded, color: p.accent, size: 64),
        const VGap.lg(),
        Semantics(header: true, child: Text('Que nada se te pase', style: context.text.headlineMedium)),
        const VGap.xs(),
        Text(
          'Te avisamos en este teléfono antes de cada evento, cita o pago, además del recordatorio por WhatsApp.',
          style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
        ),
        const VGap.lg(),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, (icono, texto)) in const [
              (Icons.schedule_rounded, '30 minutos antes y a la hora exacta'),
              (Icons.wb_sunny_rounded, 'Resumen de tu día a las 7:00 a. m.'),
              (Icons.tune_rounded, 'Tú decides cuáles recibir, desde tu perfil'),
            ].indexed) ...[
              if (i > 0) const VGap.sm(),
              Row(children: [
                Icon(icono, color: p.accent, size: IconSizes.md),
                const HGap.sm(),
                Expanded(child: Text(texto, style: context.text.bodyMedium)),
              ]),
            ],
          ]),
        ),
      ],
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.paso,
    required this.puedeSeguir,
    required this.ocupado,
    required this.onSeguir,
    required this.onAtras,
    required this.onActivar,
    required this.onOmitir,
  });

  final int paso;
  final bool puedeSeguir;
  final bool ocupado;
  final VoidCallback onSeguir;
  final VoidCallback onAtras;
  final VoidCallback onActivar;
  final VoidCallback onOmitir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: paso == 0
            ? [
                if (!puedeSeguir)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: Text('Elige al menos una opción para continuar.', textAlign: TextAlign.center, style: context.text.bodySmall),
                  ),
                FilledButton(onPressed: puedeSeguir ? onSeguir : null, child: const Text('Continuar')),
              ]
            : [
                FilledButton(onPressed: ocupado ? null : onActivar, child: const Text('Activar avisos')),
                const VGap.xs(),
                Row(children: [
                  Expanded(child: TextButton(onPressed: ocupado ? null : onAtras, child: const Text('Atrás'))),
                  const HGap.xs(),
                  Expanded(child: TextButton(onPressed: ocupado ? null : onOmitir, child: const Text('Ahora no'))),
                ]),
              ],
      ),
    );
  }
}
