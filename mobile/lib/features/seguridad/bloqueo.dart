import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';

/// Face ID, huella o, si fallan, el código del teléfono.
abstract class ServicioBiometria {
  Future<bool> disponible();
  Future<bool> autenticar(String motivo);
}

class BiometriaInerte implements ServicioBiometria {
  @override
  Future<bool> disponible() async => false;
  @override
  Future<bool> autenticar(String motivo) async => true;
}

class BiometriaDispositivo implements ServicioBiometria {
  final _auth = LocalAuthentication();

  @override
  Future<bool> disponible() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> autenticar(String motivo) async {
    try {
      return await _auth.authenticate(localizedReason: motivo, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

final servicioBiometriaProvider = Provider<ServicioBiometria>((ref) => kIsWeb ? BiometriaInerte() : BiometriaDispositivo());

final biometriaDisponibleProvider = FutureProvider<bool>((ref) => ref.read(servicioBiometriaProvider).disponible());

/// Reloj del bloqueo (las pruebas lo adelantan).
final relojBloqueoProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Tiempo fuera de la app a partir del cual se vuelve a pedir el desbloqueo.
const esperaBloqueo = Duration(minutes: 2);

class EstadoBloqueo extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

/// true: la app está tapada hasta que la persona se identifique.
final bloqueadaProvider = NotifierProvider<EstadoBloqueo, bool>(EstadoBloqueo.new);

/// Tapa la app si el bloqueo está activo: al abrirla, al volver después de
/// [esperaBloqueo], y (difuminada) en el selector de apps del sistema.
class CapaBloqueo extends ConsumerStatefulWidget {
  const CapaBloqueo({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CapaBloqueo> createState() => _CapaBloqueoState();
}

class _CapaBloqueoState extends ConsumerState<CapaBloqueo> {
  late final AppLifecycleListener _ciclo;
  DateTime? _salio;
  bool _revisoArranque = false;
  bool _enSegundoPlano = false;

  bool get _activo => ref.read(preferenciasProvider).value?.bloqueo == true && ref.read(sesionProvider).value != null;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onInactive: () => _privacidad(true),
      onResume: () {
        _privacidad(false);
        final salio = _salio;
        _salio = null;
        if (salio != null && _activo && ref.read(relojBloqueoProvider)().difference(salio) >= esperaBloqueo) {
          ref.read(bloqueadaProvider.notifier).set(true);
        }
      },
      onPause: () => _salio ??= ref.read(relojBloqueoProvider)(),
    );
  }

  void _privacidad(bool oculto) {
    if (_enSegundoPlano != oculto && mounted) setState(() => _enSegundoPlano = oculto);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  void _revisarArranque() {
    final prefs = ref.read(preferenciasProvider);
    final sesion = ref.read(sesionProvider);
    if (_revisoArranque || !prefs.hasValue || sesion.isLoading) return;
    _revisoArranque = true;
    if (_activo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(bloqueadaProvider.notifier).set(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferenciasProvider);
    final sesion = ref.watch(sesionProvider);
    final bloqueada = ref.watch(bloqueadaProvider);
    _revisarArranque();
    final activo = prefs.value?.bloqueo == true && sesion.value != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (activo && _enSegundoPlano && !bloqueada)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: ColoredBox(color: context.palette.bg.withValues(alpha: 0.5)),
              ),
            ),
          ),
        if (bloqueada) const Positioned.fill(child: PantallaBloqueo()),
      ],
    );
  }
}

class PantallaBloqueo extends ConsumerStatefulWidget {
  const PantallaBloqueo({super.key});

  @override
  ConsumerState<PantallaBloqueo> createState() => _PantallaBloqueoState();
}

class _PantallaBloqueoState extends ConsumerState<PantallaBloqueo> {
  bool _pidiendo = false;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pedir());
  }

  Future<void> _pedir() async {
    if (_pidiendo || !mounted) return;
    setState(() {
      _pidiendo = true;
      _fallo = false;
    });
    final servicio = ref.read(servicioBiometriaProvider);
    // Si el teléfono ya no tiene con qué identificar, no se puede quedar fuera.
    final ok = !await servicio.disponible() || await servicio.autenticar('Desbloquea Agendaservi para ver tu información');
    if (!mounted) return;
    if (ok) {
      ref.read(bloqueadaProvider.notifier).set(false);
    } else {
      setState(() {
        _pidiendo = false;
        _fallo = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: Image.asset('assets/images/logo.png', width: 88, height: 88, semanticLabel: 'Agendaservi'),
                ),
                const VGap.lg(),
                Semantics(header: true, child: Text('Agendaservi está bloqueada', textAlign: TextAlign.center, style: context.text.headlineSmall)),
                const VGap.xs(),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _fallo ? 'No pudimos identificarte. Inténtalo de nuevo.' : 'Identifícate para ver tu información.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: _fallo ? p.danger : p.textSecondary),
                  ),
                ),
                const VGap.xl(),
                FilledButton.icon(
                  onPressed: _pidiendo ? null : _pedir,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
