import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';

/// Pantalla breve mientras abre la base de datos.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Entrance(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/logo.png', width: 96, height: 96, semanticLabel: 'Agendaservi'),
          ),
        ),
      ),
    );
  }
}

/// Bienvenida de primer uso: presenta los tres calendarios y pide el nombre
/// para personalizar el saludo. Nada sale del dispositivo.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _nombre = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _empezar() async {
    final repo = ref.read(ajustesRepoProvider);
    await repo.setNombre(_nombre.text);
    await repo.marcarBienvenida();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduced = Motion.reduced(context);
    const features = [
      (AppModule.eventos, 'Eventos, cumpleaños, festivos de Colombia y pagos recurrentes.'),
      (AppModule.ciclo, 'Tu ciclo con predicciones, ventana fértil y registro de síntomas.'),
      (AppModule.finanzas, 'Cuentas, tarjetas, metas, presupuestos y un experto económico.'),
    ];

    Widget logo = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset('assets/images/logo.png', width: 104, height: 104, semanticLabel: 'Logo de Agendaservi'),
    );
    if (!reduced) {
      logo = logo
          .animate()
          .scale(begin: const Offset(0.6, 0.6), duration: 700.ms, curve: Curves.easeOutBack)
          .fadeIn(duration: 400.ms)
          .then(delay: 200.ms)
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.25));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xxl, Gap.xl, Gap.xl),
              children: [
                Center(child: logo),
                const VGap.xl(),
                Entrance(
                  index: 2,
                  child: Text('Agendaservi', textAlign: TextAlign.center, style: context.text.displaySmall),
                ),
                const VGap.xs(),
                Entrance(
                  index: 3,
                  child: Text(
                    'Tres calendarios, una sola app. Organiza tu tiempo, tu ciclo y tu dinero.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(color: p.textSecondary),
                  ),
                ),
                const VGap.xl(),
                for (var i = 0; i < features.length; i++)
                  Entrance(
                    index: 4 + i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: Row(
                        children: [
                          IconBadge(features[i].$1.iconSelected, color: features[i].$1.accent(Theme.of(context).brightness), size: 48),
                          const HGap.md(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(features[i].$1.titulo, style: context.text.titleSmall),
                                Text(features[i].$2, style: context.text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const VGap.lg(),
                Entrance(
                  index: 8,
                  child: TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _empezar(),
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(
                      labelText: '¿Cómo te llamas?',
                      hintText: 'Opcional',
                      prefixIcon: Icon(Icons.waving_hand_rounded),
                    ),
                  ),
                ),
                const VGap.md(),
                Entrance(
                  index: 9,
                  child: FilledButton(onPressed: _empezar, child: const Text('Comenzar')),
                ),
                const VGap.md(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, size: IconSizes.sm, color: p.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Tus datos se guardan solo en este dispositivo.', style: context.text.bodySmall),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
