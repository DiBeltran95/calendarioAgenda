import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../../events/event_categories.dart';
import '../../events/events_repository.dart';
import '../fijos_sugeridos.dart';

/// Pagos de cada mes que todavía no están en Eventos: agendarlos hace que el
/// plan del sueldo los descuente antes de pagarlos.
class FijosSugeridosCard extends ConsumerStatefulWidget {
  const FijosSugeridosCard({super.key, required this.sugeridos});
  final List<FijoSugerido> sugeridos;

  @override
  ConsumerState<FijosSugeridosCard> createState() => _FijosSugeridosCardState();
}

class _FijosSugeridosCardState extends ConsumerState<FijosSugeridosCard> {
  /// Filas en curso o ya resueltas: desaparecen al instante.
  final _listos = <String>{};

  Future<void> _agendar(FijoSugerido f) async {
    final toaster = Toaster.of(context);
    setState(() => _listos.add(f.clave));
    try {
      await ref.read(eventsRepoProvider).crear(EventoInput(
            titulo: f.titulo,
            fecha: f.proximaFecha,
            categoria: f.categoriaEvento,
            frecuencia: 'mensual',
            tipoTransaccion: 'gasto',
            costo: f.monto,
          ));
      HapticFeedback.mediumImpact();
      toaster.show('Agendado: ${f.titulo}, cada mes el día ${f.dia}', icon: Icons.event_available_rounded);
    } catch (_) {
      if (mounted) setState(() => _listos.remove(f.clave));
      toaster.show('No se pudo agendar. Revisa tu conexión e inténtalo de nuevo.', error: true);
    }
  }

  Future<void> _descartar(FijoSugerido f) async {
    setState(() => _listos.add(f.clave));
    final prefs = ref.read(preferenciasProvider).value ?? const Preferencias();
    await ref.read(ajustesRepoProvider).setFijosDescartados({...prefs.fijosDescartados, f.clave});
  }

  @override
  Widget build(BuildContext context) {
    final lista = widget.sugeridos.where((f) => !_listos.contains(f.clave)).toList();
    if (lista.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(
            '¿Agendamos tus pagos fijos?',
            icon: Icons.event_repeat_rounded,
            subtitle: 'Así tu plan los descuenta antes de pagarlos',
          ),
          for (final (i, f) in lista.indexed) ...[
            if (i > 0) const Divider(height: Gap.lg),
            _Fila(fijo: f, alAgendar: () => _agendar(f), alDescartar: () => _descartar(f)),
          ],
        ]),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.fijo, required this.alAgendar, required this.alDescartar});
  final FijoSugerido fijo;
  final VoidCallback alAgendar;
  final VoidCallback alDescartar;

  @override
  Widget build(BuildContext context) {
    final f = fijo;
    final c = categoriaEvento(f.categoriaEvento);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconBadge(c.icon, color: c.colorDe(context), size: 40),
        const HGap.sm(),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.titulo, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${cop(f.monto)} · cada mes el día ${f.dia} · próximo ${fechaCorta(f.proximaFecha)}', style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
      const VGap.xs(),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: alDescartar, child: const Text('No es fijo')),
        const HGap.xs(),
        FilledButton.tonalIcon(onPressed: alAgendar, icon: const Icon(Icons.event_available_rounded), label: const Text('Agendar')),
      ]),
    ]);
  }
}
