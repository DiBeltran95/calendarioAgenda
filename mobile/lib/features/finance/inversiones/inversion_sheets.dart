import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../sheets/finance_sheets.dart' show cuentaDropdown;
import 'inversiones_logica.dart';
import 'inversiones_repository.dart';

/// Guarda, cierra la hoja y avisa; si el servidor rechaza, deja la hoja abierta.
Future<void> guardarYCerrar(BuildContext context, Future<void> Function() op, {required String aviso}) async {
  final nav = Navigator.of(context);
  final toaster = Toaster.of(context);
  try {
    await op();
    HapticFeedback.mediumImpact();
    nav.pop();
    toaster.show(aviso, icon: Icons.check_circle_rounded);
  } on FinanzasError catch (e) {
    toaster.show(e.mensaje, error: true);
  } catch (_) {
    toaster.show('No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.', error: true);
  }
}

/// Avisa si lo que sale de la cuenta es más de lo que tiene (no lo impide: las
/// transferencias tampoco, y la persona puede estar poniéndose al día).
class AvisoSaldo extends StatelessWidget {
  const AvisoSaldo({super.key, required this.cuentas, required this.cuentaId, required this.monto});
  final List<Cuenta> cuentas;
  final int? cuentaId;
  final double monto;

  @override
  Widget build(BuildContext context) {
    final c = cuentas.where((x) => x.id == cuentaId).firstOrNull;
    if (c == null || esCredito(c.tipo) || monto <= c.saldo) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Text('${c.nombre} tiene ${cop(c.saldo)}: quedará en negativo.', style: context.text.bodySmall?.copyWith(color: context.palette.warning)),
    );
  }
}

// ─────────────────────────── Nueva inversión / editar ───────────────────────────

class InversionSheet extends ConsumerStatefulWidget {
  const InversionSheet({super.key, this.inversion, this.tipoInicial});

  /// Si viene, se editan sus datos; el dinero se corrige en sus movimientos.
  final Inversion? inversion;

  /// Si viene, se abre directo para ese tipo, sin preguntar en qué invierte.
  final String? tipoInicial;

  @override
  ConsumerState<InversionSheet> createState() => _InversionSheetState();
}

