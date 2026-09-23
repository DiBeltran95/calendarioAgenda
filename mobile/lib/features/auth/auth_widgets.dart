import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';

/// Fondo con "auroras" de color que se desplazan muy despacio. Da vida a las
/// pantallas de acceso sin distraer; con movimiento reducido queda estático.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

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
    final p = context.palette;
    final dark = context.isDark;
    return ColoredBox(
      color: p.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value * 2 * math.pi;
              Widget blob(Color c, double size, Alignment base, double fase) => Align(
                    alignment: Alignment(base.x + 0.25 * math.sin(t + fase), base.y + 0.2 * math.cos(t * 0.8 + fase)),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [c.withValues(alpha: dark ? 0.32 : 0.22), c.withValues(alpha: 0)]),
                      ),
                    ),
                  );
              return Stack(children: [
                blob(const Color(0xFF25D366), 420, const Alignment(-1.1, -0.9), 0),
                blob(const Color(0xFF60A5FA), 380, const Alignment(1.1, -0.2), 2),
                blob(const Color(0xFFF472B6), 340, const Alignment(-0.6, 1.1), 4),
              ]);
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Estructura de las pantallas de acceso: logo, tarjeta con el formulario y
/// pie; centrada y con ancho máximo en tablet/web.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.titulo, required this.subtitulo, required this.child, this.pie, this.arriba});

  final String titulo;
  final String subtitulo;
  final Widget child;
  final Widget? pie;

  /// Contenido sobre el título (p. ej. el botón volver).
  final Widget? arriba;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (arriba != null) Align(alignment: Alignment.centerLeft, child: arriba!),
                    Hero(
                      tag: 'logo-auth',
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset('assets/images/logo.png', width: 76, height: 76, semanticLabel: 'Agendaservi'),
                        ),
                      ),
                    ),
                    const VGap.lg(),
                    Entrance(
                      child: Semantics(
                        header: true,
                        child: Text(titulo, textAlign: TextAlign.center, style: context.text.headlineMedium),
                      ),
                    ),
                    const VGap.xs(),
                    Entrance(
                      index: 1,
                      child: Text(subtitulo, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
                    ),
                    const VGap.xl(),
                    Entrance(
                      index: 2,
                      child: Container(
                        padding: const EdgeInsets.all(Gap.lg),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: context.isDark ? 0.86 : 0.94),
                          borderRadius: Radii.rXl,
                          border: Border.all(color: p.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.08), blurRadius: 30, offset: const Offset(0, 14))],
                        ),
                        child: child,
                      ),
                    ),
                    if (pie != null) ...[const VGap.lg(), Entrance(index: 3, child: pie!)],
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

/// Mensaje de error del servidor, anunciado a lectores de pantalla y con un
/// breve "temblor" para llamar la atención.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.mensaje, this.info = false});
  final String mensaje;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = info ? p.info : p.danger;
    Widget w = Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.sm),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: Radii.rMd, border: Border.all(color: c.withValues(alpha: 0.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(info ? Icons.info_outline_rounded : Icons.error_outline_rounded, color: c, size: IconSizes.md),
          const HGap.xs(),
          Expanded(child: Text(mensaje, style: context.text.bodyMedium?.copyWith(color: c))),
        ]),
      ),
    );
    if (!Motion.reduced(context) && !info) {
      w = w.animate(key: ValueKey(mensaje)).shakeX(hz: 5, amount: 5, duration: 400.ms);
    }
    return w;
  }
}

/// Contraseña con botón mostrar/ocultar y (opcional) medidor de seguridad.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.label = 'Contraseña', this.medidor = false, this.onSubmitted, this.nueva = false});
  final TextEditingController controller;
  final String label;
  final bool medidor;
  final bool nueva;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _oculta = true;

  @override
  void initState() {
    super.initState();
    if (widget.medidor) widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  /// 0..4 según longitud y variedad de caracteres.
  int _fuerza(String s) {
    if (s.isEmpty) return 0;
    var f = 0;
    if (s.length >= 6) f++;
    if (s.length >= 10) f++;
    if (RegExp(r'[A-Z]').hasMatch(s) && RegExp(r'[a-z]').hasMatch(s)) f++;
    if (RegExp(r'\d').hasMatch(s) && RegExp(r'[^A-Za-z0-9]').hasMatch(s)) f++;
    return f.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = _fuerza(widget.controller.text);
    final colores = [p.danger, p.danger, p.warning, p.success, p.success];
    const etiquetas = ['', 'Débil', 'Aceptable', 'Buena', 'Excelente'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _oculta,
          autofillHints: [widget.nueva ? AutofillHints.newPassword : AutofillHints.password],
          textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _oculta = !_oculta),
              icon: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: Icon(_oculta ? Icons.visibility_rounded : Icons.visibility_off_rounded, key: ValueKey(_oculta)),
              ),
            ),
          ),
          validator: (v) {
            if ((v ?? '').isEmpty) return 'Escribe tu contraseña';
            if (widget.nueva && v!.length < 6) return 'Usa al menos 6 caracteres';
            return null;
          },
        ),
        if (widget.medidor && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 1; i <= 4; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  height: 4,
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  decoration: BoxDecoration(color: i <= f ? colores[f] : p.surfaceHighest, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            const HGap.xs(),
            SizedBox(width: 70, child: Text(etiquetas[f], style: context.text.labelSmall?.copyWith(color: colores[f]))),
          ]),
        ],
      ],
    );
  }
}

