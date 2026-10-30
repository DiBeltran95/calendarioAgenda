import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../../core/widgets/sheets.dart';
import '../citas_models.dart';

String _sinEsquema(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

Future<void> compartirEnlace(BuildContext context, NegocioAgenda n) async {
  final caja = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    text: 'Agenda tu cita en ${n.nombre} 👉 ${n.enlace}',
    subject: 'Agenda tu cita en ${n.nombre}',
    sharePositionOrigin: caja == null ? null : caja.localToGlobal(Offset.zero) & caja.size,
  ));
}

Future<void> copiarEnlace(BuildContext context, NegocioAgenda n) async {
  await Clipboard.setData(ClipboardData(text: n.enlace));
  HapticFeedback.lightImpact();
  if (context.mounted) Toaster.of(context).show('Enlace copiado', icon: Icons.link_rounded);
}

/// Tarjeta principal del módulo: el enlace para compartir (estilo Calendly).
class TarjetaEnlace extends StatelessWidget {
  const TarjetaEnlace({super.key, required this.negocio});
  final NegocioAgenda negocio;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final marca = Color(negocio.color);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: marca, borderRadius: Radii.rMd),
              child: Icon(Icons.link_rounded, color: textoSobre(marca)),
            ),
            const HGap.sm(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tu página para agendar', style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
                Text(
                  _sinEsquema(negocio.enlace),
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            _Estado(activo: negocio.activo),
          ]),
          const VGap.md(),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => compartirEnlace(context, negocio),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: const Text('Compartir'),
                style: FilledButton.styleFrom(backgroundColor: marca, foregroundColor: textoSobre(marca)),
              ),
            ),
            const HGap.xs(),
            _BotonCuadrado(icon: Icons.copy_rounded, tooltip: 'Copiar enlace', onTap: () => copiarEnlace(context, negocio)),
            const HGap.xs(),
            _BotonCuadrado(icon: Icons.qr_code_2_rounded, tooltip: 'Ver código QR', onTap: () => mostrarQr(context, negocio)),
          ]),
        ],
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({required this.activo});
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = activo ? p.success : p.warning;
    return Semantics(
      label: activo ? 'Página activa' : 'Página pausada',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Latido(color: color, activo: activo),
          const SizedBox(width: 6),
          Text(activo ? 'Activa' : 'Pausada', style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Punto que "late" suavemente cuando la página está recibiendo reservas.
class _Latido extends StatefulWidget {
  const _Latido({required this.color, required this.activo});
  final Color color;
  final bool activo;

  @override
  State<_Latido> createState() => _LatidoState();
}

class _LatidoState extends State<_Latido> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.activo && !Motion.reduced(context)) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(alignment: Alignment.center, children: [
          if (widget.activo)
            Transform.scale(
              scale: 1 + _c.value * 1.2,
              child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: (1 - _c.value) * 0.4))),
            ),
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

class _BotonCuadrado extends StatelessWidget {
  const _BotonCuadrado({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: Radii.rMd)),
    );
  }
}

/// Código QR del enlace (para imprimir o mostrar en el mostrador).
Future<void> mostrarQr(BuildContext context, NegocioAgenda n) {
  return showAppSheet<void>(
    context,
    (_) => SheetScaffold(
      title: 'Código QR',
      subtitle: 'Tus clientes lo escanean con la cámara y agendan al instante.',
      icon: Icons.qr_code_2_rounded,
      primaryLabel: 'Compartir enlace',
      onPrimary: () => compartirEnlace(context, n),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(color: Colors.white, borderRadius: Radii.rLg, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 8))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QrImageView(
                data: n.enlace,
                size: 220,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(n.color)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF0F172A)),
                semanticsLabel: 'Código QR de ${n.enlace}',
              ),
              const VGap.sm(),
              Text(n.nombre, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 16)),
              Text(_sinEsquema(n.enlace), style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
            ]),
          ).animate(delay: 80.ms).fadeIn(duration: 260.ms).scale(begin: const Offset(0.94, 0.94), curve: Motion.enter),
        ),
      ],
    ),
  );
}
