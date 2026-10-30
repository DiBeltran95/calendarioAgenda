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
Future<void> _guardar(BuildContext context, Future<void> Function() op, {required String aviso}) async {
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
class _AvisoSaldo extends StatelessWidget {
  const _AvisoSaldo({required this.cuentas, required this.cuentaId, required this.monto});
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
  const InversionSheet({super.key, this.inversion});

  /// Si viene, se editan sus datos; el dinero se corrige en sus movimientos.
  final Inversion? inversion;

  @override
  ConsumerState<InversionSheet> createState() => _InversionSheetState();
}

class _InversionSheetState extends ConsumerState<InversionSheet> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.inversion?.nombre ?? '');
  late final _nota = TextEditingController(text: widget.inversion?.nota ?? '');
  final _monto = TextEditingController();
  late String _tipo = widget.inversion?.tipo ?? 'ganado';
  String _fecha = hoyYmd();
  int? _cuenta;

  bool get _editando => widget.inversion != null;

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _nota.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(inversionesRepoProvider);
    if (_editando) {
      return _guardar(context, () => repo.actualizar(widget.inversion!.id, nombre: _nombre.text, tipo: _tipo, nota: _nota.text), aviso: 'Inversión actualizada');
    }
    return _guardar(
      context,
      () => repo.crear(nombre: _nombre.text, tipo: _tipo, monto: parseMonto(_monto.text), fecha: _fecha, cuentaId: _cuenta, nota: _nota.text),
      aviso: 'Inversión registrada',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final tipo = tipoInversion(_tipo);
    return SheetScaffold(
      title: _editando ? 'Editar inversión' : 'Nueva inversión',
      subtitle: _editando ? null : 'Queda registrada la fecha, el monto y de dónde salió el dinero',
      icon: tipo.icono,
      primaryLabel: _editando ? 'Guardar cambios' : 'Registrar inversión',
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
              const FieldLabel('¿En qué inviertes?'),
              ChoiceChips<String>(
                options: [for (final t in tiposInversion) (t.valor, t.etiqueta)],
                value: _tipo,
                onChanged: (v) => setState(() => _tipo = v),
              ),
              const VGap.md(),
              const FieldLabel('Nombre', required: true),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: InputDecoration(hintText: tipo.ejemplo, counterText: ''),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe un nombre para la inversión' : null,
              ),
              if (!_editando) ...[
                const VGap.md(),
                const FieldLabel('¿Cuánto invertiste?', required: true),
                MoneyField(controller: _monto, big: true, validator: (v) => v <= 0 ? 'Escribe el monto invertido' : null),
                const VGap.md(),
                DateField(value: _fecha, last: DateTime.now(), label: '¿Cuándo?', onChanged: (v) => setState(() => _fecha = v)),
                const VGap.md(),
                const FieldLabel('¿De dónde salió el dinero?'),
                cuentaDropdown(cuentas: cuentas, value: _cuenta, nula: 'De ninguna cuenta (ya lo tenía)', onChanged: (v) => setState(() => _cuenta = v)),
                _AvisoSaldo(cuentas: cuentas, cuentaId: _cuenta, monto: parseMonto(_monto.text)),
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
  late final _monto = TextEditingController(text: montoInicial(widget.movimiento?.monto ?? 0));
  late final _nota = TextEditingController(text: widget.movimiento?.nota ?? '');
  late String _fecha = widget.movimiento?.fecha ?? hoyYmd();
  late int? _cuenta = widget.movimiento?.cuentaId;
  late final _inicial = '${_monto.text}|${_nota.text}';

  bool get _editando => widget.movimiento != null;
  bool get _aporte => widget.tipo == TipoMovimiento.aporte;
  bool get _valoracion => widget.tipo == TipoMovimiento.valoracion;

  @override
  void initState() {
    super.initState();
    _inicial;
    _monto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  (String, String, IconData) get _textos => switch (widget.tipo) {
        TipoMovimiento.aporte => ('Agregar dinero', '¿Cuánto agregaste?', Icons.add_rounded),
        TipoMovimiento.retiro => ('Vender una parte', '¿Cuánto recibiste?', Icons.sell_rounded),
        TipoMovimiento.venta => ('Vender todo', '¿Cuánto recibiste?', Icons.sell_rounded),
        TipoMovimiento.valoracion => ('Actualizar valor', '¿Cuánto vale hoy?', Icons.trending_up_rounded),
      };

  Future<void> _enviar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(inversionesRepoProvider);
    final monto = parseMonto(_monto.text);
    return _guardar(
      context,
      () => _editando
          ? repo.actualizarMovimiento(widget.movimiento!.id, tipo: widget.tipo, monto: monto, fecha: _fecha, cuentaId: _valoracion ? null : _cuenta, nota: _nota.text)
          : repo.agregarMovimiento(widget.inversion.id, tipo: widget.tipo, monto: monto, fecha: _fecha, cuentaId: _valoracion ? null : _cuenta, nota: _nota.text),
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
      hayCambios: () => '${_monto.text}|${_nota.text}' != _inicial,
      headerAction: _editando ? IconButton(tooltip: 'Eliminar movimiento', onPressed: _eliminar, icon: Icon(Icons.delete_outline_rounded, color: p.danger)) : null,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(pregunta, required: true),
              MoneyField(controller: _monto, big: true, validator: _valoracion ? null : (v) => v <= 0 ? 'Escribe el monto' : null),
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
                if (_aporte) _AvisoSaldo(cuentas: cuentas, cuentaId: _cuenta, monto: parseMonto(_monto.text)),
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
      primaryLabel: i.vendida ? null : 'Agregar dinero',
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
        Row(children: [
          dato(i.vendida ? 'Recibido' : 'Vale hoy', cop(i.vendida ? i.recibido : i.valor)),
          const HGap.sm(),
          dato('Invertido', cop(i.invertido)),
        ]),
        const VGap.md(),
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
            OutlinedButton.icon(onPressed: () => abrir(TipoMovimiento.valoracion), icon: const Icon(Icons.trending_up_rounded, size: IconSizes.md), label: const Text('Actualizar valor')),
            OutlinedButton.icon(onPressed: () => abrir(TipoMovimiento.retiro), icon: const Icon(Icons.sell_outlined, size: IconSizes.md), label: const Text('Vender una parte')),
            OutlinedButton.icon(onPressed: () => abrir(TipoMovimiento.venta), icon: const Icon(Icons.sell_rounded, size: IconSizes.md), label: const Text('Vender todo')),
          ]),
        ],
        const VGap.lg(),
        const SectionHeader('Historial'),
        for (final m in i.movimientos.reversed) _FilaMovimiento(movimiento: m, onTap: () => abrir(m.tipo, m)),
      ],
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento, required this.onTap});
  final MovimientoInversion movimiento;
  final VoidCallback onTap;

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
      title: Text(m.tipo.etiqueta, style: context.text.titleSmall),
      subtitle: Text(
        ['${fechaCorta(m.fecha)} ${parseYmd(m.fecha).year}', ?cuenta, if (m.nota.isNotEmpty) m.nota].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall,
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(cop(m.monto), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ),
    );
  }
}
