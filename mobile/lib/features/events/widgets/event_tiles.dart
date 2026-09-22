import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/db/database.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../event_categories.dart';
import '../events_repository.dart';
import '../whatsapp.dart';
import 'event_form_sheet.dart';

// ─────────────────────────── Acciones ───────────────────────────

/// Borra un evento (preguntando el alcance si es de una serie) con "Deshacer".
Future<void> eliminarEvento(BuildContext context, WidgetRef ref, Evento e) async {
  final repo = ref.read(eventsRepoProvider);
  final toaster = Toaster.of(context);
  var alcance = AlcanceSerie.soloEste;
  if (repo.esSerie(e)) {
    final a = await preguntarAlcance(context, borrar: true);
    if (a == null) return;
    alcance = a;
  }
  final afectados = await repo.afectados(e, alcance);
  await repo.eliminar(e, alcance);
  HapticFeedback.mediumImpact();
  toaster.show(
    afectados.length > 1 ? '${afectados.length} eventos eliminados' : 'Evento eliminado',
    icon: Icons.delete_outline_rounded,
    onUndo: () => repo.restaurar(afectados),
  );
}

Future<void> eliminarCumple(BuildContext context, WidgetRef ref, Cumple c) async {
  final repo = ref.read(eventsRepoProvider);
  final toaster = Toaster.of(context);
  await repo.eliminarCumple(c.id);
  HapticFeedback.mediumImpact();
  toaster.show('Cumpleaños eliminado', icon: Icons.delete_outline_rounded, onUndo: () => repo.restaurarCumple(c));
}

// ─────────────────────────── Tile de evento ───────────────────────────

class EventTile extends ConsumerWidget {
  const EventTile({super.key, required this.evento, this.mostrarFecha = false});

  final Evento evento;
  final bool mostrarFecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final e = evento;
    final cat = categoriaEvento(e.categoria);
    final esTx = e.tipoTransaccion != 'ninguno';
    final pagado = e.estadoPago == 'pagado';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.xs, Gap.sm),
      onTap: () => showAppSheet(context, (_) => EventDetailSheet(evento: e, parentContext: context)),
      semanticLabel: '${e.titulo}, ${cat.label}${e.hora != null ? ', ${hora12(e.hora)}' : ''}',
      child: Row(
        children: [
          // Hora
          SizedBox(
            width: 56,
            child: Column(
              children: [
                if (mostrarFecha) ...[
                  Text(fechaCorta(e.fecha), style: context.text.labelSmall),
                  const SizedBox(height: 2),
                ],
                if (e.hora == null)
                  Icon(Icons.wb_sunny_outlined, size: IconSizes.md, color: p.textSecondary)
                else ...[
                  Text(hora12(e.hora).split(' ').first,
                      style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  Text(hora12(e.hora).split(' ').skip(1).join(' '), style: context.text.labelSmall),
                ],
              ],
            ),
          ),
          Container(width: 3, height: 40, decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(2))),
          const HGap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.titulo, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tag(cat.label, color: cat.color, icon: cat.icon),
                    if (e.frecuencia != 'unica') Tag(frecuenciaLabel(e.frecuencia), icon: Icons.repeat_rounded),
                    if (e.ubicacion.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.place_outlined, size: 13, color: p.textSecondary),
                        const SizedBox(width: 2),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(e.ubicacion, style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                  ],
                ),
                if (esTx) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${e.tipoTransaccion == 'ingreso' ? '+' : '-'}${cop(e.costo)}',
                    style: context.text.titleSmall?.copyWith(
                      color: e.tipoTransaccion == 'ingreso' ? p.success : p.danger,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (esTx)
            _PagoToggle(
              pagado: pagado,
              onTap: () => ref.read(eventsRepoProvider).alternarPago(e),
            ),
        ],
      ),
    );
  }
}

