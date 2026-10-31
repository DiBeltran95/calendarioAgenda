import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/esqueleto.dart';
import '../../../core/widgets/fab_animado.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../../../core/widgets/vista_async.dart';
import '../../../data/models.dart';
import '../../../data/sync.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import 'inversion_sheets.dart';
import 'inversiones_logica.dart';
import 'inversiones_repository.dart';
import '../prestamos/prestamos_repository.dart';

/// Patrimonio completo (cuentas + inversiones − deudas) y las inversiones.
class InversionesScreen extends ConsumerWidget {
  const InversionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLista = ref.watch(inversionesProvider);
    Future<void> refrescar() async {
      await Future.wait([
        ref.read(inversionesProvider.notifier).refrescar(),
        ref.read(sincronizadorProvider).despuesDeCambio(meses: false),
      ]);
    }

    return Scaffold(
      appBar: barraPantalla(context, 'Inversiones'),
      floatingActionButton: FabAnimado(
        heroTag: 'fab-inversiones',
        icono: Icons.add_rounded,
        etiqueta: 'Nueva inversión',
        onPressed: () => showAppSheet(context, (_) => const InversionSheet()),
      ),
      body: RefreshIndicator(
        onRefresh: refrescar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Entrance(child: _HeroPatrimonio()),
                    const VGap.lg(),
                    VistaAsync<List<Inversion>>(
                      valor: asyncLista,
                      onReintentar: refrescar,
                      esqueleto: const EsqueletoLista(alturas: [96, 96]),
                      datos: (lista) => _Lista(lista: lista),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuánto tienes en total y de qué está hecho.
class _HeroPatrimonio extends ConsumerWidget {
  const _HeroPatrimonio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final inversiones = ref.watch(valorInversionesProvider);
    final r = ResumenFinanciero(cuentas: cuentas, txMes: const [], inversiones: inversiones, porCobrar: ref.watch(porCobrarProvider));
    final suave = p.onAccent.withValues(alpha: 0.86);

    Widget fila(IconData icono, String etiqueta, String valor) => Padding(
          padding: const EdgeInsets.only(top: Gap.xs),
          child: Row(children: [
            Icon(icono, size: IconSizes.md, color: p.onAccent),
            const HGap.xs(),
            Expanded(child: Text(etiqueta, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: suave))),
            const HGap.xs(),
            // Los montos de una casa son largos: se reducen en vez de aplastar la etiqueta.
            Flexible(
              fit: FlexFit.tight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(valor, style: context.text.titleSmall?.copyWith(color: p.onAccent, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
          ]),
        );

    return TarjetaHeroe(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Patrimonio neto', style: context.text.labelLarge?.copyWith(color: suave)),
        const SizedBox(height: Gap.xxs),
        AnimatedMoney(r.patrimonio, style: context.text.displaySmall?.copyWith(color: p.onAccent)),
        const VGap.sm(),
        fila(Icons.account_balance_wallet_rounded, 'Cuentas y ahorros', cop(r.ahorros)),
        fila(Icons.trending_up_rounded, 'Inversiones', cop(r.inversiones)),
        if (r.porCobrar > 0) fila(Icons.handshake_rounded, 'Préstamos por cobrar', cop(r.porCobrar)),
        fila(Icons.credit_card_rounded, 'Deuda de tarjetas', r.deudaTarjetas > 0 ? '- ${cop(r.deudaTarjetas)}' : cop(0)),
      ]),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.lista});
  final List<Inversion> lista;

  @override
  Widget build(BuildContext context) {
    final activas = lista.where((i) => !i.vendida).toList();
    final vendidas = lista.where((i) => i.vendida).toList();
    if (lista.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.trending_up_rounded,
          title: 'Registra tu primera inversión',
          message: 'Dólares, ganado, una casa, un vehículo, un negocio… Queda la fecha, el monto y de qué cuenta salió el dinero.',
          actionLabel: 'Nueva inversión',
          onAction: () => showAppSheet(context, (_) => const InversionSheet()),
        ),
      );
    }
    final invertido = activas.fold(0.0, (s, i) => s + i.invertido);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activas.isNotEmpty) ...[
          SectionHeader('Mis inversiones', subtitle: 'Invertido ${cop(invertido)} · Vale hoy ${cop(valorTotalInversiones(activas))}'),
          for (final (k, i) in activas.indexed) Entrance(index: k, child: _Tarjeta(inversion: i)),
        ],
        if (vendidas.isNotEmpty) ...[
          if (activas.isNotEmpty) const VGap.md(),
          const SectionHeader('Vendidas'),
          for (final (k, i) in vendidas.indexed) Entrance(index: k, child: _Tarjeta(inversion: i)),
        ],
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.inversion});
  final Inversion inversion;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final i = inversion;
    final t = tipoInversion(i.tipo);
    final g = i.ganancia;
    final color = g >= 0 ? p.success : p.danger;
    final porcentaje = i.rentabilidad;
    final resultado = '${copConSigno(g)}${porcentaje == null ? '' : ' (${porcentaje.toStringAsFixed(0)}%)'}';
    final desde = i.desde == null ? null : 'Desde ${fechaCorta(i.desde!)} ${parseYmd(i.desde!).year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: AppCard(
        onTap: () => showAppSheet(context, (_) => InversionDetalleSheet(id: i.id)),
        semanticLabel: '${i.nombre}, ${t.etiqueta}. ${i.vendida ? 'Vendida' : 'Vale ${cop(i.valor)}'}. Invertido ${cop(i.invertido)}. ${g >= 0 ? 'Ganancia' : 'Pérdida'} ${cop(g.abs())}.',
        child: Row(children: [
          IconBadge(t.icono, color: context.par(t.par), size: 48),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              Text(
                [t.etiqueta, if (i.esDolares && !i.vendida) '≈ ${cop(i.valor)}', ?desde].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
              const SizedBox(height: Gap.xxs),
              Wrap(spacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(i.esDolares && !i.vendida ? usd(i.usd) : cop(i.vendida ? i.recibido : i.valor), style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                Text(resultado, style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary),
        ]),
      ),
    );
  }
}
