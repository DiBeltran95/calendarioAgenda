import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/widgets/sheets.dart' show validarFormulario;
import 'auth_repository.dart';
import 'auth_widgets.dart';

/// Datos que viajan a la pantalla de verificación.
class DatosVerificacion {
  const DatosVerificacion({required this.email, this.whatsapp = '', this.mensaje});
  final String email;
  final String whatsapp;
  final String? mensaje;
}

/// "+57 300 *** 4567" (se muestra el número sin exponerlo completo).
String whatsappEnmascarado(String w) {
  final d = w.replaceAll(RegExp(r'\D'), '');
  if (d.length < 7) return d.isEmpty ? 'tu WhatsApp' : '+$d';
  final cc = d.length > 10 ? d.substring(0, d.length - 10) : '';
  final n = d.substring(d.length - 10 < 0 ? 0 : d.length - 10);
  return '${cc.isEmpty ? '' : '+$cc '}${n.substring(0, 3)} *** ${n.substring(n.length - 4)}';
}

// ─────────────────────────── Iniciar sesión ───────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_cargando || !validarFormulario(_form)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await ref.read(authRepoProvider).iniciarSesion(_email.text, _pass.text);
      if (!mounted) return;
      switch (r) {
        case AuthOk(:final sesion):
          TextInput.finishAutofillContext();
          HapticFeedback.mediumImpact();
          await ref.read(sesionProvider.notifier).iniciar(sesion);
        case AuthVerificar():
          context.push('/verificar', extra: DatosVerificacion(email: r.email, whatsapp: r.whatsapp, mensaje: r.mensaje));
      }
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final aviso = ref.watch(avisoSesionProvider);
    return AuthShell(
      titulo: 'Bienvenido de nuevo',
      subtitulo: 'Inicia sesión para ver tu agenda, tus recordatorios y tus finanzas.',
      pie: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('¿No tienes cuenta?', style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
          TextButton(onPressed: () => context.go('/registro'), child: const Text('Crear cuenta gratis')),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (aviso != null && _error == null) ...[ErrorBanner(mensaje: aviso, info: true), const VGap.md()],
              if (_error != null) ...[ErrorBanner(mensaje: _error!), const VGap.md()],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Escribe un correo válido',
              ),
              const VGap.md(),
              PasswordField(controller: _pass, onSubmitted: (_) => _entrar()),
              const VGap.lg(),
              FilledButton(
                onPressed: _cargando ? null : _entrar,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: _cargando
                      ? SizedBox(key: const ValueKey('c'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onAccent))
                      : const Text('Iniciar sesión', key: ValueKey('t')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Crear cuenta ───────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _wa = TextEditingController();
  final _pass = TextEditingController();
  String _indicativo = '57';
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _wa, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_cargando || !validarFormulario(_form)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final whatsapp = '$_indicativo${_wa.text.replaceAll(RegExp(r'\D'), '')}';
      final r = await ref.read(authRepoProvider).registrar(nombre: _nombre.text, email: _email.text, password: _pass.text, whatsapp: whatsapp);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.push('/verificar', extra: DatosVerificacion(email: r.email, whatsapp: whatsapp, mensaje: r.mensaje));
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuthShell(
      titulo: 'Crea tu cuenta',
      subtitulo: 'Te enviaremos un código por WhatsApp para confirmar que eres tú.',
      pie: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('¿Ya tienes cuenta?', style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Iniciar sesión')),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[ErrorBanner(mensaje: _error!), const VGap.md()],
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe tu nombre' : null,
              ),
              const VGap.md(),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Escribe un correo válido',
              ),
              const VGap.md(),
              WhatsAppField(controller: _wa, indicativo: _indicativo, onIndicativo: (v) => setState(() => _indicativo = v)),
              const VGap.md(),
              PasswordField(controller: _pass, medidor: true, nueva: true, onSubmitted: (_) => _registrar()),
              const VGap.lg(),
              FilledButton(
                onPressed: _cargando ? null : _registrar,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: _cargando
                      ? SizedBox(key: const ValueKey('c'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onAccent))
                      : const Text('Crear cuenta', key: ValueKey('t')),
                ),
              ),
              const VGap.sm(),
              Row(children: [
                Icon(Icons.lock_rounded, size: IconSizes.sm, color: p.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text('Tu número solo se usa para enviarte tus recordatorios.', style: context.text.bodySmall)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Verificar código ───────────────────────────

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.datos});
  final DatosVerificacion datos;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _otp = GlobalKey<OtpFieldState>();
  bool _cargando = false;
  bool _error = false;
  String? _mensaje;
  String? _info;
  int _espera = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _info = widget.datos.mensaje;
    _contar();
  }

  void _contar() {
    _timer?.cancel();
    setState(() => _espera = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _espera--);
      if (_espera <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verificar(String codigo) async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = false;
      _mensaje = null;
    });
    try {
      final s = await ref.read(authRepoProvider).verificar(widget.datos.email, codigo);
      HapticFeedback.heavyImpact();
      ref.read(bienvenidaPendienteProvider.notifier).set(true);
      await ref.read(sesionProvider.notifier).iniciar(s);
    } on AuthError catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _error = true;
        _mensaje = e.mensaje;
      });
      _otp.currentState?.limpiar();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviar() async {
    try {
      await ref.read(authRepoProvider).reenviarCodigo(widget.datos.email);
      if (!mounted) return;
      setState(() {
        _info = 'Te enviamos un código nuevo.';
        _mensaje = null;
        _error = false;
      });
      _contar();
    } on AuthError catch (e) {
      if (mounted) setState(() => _mensaje = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const wa = Brand.whatsapp;
    return AuthShell(
      titulo: 'Revisa tu WhatsApp',
      subtitulo: 'Escribe el código de 6 dígitos que enviamos a ${whatsappEnmascarado(widget.datos.whatsapp)}.',
      arriba: IconButton(
        tooltip: 'Volver',
        onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      pie: Center(
        child: TextButton(
          onPressed: () => context.go('/registro'),
          child: const Text('¿Número equivocado? Regístralo de nuevo'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _Pulso(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: wa.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.chat_rounded, color: wa, size: 30),
              ),
            ),
          ),
          const VGap.lg(),
          if (_mensaje != null) ...[ErrorBanner(mensaje: _mensaje!), const VGap.md()] else if (_info != null) ...[
            ErrorBanner(mensaje: _info!, info: true),
            const VGap.md(),
          ],
          OtpField(key: _otp, onCompleto: _verificar, error: _error, enabled: !_cargando),
          const VGap.lg(),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: _cargando
                ? Row(key: const ValueKey('v'), mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: p.accent)),
                    const HGap.sm(),
                    Text('Verificando…', style: context.text.bodyMedium),
                  ])
                : Center(
                    key: const ValueKey('r'),
                    child: _espera > 0
                        ? Text('Puedes pedir otro código en $_espera s', style: context.text.bodySmall)
                        : TextButton.icon(onPressed: _reenviar, icon: const Icon(Icons.refresh_rounded), label: const Text('Reenviar código')),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Halo que late suavemente alrededor del ícono de WhatsApp.
class _Pulso extends StatefulWidget {
  const _Pulso({required this.child});
  final Widget child;

  @override
  State<_Pulso> createState() => _PulsoState();
}

class _PulsoState extends State<_Pulso> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Stack(alignment: Alignment.center, children: [
        Container(
          width: 64 + 36 * _c.value,
          height: 64 + 36 * _c.value,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Brand.whatsapp.withValues(alpha: 0.18 * (1 - _c.value))),
        ),
        child!,
      ]),
      child: SizedBox(width: 100, height: 100, child: Center(child: widget.child)),
    );
  }
}
