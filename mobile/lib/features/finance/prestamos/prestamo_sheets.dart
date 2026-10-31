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
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../inversiones/inversion_sheets.dart' show AvisoSaldo, guardarYCerrar;
import '../sheets/finance_sheets.dart' show cuentaDropdown;
import 'prestamos_logica.dart';
import 'prestamos_repository.dart';

double _tasaDe(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

String _textoTasa(double t) => t == t.roundToDouble() ? t.toStringAsFixed(0) : '$t'.replaceAll('.', ',');

String _fechaConAnio(String f) => '${fechaCorta(f)} ${parseYmd(f).year}';

// ─────────────────────────── Nuevo préstamo / editar ───────────────────────────

class PrestamoSheet extends ConsumerStatefulWidget {
  const PrestamoSheet({super.key, this.prestamo});

  /// Si viene, se editan sus datos; el dinero se corrige en sus movimientos.
  final Prestamo? prestamo;

  @override
  ConsumerState<PrestamoSheet> createState() => _PrestamoSheetState();
}

class _PrestamoSheetState extends ConsumerState<PrestamoSheet> {
  final _form = GlobalKey<FormState>();
  late final _persona = TextEditingController(text: widget.prestamo?.persona ?? '');
  late final _nota = TextEditingController(text: widget.prestamo?.nota ?? '');
  final _monto = TextEditingController();
  late final _tasa = TextEditingController(text: (widget.prestamo?.tasaMensual ?? 0) > 0 ? _textoTasa(widget.prestamo!.tasaMensual) : '');
  String _fecha = hoyYmd();
  late bool _conInteres = widget.prestamo?.conInteres ?? false;
  late String? _interesDesde = widget.prestamo?.interesDesde;
  late String? _vencimiento = widget.prestamo?.vencimiento;
  int? _cuenta;
  late final _inicial = _firma();

  bool get _editando => widget.prestamo != null;

  String _firma() => [_persona.text, _nota.text, _monto.text, _tasa.text, _conInteres, _interesDesde, _vencimiento].join('|');

  @override
  void initState() {
    super.initState();
    _inicial;
    _monto.addListener(() => setState(() {}));
    _tasa.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_persona, _nota, _monto, _tasa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(prestamosRepoProvider);
    final tasa = _conInteres ? _tasaDe(_tasa.text) : 0.0;
    final desde = _interesDesde ?? _fecha;
    if (_editando) {
      return guardarYCerrar(
        context,
        () => repo.actualizar(widget.prestamo!.id, persona: _persona.text, tasaMensual: tasa, interesDesde: desde, vencimiento: _vencimiento, nota: _nota.text),
        aviso: 'Préstamo actualizado',
      );
    }
    return guardarYCerrar(
      context,
      () => repo.crear(persona: _persona.text, monto: parseMonto(_monto.text), fecha: _fecha, cuentaId: _cuenta, tasaMensual: tasa, interesDesde: desde, vencimiento: _vencimiento, nota: _nota.text),
      aviso: 'Préstamo registrado',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final capital = _editando ? widget.prestamo!.capitalPendiente : parseMonto(_monto.text);
    final tasa = _tasaDe(_tasa.text);
    final mensual = capital * tasa / 100;
    return SheetScaffold(
      title: _editando ? 'Editar préstamo' : 'Nuevo préstamo',
      subtitle: _editando ? null : 'Dinero que le prestaste a otra persona',
      icon: Icons.handshake_rounded,
      primaryLabel: _editando ? 'Guardar cambios' : 'Registrar préstamo',
      onPrimary: _enviar,
      hayCambios: () => _firma() != _inicial,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('¿A quién le prestaste?', required: true),
              TextFormField(
                controller: _persona,
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                decoration: const InputDecoration(hintText: 'Ej.: Ana Gómez', counterText: '', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe el nombre de la persona' : null,
              ),
              if (!_editando) ...[
                const VGap.md(),
                const FieldLabel('¿Cuánto le prestaste?', required: true),
                MoneyField(controller: _monto, big: true, validator: (v) => v <= 0 ? 'Escribe el monto prestado' : null),
                const VGap.md(),
                DateField(
                  value: _fecha,
                  last: DateTime.now(),
                  label: '¿Cuándo?',
                  onChanged: (v) => setState(() {
                    // Mientras no elija otra, los intereses corren desde que prestó.
                    if (_interesDesde == null || _interesDesde == _fecha) _interesDesde = v;
                    _fecha = v;
                  }),
                ),
                const VGap.md(),
                const FieldLabel('¿De dónde salió el dinero?'),
                cuentaDropdown(cuentas: cuentas, value: _cuenta, nula: 'De ninguna cuenta (se lo presté antes)', onChanged: (v) => setState(() => _cuenta = v)),
                AvisoSaldo(cuentas: cuentas, cuentaId: _cuenta, monto: parseMonto(_monto.text)),
              ],
              const VGap.md(),
              const FieldLabel('¿Genera intereses?'),
              SegmentedPill<bool>(
                value: _conInteres,
                onChanged: (v) => setState(() {
                  _conInteres = v;
                  _interesDesde ??= _fecha;
                }),
                options: const [(false, 'Sin intereses', null), (true, 'Con intereses', null)],
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: !_conInteres
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const VGap.md(),
                          const FieldLabel('Interés al mes (%)', required: true),
                          TextFormField(
                            controller: _tasa,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: 'Ej.: 2', prefixIcon: Icon(Icons.percent_rounded)),
                            validator: (v) {
                              final n = _tasaDe(v ?? '');
                              return n <= 0 || n > 100 ? 'Escribe un porcentaje entre 0 y 100' : null;
                            },
                          ),
                          const VGap.md(),
                          DateField(value: _interesDesde ?? _fecha, label: '¿Desde qué fecha gana intereses?', onChanged: (v) => setState(() => _interesDesde = v)),
                          const VGap.xs(),
                          Text(
                            mensual > 0
                                ? 'Gana ${cop(mensual / 30)} al día (${cop(mensual)} al mes). Se suma solo cada día y se ve en tu historial y patrimonio.'
                                : 'Se suma solo cada día y se ve en tu historial y patrimonio.',
                            style: context.text.bodySmall,
                          ),
                          if (_editando) ...[
                            const VGap.xs(),
                            Text('Si cambias el interés o la fecha, se recalcula lo ya sumado.', style: context.text.bodySmall),
                          ],
                        ],
                      ),
              ),
              const VGap.md(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Acordaron una fecha de pago', style: context.text.bodyMedium),
                value: _vencimiento != null,
                onChanged: (v) => setState(() => _vencimiento = v ? sumarDiasYmd(hoyYmd(), 30) : null),
              ),
              if (_vencimiento != null) DateField(value: _vencimiento!, label: '¿Cuándo debe pagarte?', onChanged: (v) => setState(() => _vencimiento = v)),
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

// ─────────────────────────── Abono / prestar más ───────────────────────────

class MovimientoPrestamoSheet extends ConsumerStatefulWidget {
  const MovimientoPrestamoSheet({super.key, required this.prestamo, required this.tipo, this.movimiento});
  final Prestamo prestamo;

  /// desembolso · abono
  final String tipo;

  /// Si viene, se corrige este movimiento.
  final MovimientoPrestamo? movimiento;

  @override
  ConsumerState<MovimientoPrestamoSheet> createState() => _MovimientoPrestamoSheetState();
}

class _MovimientoPrestamoSheetState extends ConsumerState<MovimientoPrestamoSheet> {
  final _form = GlobalKey<FormState>();
  late final _monto = TextEditingController(text: montoInicial(widget.movimiento?.total ?? 0));
  late final _interes = TextEditingController(text: montoInicial(widget.movimiento?.interes ?? 0));
  late final _nota = TextEditingController(text: widget.movimiento?.nota ?? '');
  late String _fecha = widget.movimiento?.fecha ?? hoyYmd();
  late int? _cuenta = widget.movimiento?.cuentaId;

  /// Los intereses siguen al monto hasta que la persona los cambie a mano.
  late bool _interesManual = widget.movimiento != null;
  late final _inicial = '${_monto.text}|${_interes.text}|${_nota.text}';

  bool get _editando => widget.movimiento != null;
  bool get _abono => widget.tipo == 'abono';
  Prestamo get _p => widget.prestamo;

  /// Lo que se puede abonar: si se está corrigiendo, cuenta lo que ya tenía este movimiento.
  double get _capitalMaximo => _p.capitalPendiente + (widget.movimiento?.capital ?? 0);
  double get _interesMaximo => _p.interesPendiente + (widget.movimiento?.interes ?? 0);

  /// ¿Hay intereses que separar? También si ya los tenía este abono.
  bool get _conIntereses => _abono && _interesMaximo >= 1;

  double get _interesAplicado {
    if (!_conIntereses) return 0;
    final v = parseMonto(_interes.text);
    final total = parseMonto(_monto.text);
    return v > total ? total : v;
  }

  double get _capitalAplicado => parseMonto(_monto.text) - _interesAplicado;

  @override
  void initState() {
    super.initState();
    _inicial;
    _monto.addListener(_alCambiarMonto);
    _interes.addListener(() => setState(() {}));
  }

  void _alCambiarMonto() {
    // Lo primero que se paga son los intereses.
    if (_conIntereses && !_interesManual) {
      final total = parseMonto(_monto.text);
      final sugerido = total < _interesMaximo ? total : _interesMaximo;
      final texto = montoInicial(sugerido);
      if (_interes.text != texto) _interes.text = texto;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _monto.dispose();
    _interes.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(prestamosRepoProvider);
    final capital = _capitalAplicado;
    final interes = _interesAplicado;
    return guardarYCerrar(
      context,
      () => _editando
          ? repo.actualizarMovimiento(widget.movimiento!.id, tipo: widget.tipo, capital: capital, interes: interes, fecha: _fecha, cuentaId: _cuenta, nota: _nota.text)
          : repo.agregarMovimiento(_p.id, tipo: widget.tipo, capital: capital, interes: interes, fecha: _fecha, cuentaId: _cuenta, nota: _nota.text),
      aviso: _editando ? 'Movimiento corregido' : (_abono ? 'Abono registrado' : 'Préstamo actualizado'),
    );
  }

  Future<void> _eliminar() async {
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    final si = await confirmar(
      context,
      titulo: '¿Eliminar este movimiento?',
      mensaje: 'Si movió dinero de una cuenta, ese saldo vuelve a como estaba y los intereses se recalculan.',
      confirmar: 'Eliminar',
      destructivo: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!si) return;
    try {
      await ref.read(prestamosRepoProvider).eliminarMovimiento(widget.movimiento!.id);
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
    final todo = _capitalMaximo + _interesMaximo;
    return SheetScaffold(
      title: _abono ? (_editando ? 'Corregir abono' : 'Registrar abono') : (_editando ? 'Corregir préstamo' : 'Prestar más'),
      subtitle: _p.persona,
      icon: _abono ? Icons.south_west_rounded : Icons.north_east_rounded,
      primaryLabel: _editando ? 'Guardar cambios' : 'Registrar',
      onPrimary: _enviar,
      hayCambios: () => '${_monto.text}|${_interes.text}|${_nota.text}' != _inicial,
      headerAction: _editando ? IconButton(tooltip: 'Eliminar movimiento', onPressed: _eliminar, icon: Icon(Icons.delete_outline_rounded, color: p.danger)) : null,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(_abono ? '¿Cuánto te pagó?' : '¿Cuánto más le prestaste?', required: true),
              MoneyField(
                controller: _monto,
                big: true,
                validator: (v) {
                  if (v <= 0) return 'Escribe el monto';
                  if (_abono && _capitalAplicado > _capitalMaximo + 0.5) {
                    return 'Solo faltan ${cop(_capitalMaximo)} de capital${_conIntereses ? ' y ${cop(_interesMaximo)} de intereses' : ''}';
                  }
                  return null;
                },
              ),
              if (_abono && !_editando && todo >= 1) ...[
                const VGap.xs(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.done_all_rounded, size: IconSizes.sm),
                    label: Text('Pagó todo: ${cop(todo)}'),
                    onPressed: () => _monto.text = miles(todo.round()),
                  ),
                ),
              ],
              if (_conIntereses) ...[
                const VGap.md(),
                const FieldLabel('De eso, ¿cuánto es de intereses?'),
                Focus(
                  onFocusChange: (f) {
                    if (f) _interesManual = true;
                  },
                  child: MoneyField(controller: _interes, validator: (v) => v > _interesMaximo + 1 ? 'Solo hay ${cop(_interesMaximo)} de intereses acumulados' : null),
                ),
                const VGap.xs(),
                Text('Van ${cop(_capitalAplicado)} al capital y ${cop(_interesAplicado)} a los intereses.', style: context.text.bodySmall),
              ],
              const VGap.md(),
              DateField(value: _fecha, first: _abono ? parseYmd(_p.desde ?? _fecha) : null, last: DateTime.now(), label: '¿Cuándo?', onChanged: (v) => setState(() => _fecha = v)),
              const VGap.md(),
              FieldLabel(_abono ? '¿A dónde llegó el dinero?' : '¿De dónde salió el dinero?'),
              cuentaDropdown(cuentas: cuentas, value: _cuenta, nula: _abono ? 'A ninguna cuenta' : 'De ninguna cuenta', onChanged: (v) => setState(() => _cuenta = v)),
              if (!_abono) AvisoSaldo(cuentas: cuentas, cuentaId: _cuenta, monto: parseMonto(_monto.text)),
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

class PrestamoDetalleSheet extends ConsumerWidget {
  const PrestamoDetalleSheet({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.palette;
    final prestamo = ref.watch(prestamosProvider).value?.where((x) => x.id == id).firstOrNull;
    if (prestamo == null) return const SizedBox(height: 120);
    final p = prestamo;

    void abrir(String tipo, [MovimientoPrestamo? m]) => showAppSheet(context, (_) => MovimientoPrestamoSheet(prestamo: p, tipo: tipo, movimiento: m));

    Future<void> accion(Future<void> Function() f, String aviso, {bool cerrarHoja = false}) async {
      final nav = Navigator.of(context);
      final toaster = Toaster.of(context);
      try {
        await f();
        HapticFeedback.mediumImpact();
        if (cerrarHoja) nav.pop();
        toaster.show(aviso, icon: Icons.check_circle_rounded);
      } on FinanzasError catch (e) {
        toaster.show(e.mensaje, error: true);
      } catch (_) {
        toaster.show('No se pudo guardar. Revisa tu conexión.', error: true);
      }
    }

    Future<void> eliminar() async {
      final si = await confirmar(
        context,
        titulo: '¿Eliminar el préstamo de ${p.persona}?',
        mensaje: 'Se borra su historial, las cuentas vuelven a como estaban y se quitan las ganancias que ya había sumado. No se puede deshacer.',
        confirmar: 'Eliminar',
        destructivo: true,
        icon: Icons.delete_outline_rounded,
      );
      if (!si || !context.mounted) return;
      await accion(() => ref.read(prestamosRepoProvider).eliminar(p.id), 'Préstamo eliminado', cerrarHoja: true);
    }

    Future<void> cerrar() async {
      final si = await confirmar(
        context,
        titulo: '¿Dejar de cobrarle a ${p.persona}?',
        mensaje: 'Para cuando se saldó de otra forma o lo das por perdido. Dejan de sumar los intereses y sale de tu patrimonio. Puedes reabrirlo después.',
        confirmar: 'Dejar de cobrar',
        icon: Icons.block_rounded,
      );
      if (!si || !context.mounted) return;
      await accion(() => ref.read(prestamosRepoProvider).cerrar(p.id, fecha: hoyYmd()), 'Ya no cuenta en tu patrimonio');
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
      title: p.persona,
      subtitle: [
        p.conInteres ? '${_textoTasa(p.tasaMensual)}% mensual' : 'Sin intereses',
        if (p.cerrado) 'Dejaste de cobrar el ${fechaCorta(p.cerradoEn!)}' else if (p.pagado) 'Pagado',
      ].join(' · '),
      icon: Icons.handshake_rounded,
      primaryLabel: p.activo ? 'Registrar abono' : null,
      onPrimary: p.activo ? () => abrir('abono') : null,
      headerAction: PopupMenuButton<VoidCallback>(
        tooltip: 'Más opciones',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (f) => f(),
        itemBuilder: (_) => [
          PopupMenuItem(value: () => showAppSheet(context, (_) => PrestamoSheet(prestamo: p)), child: const Text('Editar')),
          if (p.activo) PopupMenuItem(value: cerrar, child: const Text('Dejar de cobrar')),
          if (p.cerrado) PopupMenuItem(value: () => accion(() => ref.read(prestamosRepoProvider).reabrir(p.id), 'Préstamo reabierto'), child: const Text('Reabrir')),
          PopupMenuItem(value: eliminar, child: Text('Eliminar', style: TextStyle(color: c.danger))),
        ],
      ),
      children: [
        Row(children: [
          dato('Te debe', cop(p.pendiente)),
          const HGap.sm(),
          dato('Le prestaste', cop(p.prestado)),
        ]),
        const VGap.md(),
        Row(children: [
          dato('Te ha pagado', cop(p.cobrado), color: c.success),
          const HGap.sm(),
          dato('Capital pendiente', cop(p.capitalPendiente)),
        ]),
        if (p.conInteres) ...[
          const VGap.md(),
          Row(children: [
            dato('Intereses ganados', cop(p.interesCausado), color: c.success),
            const HGap.sm(),
            dato('Intereses por cobrar', cop(p.interesPendiente)),
          ]),
          const VGap.xs(),
          Text(
            [
              if (p.interesDesde != null) 'Corren desde el ${_fechaConAnio(p.interesDesde!)}',
              if (p.gananciaDiaria > 0) 'hoy gana ${cop(p.gananciaDiaria)} al día',
            ].join(' · '),
            style: context.text.bodySmall,
          ),
        ],
        if (p.vencimiento != null) ...[
          const VGap.sm(),
          Text('Fecha de pago: ${_fechaConAnio(p.vencimiento!)}', style: context.text.bodySmall),
        ],
        if (p.nota.isNotEmpty) ...[
          const VGap.sm(),
          Text(p.nota, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
        ],
        if (!p.cerrado) ...[
          const VGap.md(),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(onPressed: () => abrir('desembolso'), icon: const Icon(Icons.north_east_rounded, size: IconSizes.md), label: const Text('Prestar más')),
          ),
        ],
        const VGap.lg(),
        const SectionHeader('Historial'),
        for (final m in p.movimientos.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => abrir(m.tipo, m),
            leading: IconBadge(m.esDesembolso ? Icons.north_east_rounded : Icons.south_west_rounded, color: m.esDesembolso ? c.info : c.success, size: 40),
            title: Text(m.esDesembolso ? 'Le prestaste' : 'Te pagó', style: context.text.titleSmall),
            subtitle: Text(
              [
                _fechaConAnio(m.fecha),
                m.cuentaId == null ? 'Sin cuenta' : (m.cuentaNombre ?? 'Cuenta eliminada'),
                if (m.interes > 0) '${cop(m.interes)} de intereses',
                if (m.nota.isNotEmpty) m.nota,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(cop(m.total), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
          ),
      ],
    );
  }
}