/// Indicativos de país más comunes (Colombia por defecto).
const indicativos = <(String, String, String)>[
  ('57', '🇨🇴', 'Colombia'),
  ('52', '🇲🇽', 'México'),
  ('58', '🇻🇪', 'Venezuela'),
  ('593', '🇪🇨', 'Ecuador'),
  ('51', '🇵🇪', 'Perú'),
  ('56', '🇨🇱', 'Chile'),
  ('54', '🇦🇷', 'Argentina'),
  ('507', '🇵🇦', 'Panamá'),
  ('34', '🇪🇸', 'España'),
  ('1', '🇺🇸', 'Estados Unidos'),
];

/// Número de WhatsApp con indicativo. El servidor lo guarda solo con dígitos.
class WhatsAppField extends StatelessWidget {
  const WhatsAppField({super.key, required this.controller, required this.indicativo, required this.onIndicativo});
  final TextEditingController controller;
  final String indicativo;
  final ValueChanged<String> onIndicativo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final actual = indicativos.firstWhere((i) => i.$1 == indicativo, orElse: () => indicativos.first);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
      decoration: InputDecoration(
        labelText: 'WhatsApp',
        helperText: 'Aquí te llegarán el código y tus recordatorios.',
        helperMaxLines: 2,
        prefixIcon: PopupMenuButton<String>(
          tooltip: 'Indicativo del país',
          initialValue: indicativo,
          onSelected: onIndicativo,
          itemBuilder: (_) => [
            for (final (c, f, n) in indicativos) PopupMenuItem(value: c, child: Text('$f  $n  +$c')),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.md, right: Gap.xs),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${actual.$2} +${actual.$1}', style: context.text.bodyLarge),
              Icon(Icons.arrow_drop_down_rounded, color: p.textSecondary),
            ]),
          ),
        ),
      ),
      validator: (v) {
        final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
        if (d.isEmpty) return 'Escribe tu número de WhatsApp';
        if ((indicativo + d).length < 10) return 'El número parece incompleto';
        return null;
      },
    );
  }
}

/// Seis casillas para el código. Admite pegar el código completo y avisa en
/// cuanto está completo (sin tener que tocar "Verificar").
class OtpField extends StatefulWidget {
  const OtpField({super.key, required this.onCompleto, this.error = false, this.enabled = true});
  final ValueChanged<String> onCompleto;
  final bool error;
  final bool enabled;

  @override
  State<OtpField> createState() => OtpFieldState();
}

class OtpFieldState extends State<OtpField> {
  static const _n = 6;
  final _c = TextEditingController();
  final _foco = FocusNode();

  void limpiar() {
    _c.clear();
    _foco.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final txt = _c.text;
    Widget casillas = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < _n; i++)
          AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            width: 46,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceHigh,
              borderRadius: Radii.rMd,
              border: Border.all(
                width: i == txt.length && _foco.hasFocus ? 2 : 1.2,
                color: widget.error ? p.danger : (i == txt.length && _foco.hasFocus ? p.accent : (i < txt.length ? p.accent.withValues(alpha: 0.6) : p.border)),
              ),
            ),
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
              child: Text(i < txt.length ? txt[i] : '', key: ValueKey('$i-${i < txt.length ? txt[i] : ''}'), style: context.text.headlineSmall),
            ),
          ),
      ],
    );
    if (widget.error && !Motion.reduced(context)) {
      casillas = casillas.animate(key: ValueKey('err-$txt')).shakeX(hz: 6, amount: 6, duration: 380.ms);
    }
    return Semantics(
      label: 'Código de verificación de 6 dígitos',
      textField: true,
      child: GestureDetector(
        onTap: () => _foco.requestFocus(),
        child: Stack(
          children: [
            casillas,
            // Campo real (invisible) que recibe el teclado y el pegado.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _c,
                  focusNode: _foco,
                  enabled: widget.enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_n)],
                  showCursor: false,
                  onChanged: (v) {
                    setState(() {});
                    if (v.length == _n) {
                      HapticFeedback.lightImpact();
                      widget.onCompleto(v);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
