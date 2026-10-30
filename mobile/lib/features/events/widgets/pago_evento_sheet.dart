import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/net/api_exception.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../../../data/models.dart';
import '../../finance/finance_logic.dart';
import '../../finance/finance_providers.dart';
import '../../finance/pagos/pagos_logica.dart';
import '../../finance/pagos/pagos_repository.dart';
import '../../finance/sheets/finance_sheets.dart' show cuentaDropdown;
import '../events_repository.dart';

String _mensajeError(Object e) => e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.';

/// Lo que pasa al tocar la casilla de pago de un evento:
///  * pendiente: pregunta de dónde salió el dinero (sin cuentas, solo se marca);
///  * pagado: vuelve a pendiente y deshace lo que ese pago movió.
///
/// [context] debe seguir montado después de cerrar la hoja que lo llama.
Future<void> gestionarPagoEvento(BuildContext context, Evento e) async {
  final c = ProviderScope.containerOf(context, listen: false);
  final toaster = Toaster.of(context);
  final repo = c.read(eventsRepoProvider);
  try {
    if (e.pagado) {
      final si = await confirmar(
        context,
        titulo: '¿Marcar como pendiente?',
        mensaje: 'Si este pago movió dinero de una cuenta, el saldo vuelve a como estaba.',
        confirmar: 'Marcar pendiente',
        icon: Icons.undo_rounded,
      );
      if (!si) return;
      final devolvio = await repo.quitarPago(e);
      toaster.show(devolvio ? 'Pago deshecho: los saldos volvieron a como estaban' : 'Marcado como pendiente', icon: Icons.undo_rounded);
      return;
    }
    final cuentas = c.read(cuentasProvider).value ?? const <Cuenta>[];
    if (cuentas.isEmpty) {
      await repo.alternarPago(e);
      toaster.show('Marcado como pagado', icon: Icons.check_circle_rounded);
      return;
    }
    if (context.mounted) await showAppSheet<void>(context, (_) => PagoEventoSheet(evento: e));
  } catch (err) {
    toaster.show(_mensajeError(err), error: true);
  }
}

/// Confirmar un pago: cuánto, cuándo y de qué cuenta salió el dinero.
class PagoEventoSheet extends ConsumerStatefulWidget {
  const PagoEventoSheet({super.key, required this.evento});
  final Evento evento;

  @override
  ConsumerState<PagoEventoSheet> createState() => _PagoEventoSheetState();
}

class _PagoEventoSheetState extends ConsumerState<PagoEventoSheet> {
  final _form = GlobalKey<FormState>();
  late final _monto = TextEditingController(text: montoInicial(widget.evento.costo));
  late final String _inicial = _monto.text;
  String _fecha = hoyYmd();
  int? _cuenta;
  String? _categoria;

  Evento get e => widget.evento;
  bool get _ingreso => e.tipoTransaccion == 'ingreso';

  /// La cuenta de la deuda, si esta es la cuota de una compra a crédito.
  Cuenta? _tarjeta(List<Cuenta> cuentas) => _ingreso ? null : cuentas.where((c) => c.id == e.tarjetaCreditoId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _inicial;
    _monto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  String _categoriaSugerida() {
    final pago = CapturaPago(id: 0, origen: '', tipo: 'gasto', monto: e.costo, comercio: e.titulo, tarjeta: '', app: '', fecha: DateTime.now());
    return sugerirCategoria(pago, ref.read(preferenciasPagosProvider).value ?? const [], ref.read(categoriasFinProvider).value ?? const []);
  }

  Future<void> _guardar({required bool moverDinero}) async {
    if (moverDinero && !validarFormulario(_form)) return;
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    try {
      await ref.read(eventsRepoProvider).pagar(
            e,
            cuentaId: moverDinero ? _cuenta : null,
            monto: parseMonto(_monto.text),
            fecha: _fecha,
            categoria: _categoria ?? _categoriaSugerida(),
          );
      HapticFeedback.mediumImpact();
      nav.pop();
      toaster.show(moverDinero ? 'Pago registrado' : 'Marcado como pagado', icon: Icons.check_circle_rounded);
    } catch (err) {
      toaster.show(_mensajeError(err), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final categorias = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final tarjeta = _tarjeta(cuentas);
    final monto = parseMonto(_monto.text);
    final elegida = cuentas.where((c) => c.id == _cuenta).firstOrNull;
    final sinSaldo = !_ingreso && elegida != null && !esCredito(elegida.tipo) && monto > elegida.saldo;

    return SheetScaffold(
      title: _ingreso ? 'Confirmar ingreso' : 'Confirmar pago',
      subtitle: e.titulo,
      icon: Icons.check_circle_rounded,
      primaryLabel: _ingreso ? 'Registrar ingreso' : 'Registrar pago',
      onPrimary: () => _guardar(moverDinero: true),
      hayCambios: () => _monto.text != _inicial,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(_ingreso ? '¿Cuánto recibiste?' : '¿Cuánto pagaste?', required: true),
              MoneyField(controller: _monto, big: true, validator: (v) => v <= 0 ? 'Escribe el monto' : null),
              const VGap.md(),
              DateField(value: _fecha, last: DateTime.now(), label: _ingreso ? '¿Cuándo lo recibiste?' : '¿Cuándo pagaste?', onChanged: (v) => setState(() => _fecha = v)),
              const VGap.md(),
              FieldLabel(_ingreso ? '¿A dónde llegó el dinero?' : '¿De dónde salió el dinero?', required: true),
              cuentaDropdown(
                cuentas: cuentas,
                value: _cuenta,
                permitirNula: false,
                excluir: tarjeta?.id,
                onChanged: (v) => setState(() => _cuenta = v),
                validator: (v) => v == null ? (_ingreso ? 'Elige a qué cuenta llegó' : 'Elige de qué cuenta salió') : null,
              ),
              if (sinSaldo)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Text('${elegida.nombre} tiene ${cop(elegida.saldo)}: quedará en negativo.', style: context.text.bodySmall?.copyWith(color: p.warning)),
                ),
              if (tarjeta != null) ...[
                const VGap.sm(),
                Container(
                  padding: const EdgeInsets.all(Gap.sm),
                  decoration: BoxDecoration(color: p.success.withValues(alpha: 0.10), borderRadius: Radii.rMd),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.trending_down_rounded, color: p.success, size: IconSizes.md),
                    const HGap.xs(),
                    Expanded(
                      child: Text(
                        'La deuda de ${tarjeta.nombre} baja ${cop(monto)} (queda en ${cop(tarjeta.saldo - monto < 0 ? 0 : tarjeta.saldo - monto)}). No cuenta como gasto nuevo: la compra ya se registró.',
                        style: context.text.bodySmall?.copyWith(color: p.text),
                      ),
                    ),
                  ]),
                ),
              ] else if (!_ingreso && categorias.isNotEmpty) ...[
                const VGap.md(),
                const FieldLabel('Categoría'),
                ChoiceChips<String>(
                  options: [for (final c in categorias) (c.valor, c.label)],
                  value: _categoria ?? _categoriaSugerida(),
                  onChanged: (v) => setState(() => _categoria = v),
                ),
              ],
              const VGap.sm(),
              TextButton(
                onPressed: () => _guardar(moverDinero: false),
                child: Text(tarjeta != null ? 'Solo marcar como pagado (la deuda no baja)' : 'Solo marcar como pagado, sin mover dinero', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