class _InversionSheetState extends ConsumerState<InversionSheet> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inversion?.nombre ?? '');
  late final _nota = TextEditingController(text: widget.inversion?.nota ?? '');
  final _monto = TextEditingController();
  final _dolares = TextEditingController();
  late String _tipo = widget.inversion?.tipo ?? widget.tipoInicial ?? 'ganado';
  String _fecha = hoyYmd();
  int? _cuenta;

  bool get _editando => widget.inversion != null;
  bool get _esDolares => _tipo == 'dolares';

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
    _dolares.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _nota.dispose();
    _monto.dispose();
    _dolares.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(inversionesRepoProvider);
    if (_editando) {
      return guardarYCerrar(context, () => repo.actualizar(widget.inversion!.id, nombre: _nombre.text, tipo: _tipo, nota: _nota.text), aviso: 'Inversión actualizada');
    }
    return guardarYCerrar(
      context,
      () => repo.crear(nombre: _nombre.text, tipo: _tipo, monto: parseMonto(_monto.text), montoUsd: _esDolares ? parseDecimal(_dolares.text) : null, fecha: _fecha, cuentaId: _cuenta, nota: _nota.text),
      aviso: _esDolares ? 'Compra de dólares registrada' : 'Inversión registrada',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final tipo = tipoInversion(_tipo);
    final dolares = parseDecimal(_dolares.text);
    final pesos = parseMonto(_monto.text);
    return SheetScaffold(
      title: _editando ? 'Editar inversión' : (_esDolares ? 'Comprar dólares' : 'Nueva inversión'),
      subtitle: _editando ? null : (_esDolares ? 'Queda cuántos dólares compraste, cuánto pagaste y cuándo' : 'Queda registrada la fecha, el monto y de dónde salió el dinero'),
      icon: tipo.icono,
      primaryLabel: _editando ? 'Guardar cambios' : (_esDolares ? 'Registrar compra' : 'Registrar inversión'),
      onPrimary: _enviar,
      hayCambios: () => _editando
          ? _nombre.text != widget.inversion!.nombre || _nota.text != widget.inversion!.nota
          : _nombre.text.isNotEmpty || _monto.text.isNotEmpty || _nota.text.isNotEmpty,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Una inversión en dólares no se convierte en otra: sus movimientos son en dólares.
              if (widget.tipoInicial == null && !(_editando && _esDolares)) ...[
                const FieldLabel('¿En qué inviertes?'),
                ChoiceChips<String>(
                  options: [
                    for (final t in tiposInversion)
                      if (!_editando || t.valor != 'dolares') (t.valor, t.etiqueta),
                  ],
                  value: _tipo,
                  onChanged: (v) => setState(() => _tipo = v),
                ),
                const VGap.md(),
              ],
              FieldLabel(_esDolares ? '¿Dónde los tienes?' : 'Nombre', required: true),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: InputDecoration(hintText: tipo.ejemplo, counterText: ''),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe un nombre para la inversión' : null,
              ),
              if (!_editando) ...[
                if (_esDolares) ...[
                  const VGap.md(),
                  const FieldLabel('¿Cuántos dólares compraste?', required: true),
                  DolaresField(controller: _dolares, big: true, validator: (v) => v <= 0 ? 'Escribe cuántos dólares' : null),
                ],
                const VGap.md(),
                FieldLabel(_esDolares ? '¿Cuánto pagaste en pesos?' : '¿Cuánto invertiste?', required: true),
                MoneyField(controller: _monto, big: !_esDolares, validator: (v) => v <= 0 ? (_esDolares ? 'Escribe cuánto pagaste' : 'Escribe el monto invertido') : null),
                if (_esDolares && dolares > 0 && pesos > 0) ...[
                  const VGap.xs(),
                  Text('El dólar te salió a ${cop(pesos / dolares)}.', style: context.text.bodySmall),
                ],
                const VGap.md(),
                DateField(value: _fecha, last: DateTime.now(), label: '¿Cuándo?', onChanged: (v) => setState(() => _fecha = v)),
                const VGap.md(),
                const FieldLabel('¿De dónde salió el dinero?'),
                cuentaDropdown(cuentas: cuentas, value: _cuenta, nula: 'De ninguna cuenta (ya lo tenía)', onChanged: (v) => setState(() => _cuenta = v)),
                AvisoSaldo(cuentas: cuentas, cuentaId: _cuenta, monto: parseMonto(_monto.text)),
                const VGap.xs(),
                Text('No cuenta como gasto del mes: el dinero sigue siendo parte de tu patrimonio.', style: context.text.bodySmall),
              ],
              const VGap.md(),
              const FieldLabel('Nota'),
              TextFormField(controller: _nota, maxLength: 300, maxLines: 2, minLines: 1, decoration: const InputDecoration(hintText: 'Opcional', counterText: '')),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Movimiento ───────────────────────────

class MovimientoSheet extends ConsumerStatefulWidget {
  const MovimientoSheet({super.key, required this.inversion, required this.tipo, this.movimiento});
  final Inversion inversion;
  final TipoMovimiento tipo;

  /// Si viene, se corrige este movimiento.
  final MovimientoInversion? movimiento;

  @override
  ConsumerState<MovimientoSheet> createState() => _MovimientoSheetState();
}

class _MovimientoSheetState extends ConsumerState<MovimientoSheet> {
  final _form = GlobalKey<FormState>();
  late final _monto = TextEditingController(text: _montoParaCampo());
  late final _nota = TextEditingController(text: widget.movimiento?.nota ?? '');
  late String _fecha = widget.movimiento?.fecha ?? hoyYmd();
  late int? _cuenta = widget.movimiento?.cuentaId;
  late final _dolares = TextEditingController(text: decimalInicial(_dolaresIniciales));
  late final _inicial = '${_monto.text}|${_dolares.text}|${_nota.text}';

  bool get _editando => widget.movimiento != null;
  bool get _aporte => widget.tipo == TipoMovimiento.aporte;
  bool get _valoracion => widget.tipo == TipoMovimiento.valoracion;
  bool get _esDolares => widget.inversion.esDolares;

  /// Al actualizar o vender todo se parte de lo que hay hoy.
  double get _dolaresIniciales {
    if (widget.movimiento != null) return widget.movimiento!.montoUsd ?? 0;
    return widget.tipo == TipoMovimiento.valoracion || widget.tipo == TipoMovimiento.venta ? widget.inversion.usd : 0;
  }

  /// Al actualizar el saldo en dólares se pregunta a cuánto está el dólar, no los pesos.
  bool get _pideDolar => _esDolares && _valoracion;

  String _montoParaCampo() {
    final m = widget.movimiento;
    if (!_pideDolar) return montoInicial(m?.monto ?? 0);
    final usd = m?.montoUsd ?? 0;
    final tasa = m != null && usd > 0 ? m.monto / usd : (widget.inversion.tasaActual ?? 0);
    return montoInicial(tasa);
  }

  double get _montoEnPesos => _pideDolar ? parseDecimal(_dolares.text) * parseMonto(_monto.text) : parseMonto(_monto.text);

  @override
  void initState() {
    super.initState();
    _inicial;
    _monto.addListener(() => setState(() {}));
    _dolares.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    _dolares.dispose();
    super.dispose();
  }

  (String, String, IconData) get _textos => _esDolares
      ? switch (widget.tipo) {
          TipoMovimiento.aporte => ('Comprar dólares', '¿Cuánto pagaste en pesos?', Icons.add_rounded),
          TipoMovimiento.retiro => ('Vender dólares', '¿Cuánto recibiste en pesos?', Icons.sell_rounded),
          TipoMovimiento.venta => ('Vender todo', '¿Cuánto recibiste en pesos?', Icons.sell_rounded),
          TipoMovimiento.valoracion => ('Actualizar saldo', '¿A cuánto está el dólar?', Icons.trending_up_rounded),
        }
      : switch (widget.tipo) {
        TipoMovimiento.aporte => ('Agregar dinero', '¿Cuánto agregaste?', Icons.add_rounded),
        TipoMovimiento.retiro => ('Vender una parte', '¿Cuánto recibiste?', Icons.sell_rounded),
        TipoMovimiento.venta => ('Vender todo', '¿Cuánto recibiste?', Icons.sell_rounded),
        TipoMovimiento.valoracion => ('Actualizar valor', '¿Cuánto vale hoy?', Icons.trending_up_rounded),
      };

  Future<void> _enviar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(inversionesRepoProvider);
    final monto = _montoEnPesos;
    final dolares = _esDolares ? parseDecimal(_dolares.text) : null;
    return guardarYCerrar(
      context,
      () => _editando
          ? repo.actualizarMovimiento(widget.movimiento!.id, tipo: widget.tipo, monto: monto, montoUsd: dolares, fecha: _fecha, cuentaId: _valoracion ? null : _cuenta, nota: _nota.text)
          : repo.agregarMovimiento(widget.inversion.id, tipo: widget.tipo, monto: monto, montoUsd: dolares, fecha: _fecha, cuentaId: _valoracion ? null : _cuenta, nota: _nota.text),
      aviso: _editando ? 'Movimiento corregido' : 'Movimiento registrado',
    );
  }

  Future<void> _eliminar() async {
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    final si = await confirmar(
      context,
      titulo: '¿Eliminar este movimiento?',
      mensaje: _valoracion ? 'El valor de la inversión vuelve a calcularse sin él.' : 'Si movió dinero de una cuenta, ese saldo vuelve a como estaba.',
      confirmar: 'Eliminar',
      destructivo: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!si) return;
    try {
      await ref.read(inversionesRepoProvider).eliminarMovimiento(widget.movimiento!.id);
      nav.pop();
      toaster.show('Movimiento eliminado', icon: Icons.delete_outline_rounded);
    } on FinanzasError catch (e) {
      toaster.show(e.mensaje, error: true);
    } catch (_) {
      toaster.show('No se pudo eliminar. Revisa tu conexión.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final (titulo, pregunta, icono) = _textos;
    return SheetScaffold(
      title: titulo,
      subtitle: widget.inversion.nombre,
      icon: icono,
      primaryLabel: _editando ? 'Guardar cambios' : 'Registrar',
      onPrimary: _enviar,
      hayCambios: () => '${_monto.text}|${_dolares.text}|${_nota.text}' != _inicial,
      headerAction: _editando ? IconButton(tooltip: 'Eliminar movimiento', onPressed: _eliminar, icon: Icon(Icons.delete_outline_rounded, color: p.danger)) : null,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_esDolares) ...[
                FieldLabel(
                  switch (widget.tipo) {
                    TipoMovimiento.aporte => '¿Cuántos dólares compraste?',
                    TipoMovimiento.valoracion => '¿Cuántos dólares tienes hoy?',
                    _ => '¿Cuántos dólares vendiste?',
                  },
                  required: true,
                ),
                DolaresField(controller: _dolares, big: true, validator: (v) => v <= 0 && !_valoracion && widget.tipo != TipoMovimiento.venta ? 'Escribe cuántos dólares' : null),
                const VGap.md(),
              ],
              FieldLabel(pregunta, required: true),
              MoneyField(controller: _monto, big: !_esDolares, validator: _valoracion && !_esDolares ? null : (v) => v <= 0 ? 'Escribe el monto' : null),
              if (_pideDolar && _montoEnPesos > 0) ...[
                const VGap.xs(),
                Text('Hoy equivalen a ${cop(_montoEnPesos)}.', style: context.text.bodySmall),
              ],
              const VGap.md(),
              DateField(value: _fecha, last: DateTime.now(), label: '¿Cuándo?', onChanged: (v) => setState(() => _fecha = v)),
              if (!_valoracion) ...[
                const VGap.md(),
                FieldLabel(_aporte ? '¿De dónde salió el dinero?' : '¿A dónde llegó el dinero?'),
                cuentaDropdown(
                  cuentas: cuentas,
                  value: _cuenta,
                  nula: _aporte ? 'De ninguna cuenta (ya lo tenía)' : 'A ninguna cuenta',
                  onChanged: (v) => setState(() => _cuenta = v),
                ),
                if (_aporte) AvisoSaldo(cuentas: cuentas, cuentaId: _cuenta, monto: parseMonto(_monto.text)),
              ] else ...[
                const VGap.xs(),
                Text('Cambia tu patrimonio, pero no mueve dinero de ninguna cuenta.', style: context.text.bodySmall),
              ],
              if (widget.tipo == TipoMovimiento.venta) ...[
                const VGap.xs(),
                Text('La inversión queda cerrada, con su ganancia o pérdida final.', style: context.text.bodySmall),
              ],
              const VGap.md(),
              const FieldLabel('Nota'),
              TextFormField(controller: _nota, maxLength: 300, maxLines: 2, minLines: 1, decoration: const InputDecoration(hintText: 'Opcional', counterText: '')),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Detalle ───────────────────────────

class InversionDetalleSheet extends ConsumerWidget {
  const InversionDetalleSheet({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final i = ref.watch(inversionesProvider).value?.where((x) => x.id == id).firstOrNull;
    if (i == null) return const SizedBox(height: 120);
    final t = tipoInversion(i.tipo);
    final g = i.ganancia;

    void abrir(TipoMovimiento tipo, [MovimientoInversion? m]) => showAppSheet(context, (_) => MovimientoSheet(inversion: i, tipo: tipo, movimiento: m));

    Future<void> eliminar() async {
      final nav = Navigator.of(context);
      final toaster = Toaster.of(context);
      final si = await confirmar(
        context,
        titulo: '¿Eliminar "${i.nombre}"?',
        mensaje: 'Se borra su historial y las cuentas vuelven a como estaban antes de estos movimientos. No se puede deshacer.',
        confirmar: 'Eliminar',
        destructivo: true,
        icon: Icons.delete_outline_rounded,
      );
      if (!si) return;
      try {
        await ref.read(inversionesRepoProvider).eliminar(i.id);
        nav.pop();
        toaster.show('Inversión eliminada', icon: Icons.delete_outline_rounded);
      } on FinanzasError catch (e) {
        toaster.show(e.mensaje, error: true);
      } catch (_) {
        toaster.show('No se pudo eliminar. Revisa tu conexión.', error: true);
      }
    }

    Widget dato(String etiqueta, String valor, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: context.text.titleMedium?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ]),
        );

    return SheetScaffold(
      title: i.nombre,
      subtitle: i.vendida ? '${t.etiqueta} · Vendida' : t.etiqueta,
      icon: t.icono,
      primaryLabel: i.vendida ? null : (i.esDolares ? 'Comprar dólares' : 'Agregar dinero'),
      onPrimary: i.vendida ? null : () => abrir(TipoMovimiento.aporte),
      headerAction: PopupMenuButton<VoidCallback>(
        tooltip: 'Más opciones',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (f) => f(),
        itemBuilder: (_) => [
          PopupMenuItem(value: () => showAppSheet(context, (_) => InversionSheet(inversion: i)), child: const Text('Editar')),
          PopupMenuItem(value: eliminar, child: Text('Eliminar', style: TextStyle(color: p.danger))),
        ],
      ),
      children: [
        if (i.esDolares && !i.vendida) ...[
          Row(children: [
            dato('Tienes', usd(i.usd)),
            const HGap.sm(),
            dato('Dólares comprados', usd(i.usdComprados)),
          ]),
          const VGap.md(),
        ],
        Row(children: [
          dato(i.vendida ? 'Recibido' : 'Vale hoy', cop(i.vendida ? i.recibido : i.valor)),
          const HGap.sm(),
          dato(i.esDolares ? 'Pagaste' : 'Invertido', cop(i.invertido)),
        ]),
        const VGap.md(),
        if (i.esDolares && i.dolarPromedio != null) ...[
          Row(children: [
            dato('Dólar promedio', cop(i.dolarPromedio!)),
            const HGap.sm(),
            dato('Último dólar', cop(i.tasaActual ?? 0)),
          ]),
          const VGap.md(),
        ],
        Row(children: [
          dato(g >= 0 ? 'Ganancia' : 'Pérdida', copConSigno(g), color: g >= 0 ? p.success : p.danger),
          const HGap.sm(),
          dato('Desde', i.desde == null ? '—' : '${fechaCorta(i.desde!)} ${parseYmd(i.desde!).year}'),
        ]),
        if (i.nota.isNotEmpty) ...[
          const VGap.md(),
          Text(i.nota, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
        ],
        if (!i.vendida) ...[
          const VGap.lg(),
          Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
            OutlinedButton.icon(onPressed: () => abrir(TipoMovimiento.valoracion), icon: const Icon(Icons.trending_up_rounded, size: IconSizes.md), label: Text(i.esDolares ? 'Actualizar saldo' : 'Actualizar valor')),
            OutlinedButton.icon(onPressed: () => abrir(TipoMovimiento.retiro), icon: const Icon(Icons.sell_outlined, size: IconSizes.md), label: Text(i.esDolares ? 'Vender dólares' : 'Vender una parte')),
            OutlinedButton.icon(onPressed: () => abrir(TipoMovimiento.venta), icon: const Icon(Icons.sell_rounded, size: IconSizes.md), label: const Text('Vender todo')),
          ]),
        ],
        const VGap.lg(),
        const SectionHeader('Historial'),
        for (final m in i.movimientos.reversed) _FilaMovimiento(movimiento: m, dolares: i.esDolares, onTap: () => abrir(m.tipo, m)),
      ],
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento, required this.onTap, this.dolares = false});
  final MovimientoInversion movimiento;
  final VoidCallback onTap;
  final bool dolares;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = movimiento;
    final (icono, color) = switch (m.tipo) {
      TipoMovimiento.aporte => (Icons.south_west_rounded, p.accent),
      TipoMovimiento.retiro || TipoMovimiento.venta => (Icons.north_east_rounded, p.success),
      TipoMovimiento.valoracion => (Icons.trending_up_rounded, p.info),
    };
    final cuenta = m.tipo == TipoMovimiento.valoracion
        ? null
        : m.cuentaId == null
            ? 'Sin cuenta'
            : (m.cuentaNombre ?? 'Cuenta eliminada');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: IconBadge(icono, color: color, size: 40),
      title: Text(
        dolares
            ? switch (m.tipo) {
                TipoMovimiento.aporte => 'Compra de dólares',
                TipoMovimiento.retiro => 'Venta de dólares',
                TipoMovimiento.venta => 'Venta total',
                TipoMovimiento.valoracion => 'Saldo actualizado',
              }
            : m.tipo.etiqueta,
        style: context.text.titleSmall,
      ),
      subtitle: Text(
        ['${fechaCorta(m.fecha)} ${parseYmd(m.fecha).year}', if (dolares && m.montoUsd != null) cop(m.monto), ?cuenta, if (m.nota.isNotEmpty) m.nota].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall,
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(dolares && m.montoUsd != null ? usd(m.montoUsd!) : cop(m.monto), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ),
    );
  }
}