/// Casilla de "pagado" con animación de check.
class _PagoToggle extends StatelessWidget {
  const _PagoToggle({required this.pagado, required this.onTap});
  final bool pagado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = pagado ? p.success : p.warning;
    return Semantics(
      button: true,
      checked: pagado,
      label: pagado ? 'Pagado. Tocar para marcar pendiente' : 'Pendiente. Tocar para marcar pagado',
      child: Pressable(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.enter,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: pagado ? c : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2),
              ),
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                transitionBuilder: (w, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: w),
                child: Icon(
                  pagado ? Icons.check_rounded : Icons.schedule_rounded,
                  key: ValueKey(pagado),
                  size: 18,
                  color: pagado ? p.onAccent : c,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Detalle de evento ───────────────────────────

class EventDetailSheet extends ConsumerWidget {
  const EventDetailSheet({super.key, required this.evento, required this.parentContext});
  final Evento evento;

  /// Contexto de quien abrió la hoja: sigue montado después de cerrarla.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final e = evento;
    final cat = categoriaEvento(e.categoria);
    final mensaje = mensajeRecordatorio(e);
    final esTx = e.tipoTransaccion != 'ninguno';

    Widget fila(IconData icon, String texto, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, size: IconSizes.md, color: color ?? p.textSecondary),
            const HGap.sm(),
            Expanded(child: Text(texto, style: context.text.bodyLarge?.copyWith(color: color))),
          ]),
        );

    return SheetScaffold(
      title: e.titulo,
      subtitle: cat.label,
      icon: cat.icon,
      primaryLabel: 'Editar',
      onPrimary: () {
        Navigator.pop(context);
        abrirFormularioEvento(parentContext, evento: e);
      },
      secondary: OutlinedButton.icon(
        onPressed: () async {
          Navigator.pop(context);
          await eliminarEvento(parentContext, ref, e);
        },
        style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.5))),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Eliminar'),
      ),
      children: [
        fila(Icons.calendar_today_rounded, '${fechaConDia(e.fecha)} ${parseYmd(e.fecha).year} · ${fechaRelativa(e.fecha)}'),
        fila(Icons.schedule_rounded, e.hora == null ? 'Todo el día' : hora12(e.hora)),
        if (e.ubicacion.isNotEmpty) fila(Icons.place_rounded, e.ubicacion),
        fila(Icons.repeat_rounded, 'Se repite: ${frecuenciaLabel(e.frecuencia)}'),
        if (esTx)
          fila(
            e.tipoTransaccion == 'ingreso' ? Icons.north_east_rounded : Icons.south_east_rounded,
            '${e.tipoTransaccion == 'ingreso' ? 'Ingreso' : 'Gasto'} de ${cop(e.costo)} · ${e.estadoPago == 'pagado' ? 'Pagado' : 'Pendiente'}',
            color: e.tipoTransaccion == 'ingreso' ? p.success : p.danger,
          ),
        if (e.tarjetaCreditoId != null) fila(Icons.credit_card_rounded, 'Cobro generado por una compra con tarjeta'),
        if (e.notas.isNotEmpty) fila(Icons.notes_rounded, e.notas),
        if (esTx) ...[
          const VGap.sm(),
          OutlinedButton.icon(
            onPressed: () {
              final toaster = Toaster.of(context);
              ref.read(eventsRepoProvider).alternarPago(e);
              Navigator.pop(context);
              toaster.show(e.estadoPago == 'pagado' ? 'Marcado como pendiente' : 'Marcado como pagado');
            },
            icon: Icon(e.estadoPago == 'pagado' ? Icons.undo_rounded : Icons.check_circle_rounded),
            label: Text(e.estadoPago == 'pagado' ? 'Marcar como pendiente' : 'Marcar como pagado'),
          ),
        ],
        const VGap.lg(),
        // Vista previa del recordatorio de WhatsApp (como el simulador web).
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withValues(alpha: context.isDark ? 0.1 : 0.08),
            borderRadius: Radii.rLg,
            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: IconSizes.md),
                const HGap.xs(),
                Text('Recordatorio de WhatsApp', style: context.text.titleSmall),
              ]),
              const VGap.sm(),
              Text(mensaje, style: context.text.bodyMedium),
              const VGap.sm(),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await copiar(mensaje);
                      if (context.mounted) toast(context, 'Mensaje copiado', icon: Icons.content_copy_rounded);
                    },
                    icon: const Icon(Icons.content_copy_rounded, size: IconSizes.md),
                    label: const Text('Copiar'),
                  ),
                ),
                const HGap.sm(),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => abrirWhatsApp(mensaje),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: const Color(0xFF052E16), minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.send_rounded, size: IconSizes.md),
                    label: const Text('Enviar'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Tile de cumpleaños ───────────────────────────

class BirthdayTile extends ConsumerWidget {
  const BirthdayTile({super.key, required this.cumple, required this.anio});
  final Cumple cumple;
  final int anio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final c = cumple;
    final edad = c.anioNacimiento == null ? null : anio - c.anioNacimiento!;
    const rosa = Color(0xFFF472B6);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.xxs, Gap.sm),
      color: Color.alphaBlend(rosa.withValues(alpha: 0.07), p.surface),
      borderColor: rosa.withValues(alpha: 0.3),
      child: Row(
        children: [
          const IconBadge(Icons.cake_rounded, color: rosa, size: 44),
          const HGap.sm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nombre, style: context.text.titleSmall),
                Text(edad != null ? 'Cumple $edad años' : 'Cumpleaños', style: context.text.bodySmall),
                if (c.mensaje.isNotEmpty)
                  Text('"${c.mensaje}"', style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Felicitar por WhatsApp',
            onPressed: () => abrirWhatsApp(mensajeCumple(c), telefono: c.telefono),
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
          ),
          PopupMenuButton<int>(
            tooltip: 'Más opciones',
            icon: Icon(Icons.more_vert_rounded, color: p.textSecondary),
            onSelected: (i) {
              if (i == 0) abrirFormularioEvento(context, cumple: c, fecha: '$anio${c.fecha.substring(4)}');
              if (i == 1) eliminarCumple(context, ref, c);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Editar'))),
              PopupMenuItem(
                value: 1,
                child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: p.danger), title: Text('Eliminar', style: TextStyle(color: p.danger))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
