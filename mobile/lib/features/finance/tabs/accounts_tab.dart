import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/db/database.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../sheets/finance_sheets.dart';

class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key, required this.cuentas, required this.mes});
  final List<Cuenta> cuentas;
  final DateTime mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transferenciasMesProvider((mes.year, mes.month))).value ?? const <Transferencia>[];
    final nombre = {for (final c in cuentas) c.id: c.nombre};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showAppSheet(context, (_) => const AccountSheet()),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Agregar cuenta'),
              ),
            ),
            if (cuentas.length >= 2) ...[
              const HGap.xs(),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showAppSheet(context, (_) => const TransferSheet()),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transferir'),
                ),
              ),
            ],
          ],
        ),
        const VGap.md(),
        if (cuentas.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_rounded,
            title: 'Aún no tienes cuentas',
            message: 'Agrega tus cuentas de ahorro, tarjetas, efectivo o inversiones para ver tus saldos siempre al día.',
          ),
        for (var i = 0; i < cuentas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Entrance(index: i, child: AccountCard(cuenta: cuentas[i])),
          ),
        if (transfers.isNotEmpty) ...[
          const VGap.sm(),
          SectionHeader('Transferencias de ${mesesLargos[mes.month - 1].toLowerCase()}', icon: Icons.swap_horiz_rounded),
          for (final t in transfers)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.xxs, Gap.xs),
                child: Row(
                  children: [
                    const IconBadge(Icons.swap_horiz_rounded, size: 38),
                    const HGap.sm(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${nombre[t.cuentaOrigenId] ?? '—'} → ${nombre[t.cuentaDestinoId] ?? '—'}', style: context.text.titleSmall),
                          Text([fechaCorta(t.fecha), if (t.descripcion.isNotEmpty) t.descripcion].join(' · '), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Text(cop(t.monto), style: context.text.titleSmall),
                    IconButton(
                      tooltip: 'Eliminar transferencia',
                      icon: Icon(Icons.delete_outline_rounded, color: context.palette.danger),
                      onPressed: () async {
                        final ok = await confirmar(
                          context,
                          titulo: '¿Eliminar transferencia?',
                          mensaje: 'Se revertirán los cambios en los saldos de ambas cuentas.',
                          confirmar: 'Eliminar',
                          destructivo: true,
                        );
                        if (ok) await ref.read(financeRepoProvider).eliminarTransferencia(t);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Tarjeta visual de una cuenta: degradado según el tipo, saldo animado y
/// métricas propias (cupo de tarjeta, rendimiento de CDT).
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key, required this.cuenta});
  final Cuenta cuenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cuenta;
    final t = tipoCuenta(c.tipo);
    const blanco = Colors.white;
    final suave = Colors.white.withValues(alpha: 0.78);
    final estilo = context.text;

    Widget metrica(String l, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: estilo.labelSmall?.copyWith(color: suave, letterSpacing: 0.2)),
            Text(v, style: estilo.titleSmall?.copyWith(color: blanco)),
          ]),
        );

    return Semantics(
      label: '${c.nombre}, ${t.label}, ${esCredito(c.tipo) ? 'deuda' : 'saldo'} ${cop(c.saldo)}',
      child: Pressable(
        scale: 0.98,
        onTap: () => showAppSheet(context, (_) => AccountSheet(cuenta: c)),
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.colors),
            borderRadius: Radii.rLg,
            boxShadow: [BoxShadow(color: t.colors.first.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(t.icon, color: blanco, size: IconSizes.lg),
                  const HGap.xs(),
                  Expanded(
                    child: Text(t.label.toUpperCase(), style: estilo.labelSmall?.copyWith(color: suave, letterSpacing: 1)),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Opciones de la cuenta',
                    iconColor: blanco,
                    onSelected: (i) async {
                      if (i == 0) showAppSheet(context, (_) => AccountSheet(cuenta: c));
                      if (i == 1) {
                        final ok = await confirmar(
                          context,
                          titulo: '¿Eliminar "${c.nombre}"?',
                          mensaje: 'Sus movimientos se conservan en el historial sin cuenta asociada y sus transferencias se eliminan.',
                          confirmar: 'Eliminar',
                          destructivo: true,
                        );
                        if (ok) await ref.read(financeRepoProvider).eliminarCuenta(c.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Editar'))),
                      PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Eliminar'))),
                    ],
                  ),
                ],
              ),
              Text(c.nombre, style: estilo.titleMedium?.copyWith(color: blanco)),
              const VGap.xs(),
              Text(esCredito(c.tipo) ? 'Deuda actual' : 'Saldo', style: estilo.labelSmall?.copyWith(color: suave)),
              AnimatedMoney(c.saldo, style: estilo.headlineMedium?.copyWith(color: blanco, fontWeight: FontWeight.w800)),
              if (esCredito(c.tipo) && c.limite > 0) ...[
                const VGap.sm(),
                ProgressBar(
                  value: c.saldo / c.limite,
                  color: c.saldo / c.limite > 0.5 ? const Color(0xFFFCA5A5) : blanco,
                  background: Colors.white.withValues(alpha: 0.2),
                  height: 6,
                ),
                const VGap.xs(),
                Row(children: [
                  metrica('Disponible', cop((c.limite - c.saldo).clamp(0, double.infinity))),
                  metrica('Cupo', cop(c.limite)),
                  metrica('Uso', '${(c.saldo / c.limite * 100).toStringAsFixed(0)}%'),
                ]),
              ],
              if (esCredito(c.tipo) && c.diaCorte != null) ...[
                const VGap.xs(),
                Text('Corte el día ${c.diaCorte} de cada mes', style: estilo.bodySmall?.copyWith(color: suave)),
              ],
              if (c.tipo == 'cdt') ...[
                const VGap.sm(),
                Row(children: [
                  metrica('Tasa E.A.', '${c.interesTasa}%'),
                  metrica('Rinde al día', cop(rendimientoDiarioCdt(c.saldo, c.interesTasa))),
                  if (c.plazoDias > 0) metrica('Al vencer', '+${cop(rendimientoTotalCdt(c.saldo, c.interesTasa, c.plazoDias))}'),
                ]),
                if (c.plazoDias > 0) ...[
                  const VGap.sm(),
                  ProgressBar(value: progresoCdt(c), color: blanco, background: Colors.white.withValues(alpha: 0.2), height: 6),
                  const SizedBox(height: 6),
                  Text(
                    diasRestantesCdt(c) == 0
                        ? 'Vencido el ${fechaLarga(fechaVencimiento(c)!)}'
                        : 'Vence el ${fechaLarga(fechaVencimiento(c)!)} · faltan ${diasRestantesCdt(c)} días',
                    style: estilo.bodySmall?.copyWith(color: suave),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Rendimiento continuo', style: estilo.bodySmall?.copyWith(color: suave)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
