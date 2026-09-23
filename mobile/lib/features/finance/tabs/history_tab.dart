import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../data/models.dart';
import '../../../core/icon_map.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../sheets/transaction_sheet.dart';

class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key, required this.mes, required this.dia, required this.txMes});
  final DateTime mes;
  final String? dia;
  final List<Transaccion> txMes;

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  String _filtro = 'todos';

  /// Filas quitadas al deslizar: se ocultan al instante, antes de que la base
  /// emita los cambios (un Dismissible descartado no puede reconstruirse).
  final _ocultos = <int>{};

  @override
  Widget build(BuildContext context) {
    final lista = widget.txMes
        .where((t) => widget.dia == null || t.fecha == widget.dia)
        .where((t) => _filtro == 'todos' || t.tipo == _filtro)
        .where((t) => !_ocultos.contains(t.id))
        .toList();
    final porDia = <String, List<Transaccion>>{};
    for (final t in lista) {
      (porDia[t.fecha] ??= []).add(t);
    }
    final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));
    var i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: Gap.xs, children: [
          for (final (k, l) in const [('todos', 'Todos'), ('gasto', 'Gastos'), ('ingreso', 'Ingresos')])
            ChoiceChip(label: Text(l), selected: _filtro == k, showCheckmark: false, onSelected: (_) => setState(() => _filtro = k)),
        ]),
        const VGap.md(),
        if (lista.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Sin movimientos',
            message: widget.dia == null ? 'No hay movimientos en este mes.' : 'No hay movimientos el ${fechaCorta(widget.dia!)}.',
            actionLabel: 'Registrar movimiento',
            onAction: () => abrirTransaccion(context, fecha: widget.dia ?? hoyYmd()),
          ),
        for (final d in dias) ...[
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.xs),
            child: Row(children: [
              Expanded(
                child: Text(
                  fechaConDia(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: context.palette.text, fontWeight: FontWeight.w600),
                ),
              ),
              const HGap.xs(),
              Text(
                copConSigno(porDia[d]!.fold(0.0, (s, t) => s + (t.tipo == 'ingreso' ? t.monto : -t.monto))),
                style: context.text.labelMedium,
              ),
            ]),
          ),
          for (final t in porDia[d]!)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Entrance(index: i++, child: TxTile(tx: t, onRemoved: () => setState(() => _ocultos.add(t.id)))),
            ),
        ],
      ],
    );
  }
}

/// Movimiento con desplazamiento lateral para borrar (con "Deshacer").
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, this.onRemoved});
  final Transaccion tx;
  final VoidCallback? onRemoved;

  /// Un cobro confirmado también deshace su verificación: se pide confirmación.
  Future<bool> _confirmar(BuildContext context) async {
    if (tx.ingresoPlanificadoId == null) return true;
    return confirmar(context,
        titulo: '¿Eliminar este cobro?',
        mensaje: 'También se deshará su confirmación en el planificador y se ajustará el saldo.',
        confirmar: 'Eliminar',
        destructivo: true);
  }

  Future<void> _borrar(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(financeRepoProvider);
    final toaster = Toaster.of(context);
    onRemoved?.call();
    await repo.eliminarTransaccion(tx);
    HapticFeedback.mediumImpact();
    if (tx.ingresoPlanificadoId != null) {
      toaster.show('Cobro eliminado', icon: Icons.delete_outline_rounded);
      return;
    }
    toaster.show('Movimiento eliminado y saldo revertido', icon: Icons.delete_outline_rounded, onUndo: () {
      repo.crearTransaccion(TransaccionInput.desde(tx));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cats = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final cat = cats.where((c) => c.valor == tx.categoria).firstOrNull;
    final cuenta = cuentas.where((c) => c.id == tx.cuentaId).firstOrNull;
    final ingreso = tx.tipo == 'ingreso';

    return Dismissible(
      key: ValueKey('tx-${tx.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmar(context),
      onDismissed: (_) => _borrar(context, ref),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gap.lg),
        decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.18), borderRadius: Radii.rLg),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Eliminar', style: context.text.labelLarge?.copyWith(color: p.danger)),
          const HGap.xs(),
          Icon(Icons.delete_outline_rounded, color: p.danger),
        ]),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(Gap.sm),
        onTap: () => abrirTransaccion(context, tx: tx),
        semanticLabel: '${tx.descripcion}, ${ingreso ? 'ingreso' : 'gasto'} de ${cop(tx.monto)}. Desliza para eliminar.',
        child: Row(
          children: [
            IconBadge(
              ingreso ? Icons.north_east_rounded : iconoPorNombre(cat?.icono),
              color: ingreso ? p.success : colorCategoria(tx.categoria),
              size: 40,
            ),
            const HGap.sm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.descripcion, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      if (!ingreso) cat?.label ?? tx.categoria,
                      cuenta?.nombre ?? 'Sin cuenta',
                      if (tx.cuotas > 1) '${tx.cuotas} cuotas',
                    ].join(' · '),
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${ingreso ? '+' : '-'}${cop(tx.monto)}',
              style: context.text.titleSmall?.copyWith(color: ingreso ? p.success : p.danger, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}
