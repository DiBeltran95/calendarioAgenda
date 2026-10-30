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
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';

Future<void> abrirTransaccion(
  BuildContext context, {
  Transaccion? tx,
  String? fecha,
  String tipo = 'gasto',
  String? categoria,
  String? descripcion,
  double? monto,
  int? cuentaId,
  void Function(int id, TransaccionInput input)? alCrear,
}) {
  return showAppSheet(
    context,
    (_) => TransactionSheet(tx: tx, fecha: fecha ?? hoyYmd(), tipo: tipo, categoria: categoria, descripcion: descripcion, monto: monto, cuentaId: cuentaId, alCrear: alCrear),
  );
}

/// Registrar / editar un ingreso o gasto. Con tarjeta de crédito permite
/// diferir a cuotas y muestra en vivo en qué fechas caerán los cobros.
class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({super.key, this.tx, required this.fecha, this.tipo = 'gasto', this.categoria, this.descripcion, this.monto, this.cuentaId, this.alCrear});

  final Transaccion? tx;
  final String fecha;
  final String tipo;
  final String? categoria;
  final String? descripcion;

  /// Valores iniciales (p. ej. un pago detectado de Apple Pay o del banco).
  final double? monto;
  final int? cuentaId;

  /// Se llama con el id del movimiento recién creado.
  final void Function(int id, TransaccionInput input)? alCrear;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  final _form = GlobalKey<FormState>();
  late String _tipo;
  late String _fecha;
  late String _categoria;
  int? _cuentaId;
  late int _cuotas;
  late final TextEditingController _monto;
  late final TextEditingController _desc;
  late final String _inicial;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tx;
    _tipo = t?.tipo ?? widget.tipo;
    _fecha = t?.fecha ?? widget.fecha;
    _categoria = t?.categoria ?? widget.categoria ?? 'otros';
    _cuentaId = t?.cuentaId ?? widget.cuentaId;
    _cuotas = t?.cuotas ?? 1;
    _monto = TextEditingController(text: montoInicial(t?.monto ?? widget.monto ?? 0));
    _desc = TextEditingController(text: t?.descripcion ?? widget.descripcion ?? '');
    _inicial = '${_monto.text}|${_desc.text}';
    // La vista previa de cuotas depende del monto: se recalcula al escribir.
    _monto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!validarFormulario(_form)) return;
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    setState(() => _guardando = true);
    final cuentas = ref.read(cuentasProvider).value ?? const <Cuenta>[];
    final cuenta = cuentas.where((c) => c.id == _cuentaId).firstOrNull;
    final esTarjeta = cuenta != null && esCredito(cuenta.tipo) && _tipo == 'gasto';
    final input = TransaccionInput(
      tipo: _tipo,
      monto: parseMonto(_monto.text),
      descripcion: _desc.text,
      fecha: _fecha,
      cuentaId: _cuentaId,
      categoria: _tipo == 'gasto' ? _categoria : (_categoria.isEmpty ? 'otros' : _categoria),
      cuotas: esTarjeta ? _cuotas : 1,
    );
    try {
      final repo = ref.read(financeRepoProvider);
      if (widget.tx == null) {
        final id = await repo.crearTransaccion(input);
        widget.alCrear?.call(id, input);
      } else {
        await repo.actualizarTransaccion(widget.tx!, input);
      }
      HapticFeedback.mediumImpact();
      nav.pop();
      toaster.show(
        widget.tx != null
            ? 'Movimiento actualizado'
            : esTarjeta
                ? 'Compra registrada · ${_cuotas == 1 ? 'cobro agendado' : '$_cuotas cuotas agendadas'} en Eventos'
                : (_tipo == 'gasto' ? 'Gasto registrado' : 'Ingreso registrado'),
        icon: esTarjeta ? Icons.credit_card_rounded : Icons.check_circle_rounded,
      );
    } on FinanzasError catch (e) {
      setState(() => _guardando = false);
      toaster.show(e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final categorias = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final cuenta = cuentas.where((c) => c.id == _cuentaId).firstOrNull;
    final esTarjeta = cuenta != null && esCredito(cuenta.tipo) && _tipo == 'gasto';
    final monto = parseMonto(_monto.text);
    final cobros = esTarjeta && monto > 0
        ? cobrosTarjeta(fechaCompra: _fecha, monto: monto, cuotas: _cuotas, diaCorte: cuenta.diaCorte)
        : const <(String, double)>[];

    return SheetScaffold(
      title: widget.tx == null ? 'Nuevo movimiento' : 'Editar movimiento',
      subtitle: fechaConDia(_fecha),
      icon: _tipo == 'gasto' ? Icons.south_east_rounded : Icons.north_east_rounded,
      primaryLabel: widget.tx == null ? (_tipo == 'gasto' ? 'Registrar gasto' : 'Registrar ingreso') : 'Guardar cambios',
      busy: _guardando,
      onPrimary: _guardar,
      hayCambios: () => '${_monto.text}|${_desc.text}' != _inicial,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedPill<String>(
                options: const [('gasto', 'Gasto', Icons.south_east_rounded), ('ingreso', 'Ingreso', Icons.north_east_rounded)],
                colors: {'gasto': p.danger, 'ingreso': p.success},
                value: _tipo,
                onChanged: (v) => setState(() => _tipo = v),
              ),
              const FieldLabel('Monto', required: true),
              MoneyField(
                controller: _monto,
                big: true,
                autofocus: widget.tx == null,
                validator: (v) => v <= 0 ? 'Ingresa un monto mayor a 0' : null,
              ),
              const FieldLabel('Descripción', required: true),
              TextFormField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _tipo == 'gasto' ? 'Ej. Mercado del mes' : 'Ej. Pago de cliente',
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe una descripción' : null,
              ),
              const FieldLabel('Fecha'),
              DateField(value: _fecha, onChanged: (v) => setState(() => _fecha = v)),
              const FieldLabel('Cuenta'),
              DropdownButtonFormField<int?>(
                initialValue: cuentas.any((c) => c.id == _cuentaId) ? _cuentaId : null,
                isExpanded: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_wallet_rounded)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ninguna (solo registrar)')),
                  for (final c in cuentas)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.nombre} · ${esCredito(c.tipo) ? 'deuda ' : ''}${cop(c.saldo)}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _cuentaId = v),
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: !esTarjeta
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('Cuotas'),
                          StepperField(
                            value: _cuotas,
                            min: 1,
                            max: 48,
                            suffix: _cuotas == 1 ? ' cuota' : ' cuotas',
                            onChanged: (v) => setState(() => _cuotas = v),
                          ),
                          if (cobros.isNotEmpty) ...[
                            const VGap.sm(),
                            Container(
                              padding: const EdgeInsets.all(Gap.sm),
                              decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.event_repeat_rounded, size: IconSizes.sm, color: p.accent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        cuenta.diaCorte != null ? 'Cobros según el corte (día ${cuenta.diaCorte})' : 'Cobros mensuales desde el mes siguiente',
                                        style: context.text.labelMedium,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  for (final (f, m) in cobros.take(4))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(children: [
                                        Expanded(child: Text(fechaLarga(f), style: context.text.bodySmall)),
                                        Text(cop(m), style: context.text.bodySmall?.copyWith(color: p.text, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                  if (cobros.length > 4) Text('… y ${cobros.length - 4} más', style: context.text.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const FieldLabel('Categoría'),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final c in categorias)
                    ChoiceChip(
                      avatar: Icon(iconoPorNombre(c.icono), size: IconSizes.sm, color: c.valor == _categoria ? colorCategoria(context, c.valor) : p.textSecondary),
                      label: Text(c.label),
                      selected: c.valor == _categoria,
                      showCheckmark: false,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _categoria = c.valor);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
