import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/db/database.dart';
import '../../../core/icon_map.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../widgets/celebration.dart';

/// Ejecuta una operación de finanzas y muestra el error de negocio si falla.
Future<bool> _ejecutar(BuildContext context, Future<void> Function() op, {String? ok, IconData? icon}) async {
  final nav = Navigator.of(context);
  final toaster = Toaster.of(context);
  try {
    await op();
    HapticFeedback.mediumImpact();
    nav.pop();
    if (ok != null) toaster.show(ok, icon: icon);
    return true;
  } on FinanzasError catch (e) {
    toaster.show(e.mensaje, error: true);
    return false;
  }
}

Widget _cuentaDropdown({
  required List<Cuenta> cuentas,
  required int? value,
  required ValueChanged<int?> onChanged,
  String nula = 'Ninguna',
  bool permitirNula = true,
  int? excluir,
  String? Function(int?)? validator,
}) {
  return DropdownButtonFormField<int?>(
    initialValue: cuentas.any((c) => c.id == value) ? value : null,
    isExpanded: true,
    decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_wallet_rounded)),
    hint: const Text('Selecciona una cuenta'),
    validator: validator,
    items: [
      if (permitirNula) DropdownMenuItem(value: null, child: Text(nula)),
      for (final c in cuentas)
        DropdownMenuItem(
          value: c.id,
          enabled: c.id != excluir,
          child: Text('${c.nombre} · ${cop(c.saldo)}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

// ─────────────────────────── Cuenta ───────────────────────────

class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key, this.cuenta});
  final Cuenta? cuenta;

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
  final _form = GlobalKey<FormState>();
  late String _tipo;
  late String _fechaInicio;
  late final TextEditingController _nombre, _saldo, _limite, _tasa, _plazo, _corte;

  @override
  void initState() {
    super.initState();
    final c = widget.cuenta;
    _tipo = c?.tipo ?? 'ahorros';
    _fechaInicio = c?.fechaInicio ?? hoyYmd();
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _saldo = TextEditingController(text: montoInicial(c?.saldo ?? 0));
    _limite = TextEditingController(text: montoInicial(c?.limite ?? 0));
    _tasa = TextEditingController(text: (c?.interesTasa ?? 0) == 0 ? '' : c!.interesTasa.toString());
    _plazo = TextEditingController(text: (c?.plazoDias ?? 0) == 0 ? '' : '${c!.plazoDias}');
    _corte = TextEditingController(text: c?.diaCorte?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nombre, _saldo, _limite, _tasa, _plazo, _corte]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credito = esCredito(_tipo);
    final cdt = _tipo == 'cdt';
    final t = tipoCuenta(_tipo);
    return SheetScaffold(
      title: widget.cuenta == null ? 'Nueva cuenta' : 'Editar cuenta',
      icon: t.icon,
      primaryLabel: widget.cuenta == null ? 'Crear cuenta' : 'Guardar cambios',
      onPrimary: () {
        if (!(_form.currentState?.validate() ?? false)) return;
        final input = CuentaInput(
          nombre: _nombre.text,
          tipo: _tipo,
          saldo: parseMonto(_saldo.text),
          limite: parseMonto(_limite.text),
          interesTasa: double.tryParse(_tasa.text.replaceAll(',', '.')) ?? 0,
          fechaInicio: _fechaInicio,
          plazoDias: int.tryParse(_plazo.text) ?? 0,
          diaCorte: int.tryParse(_corte.text),
        );
        final repo = ref.read(financeRepoProvider);
        _ejecutar(
          context,
          () => widget.cuenta == null ? repo.crearCuenta(input) : repo.actualizarCuenta(widget.cuenta!.id, input),
          ok: widget.cuenta == null ? 'Cuenta creada' : 'Cuenta actualizada',
        );
      },
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Tipo de cuenta'),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final tc in tiposCuenta)
                    ChoiceChip(
                      avatar: Icon(tc.icon, size: IconSizes.sm, color: tc.value == _tipo ? tc.colors.first : context.palette.textSecondary),
                      label: Text(tc.label),
                      selected: tc.value == _tipo,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _tipo = tc.value),
                    ),
                ],
              ),
              const FieldLabel('Nombre', required: true),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: credito ? 'Ej. Visa Bancolombia' : 'Ej. Nequi, Davivienda…', prefixIcon: const Icon(Icons.badge_rounded)),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              FieldLabel(credito ? 'Deuda actual' : 'Saldo actual'),
              MoneyField(controller: _saldo),
              AnimatedSize(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (credito) ...[
                      const FieldLabel('Cupo total'),
                      MoneyField(controller: _limite),
                      const FieldLabel('Día de corte'),
                      TextFormField(
                        controller: _corte,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                        decoration: const InputDecoration(
                          hintText: 'Opcional · 1 a 31',
                          prefixIcon: Icon(Icons.content_cut_rounded),
                          helperText: 'Las compras se agendan como cobros en el siguiente corte.',
                        ),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return null;
                          final n = int.tryParse(v!);
                          return n == null || n < 1 || n > 31 ? 'Debe estar entre 1 y 31' : null;
                        },
                      ),
                    ],
                    if (cdt) ...[
                      const FieldLabel('Tasa efectiva anual (%)'),
                      TextFormField(
                        controller: _tasa,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'Ej. 11,5', prefixIcon: Icon(Icons.percent_rounded)),
                      ),
                      const FieldLabel('Fecha de apertura'),
                      DateField(value: _fechaInicio, onChanged: (v) => setState(() => _fechaInicio = v)),
                      const FieldLabel('Plazo en días'),
                      TextFormField(
                        controller: _plazo,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: 'Vacío = rendimiento continuo (cajita)',
                          prefixIcon: Icon(Icons.timelapse_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Transferencia ───────────────────────────

class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _form = GlobalKey<FormState>();
  int? _origen, _destino;
  String _fecha = hoyYmd();
  final _monto = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    return SheetScaffold(
      title: 'Transferir entre cuentas',
      subtitle: 'Pagar tarjeta, mover a ahorros, retirar efectivo…',
      icon: Icons.swap_horiz_rounded,
      primaryLabel: 'Transferir',
      onPrimary: () {
        if (!(_form.currentState?.validate() ?? false)) return;
        _ejecutar(
          context,
          () => ref.read(financeRepoProvider).transferir(
                origenId: _origen!,
                destinoId: _destino!,
                monto: parseMonto(_monto.text),
                fecha: _fecha,
                descripcion: _desc.text,
              ),
          ok: 'Transferencia registrada',
          icon: Icons.swap_horiz_rounded,
        );
      },
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Desde', required: true),
              _cuentaDropdown(
                cuentas: cuentas,
                value: _origen,
                permitirNula: false,
                excluir: _destino,
                onChanged: (v) => setState(() => _origen = v),
                validator: (v) => v == null ? 'Elige la cuenta de origen' : null,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Icon(Icons.arrow_downward_rounded, color: p.accent),
                ),
              ),
              const FieldLabel('Hacia', required: true),
              _cuentaDropdown(
                cuentas: cuentas,
                value: _destino,
                permitirNula: false,
                excluir: _origen,
                onChanged: (v) => setState(() => _destino = v),
                validator: (v) {
                  if (v == null) return 'Elige la cuenta de destino';
                  if (v == _origen) return 'Debe ser distinta a la de origen';
                  return null;
                },
              ),
              const FieldLabel('Monto', required: true),
              MoneyField(controller: _monto, big: true, validator: (v) => v <= 0 ? 'Ingresa un monto mayor a 0' : null),
              const FieldLabel('Fecha'),
              DateField(value: _fecha, onChanged: (v) => setState(() => _fecha = v)),
              const FieldLabel('Descripción'),
              TextFormField(controller: _desc, decoration: const InputDecoration(hintText: 'Opcional')),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Ingreso planificado ───────────────────────────

class PlanSheet extends ConsumerStatefulWidget {
  const PlanSheet({super.key, this.plan});
  final IngresoPlanificado? plan;

  @override
  ConsumerState<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<PlanSheet> {
  final _form = GlobalKey<FormState>();
  late String _frecuencia;
  late String _fecha;
  int? _cuenta;
  late bool _activo;
  late final TextEditingController _desc, _monto;

  @override
  void initState() {
    super.initState();
    final pl = widget.plan;
    _frecuencia = pl?.frecuencia ?? 'mensual';
    _fecha = pl?.fechaInicio ?? hoyYmd();
    _cuenta = pl?.cuentaId;
    _activo = pl?.activo ?? true;
    _desc = TextEditingController(text: pl?.descripcion ?? '');
    _monto = TextEditingController(text: montoInicial(pl?.monto ?? 0));
  }

  @override
  void dispose() {
    _desc.dispose();
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    return SheetScaffold(
      title: widget.plan == null ? 'Ingreso planificado' : 'Editar ingreso planificado',
      subtitle: 'Salario, arriendo que cobras, pagos recurrentes…',
      icon: Icons.event_repeat_rounded,
      primaryLabel: widget.plan == null ? 'Guardar' : 'Guardar cambios',
      onPrimary: () {
        if (!(_form.currentState?.validate() ?? false)) return;
        final repo = ref.read(financeRepoProvider);
        _ejecutar(
          context,
          () => widget.plan == null
              ? repo.crearPlan(descripcion: _desc.text, monto: parseMonto(_monto.text), frecuencia: _frecuencia, fechaInicio: _fecha, cuentaId: _cuenta)
              : repo.actualizarPlan(widget.plan!.id,
                  descripcion: _desc.text, monto: parseMonto(_monto.text), frecuencia: _frecuencia, fechaInicio: _fecha, cuentaId: _cuenta, activo: _activo),
          ok: 'Ingreso planificado guardado',
        );
      },
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Descripción', required: true),
              TextFormField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ej. Salario', prefixIcon: Icon(Icons.work_rounded)),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe una descripción' : null,
              ),
              const FieldLabel('Monto esperado', required: true),
              MoneyField(controller: _monto, validator: (v) => v <= 0 ? 'Ingresa un monto mayor a 0' : null),
              const FieldLabel('Frecuencia'),
              ChoiceChips<String>(options: frecuenciasIngreso, value: _frecuencia, onChanged: (v) => setState(() => _frecuencia = v)),
              const FieldLabel('Primera fecha'),
              DateField(value: _fecha, onChanged: (v) => setState(() => _fecha = v)),
              const FieldLabel('Cuenta donde llega'),
              _cuentaDropdown(cuentas: cuentas, value: _cuenta, nula: 'Ninguna (solo registrar)', onChanged: (v) => setState(() => _cuenta = v)),
              if (widget.plan != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  title: const Text('Activo'),
                  subtitle: const Text('Pausa el plan sin borrar su historial.'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Verificar ingreso ───────────────────────────

class VerifySheet extends ConsumerStatefulWidget {
  const VerifySheet({super.key, required this.ocurrencia});
  final OcurrenciaIngreso ocurrencia;

  @override
  ConsumerState<VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends ConsumerState<VerifySheet> {
  late String _fecha;
  int? _cuenta;
  late final TextEditingController _monto;

  @override
  void initState() {
    super.initState();
    _fecha = widget.ocurrencia.fechaEsperada.compareTo(hoyYmd()) > 0 ? hoyYmd() : widget.ocurrencia.fechaEsperada;
    _cuenta = widget.ocurrencia.plan.cuentaId;
    _monto = TextEditingController(text: montoInicial(widget.ocurrencia.plan.monto));
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.ocurrencia;
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    return SheetScaffold(
      title: '¿Llegó el dinero?',
      subtitle: '${o.plan.descripcion} · esperado el ${fechaCorta(o.fechaEsperada)}',
      icon: Icons.verified_rounded,
      primaryLabel: 'Confirmar ingreso',
      onPrimary: () => _ejecutar(
        context,
        () => ref.read(financeRepoProvider).verificarIngreso(
              plan: o.plan,
              fechaEsperada: o.fechaEsperada,
              fechaReal: _fecha,
              montoReal: parseMonto(_monto.text),
              cuentaId: _cuenta,
            ),
        ok: 'Ingreso confirmado y sumado a la cuenta',
        icon: Icons.verified_rounded,
      ),
      children: [
        const FieldLabel('Monto recibido'),
        MoneyField(controller: _monto, big: true),
        const FieldLabel('Fecha en que llegó'),
        DateField(value: _fecha, onChanged: (v) => setState(() => _fecha = v)),
        const FieldLabel('Cuenta'),
        _cuentaDropdown(cuentas: cuentas, value: _cuenta, nula: 'Ninguna (solo registrar)', onChanged: (v) => setState(() => _cuenta = v)),
      ],
    );
  }
}

// ─────────────────────────── Metas ───────────────────────────

const coloresMeta = [0xFF34E47E, 0xFF60A5FA, 0xFFF472B6, 0xFFFBBF24, 0xFFA78BFA, 0xFF2DD4BF, 0xFFF97316, 0xFFF87171];
const iconosMeta = ['savings', 'flight', 'home', 'directions_car', 'two_wheeler', 'school', 'laptop', 'beach_access', 'card_giftcard', 'pets', 'fitness_center', 'celebration'];

class GoalSheet extends ConsumerStatefulWidget {
  const GoalSheet({super.key, this.meta});
  final Meta? meta;

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre, _desc, _objetivo, _actual;
  String? _fecha;
  late String _icono;
  late int _color;

  @override
  void initState() {
    super.initState();
    final m = widget.meta;
    _nombre = TextEditingController(text: m?.nombre ?? '');
    _desc = TextEditingController(text: m?.descripcion ?? '');
    _objetivo = TextEditingController(text: montoInicial(m?.montoObjetivo ?? 0));
    _actual = TextEditingController(text: montoInicial(m?.montoActual ?? 0));
    _fecha = m?.fechaObjetivo;
    _icono = m?.icono ?? 'savings';
    _color = m?.color ?? coloresMeta.first;
  }

  @override
  void dispose() {
    for (final c in [_nombre, _desc, _objetivo, _actual]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SheetScaffold(
      title: widget.meta == null ? 'Nueva meta de ahorro' : 'Editar meta',
      icon: iconoPorNombre(_icono),
      primaryLabel: widget.meta == null ? 'Crear meta' : 'Guardar cambios',
      onPrimary: () {
        if (!(_form.currentState?.validate() ?? false)) return;
        final input = MetaInput(
          nombre: _nombre.text,
          descripcion: _desc.text,
          montoObjetivo: parseMonto(_objetivo.text),
          montoActual: parseMonto(_actual.text),
          fechaObjetivo: _fecha,
          icono: _icono,
          color: _color,
        );
        final repo = ref.read(financeRepoProvider);
        _ejecutar(context, () => widget.meta == null ? repo.crearMeta(input) : repo.actualizarMeta(widget.meta!.id, input),
            ok: widget.meta == null ? 'Meta creada' : 'Meta actualizada', icon: Icons.flag_rounded);
      },
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Nombre', required: true),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ej. Viaje a Cartagena'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              const FieldLabel('Monto objetivo', required: true),
              MoneyField(controller: _objetivo, validator: (v) => v <= 0 ? 'Ingresa un monto mayor a 0' : null),
              const FieldLabel('Ya tengo ahorrado'),
              MoneyField(controller: _actual),
              const FieldLabel('Fecha objetivo'),
              if (_fecha == null)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _fecha = sumarDiasYmd(hoyYmd(), 90)),
                  icon: const Icon(Icons.event_rounded),
                  label: const Text('Agregar fecha límite'),
                )
              else
                Row(children: [
                  Expanded(child: DateField(value: _fecha!, first: DateTime.now(), onChanged: (v) => setState(() => _fecha = v))),
                  IconButton(tooltip: 'Quitar fecha', onPressed: () => setState(() => _fecha = null), icon: const Icon(Icons.close_rounded)),
                ]),
              const FieldLabel('Ícono y color'),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final i in iconosMeta)
                    _Seleccionable(
                      selected: i == _icono,
                      color: Color(_color),
                      onTap: () => setState(() => _icono = i),
                      child: Icon(iconoPorNombre(i), color: i == _icono ? Color(_color) : p.textSecondary),
                    ),
                ],
              ),
              const VGap.sm(),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final c in coloresMeta)
                    Semantics(
                      button: true,
                      selected: c == _color,
                      label: 'Color',
                      child: Pressable(
                        onTap: () => setState(() => _color = c),
                        child: AnimatedContainer(
                          duration: Motion.of(context, Motion.fast),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: c == _color ? p.text : Colors.transparent, width: 3),
                          ),
                          child: c == _color ? const Icon(Icons.check_rounded, color: Colors.black87) : null,
                        ),
                      ),
                    ),
                ],
              ),
              const FieldLabel('Descripción'),
              TextFormField(controller: _desc, maxLines: 2, decoration: const InputDecoration(hintText: 'Opcional')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Seleccionable extends StatelessWidget {
  const _Seleccionable({required this.selected, required this.color, required this.onTap, required this.child});
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : p.surfaceHigh,
            borderRadius: Radii.rMd,
            border: Border.all(color: selected ? color : p.border, width: selected ? 1.6 : 1),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Aportar a una meta (opcionalmente desde una cuenta).
class ContributionSheet extends ConsumerStatefulWidget {
  const ContributionSheet({super.key, required this.meta, required this.parentContext});
  final Meta meta;
  final BuildContext parentContext;

  @override
  ConsumerState<ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<ContributionSheet> {
  final _monto = TextEditingController();
  int? _cuenta;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    final cuentas = (ref.watch(cuentasProvider).value ?? const <Cuenta>[]).where((c) => !esCredito(c.tipo)).toList();
    final falta = (m.montoObjetivo - m.montoActual).clamp(0, double.infinity);
    return SheetScaffold(
      title: 'Aportar a "${m.nombre}"',
      subtitle: 'Faltan ${cop(falta)}',
      icon: iconoPorNombre(m.icono),
      primaryLabel: 'Aportar',
      onPrimary: () async {
        final monto = parseMonto(_monto.text);
        final nav = Navigator.of(context);
        final toaster = Toaster.of(context);
        final parent = widget.parentContext;
        try {
          final cumplida = await ref.read(financeRepoProvider).aportarAMeta(m, monto, cuentaId: _cuenta);
          HapticFeedback.mediumImpact();
          nav.pop();
          if (cumplida && parent.mounted) {
            celebrar(parent);
            toaster.show('¡Meta cumplida! 🎉 ${m.nombre}', icon: Icons.emoji_events_rounded);
          } else {
            toaster.show('Aporte de ${cop(monto)} registrado', icon: Icons.savings_rounded);
          }
        } on FinanzasError catch (e) {
          toaster.show(e.mensaje, error: true);
        }
      },
      children: [
        const FieldLabel('Monto del aporte', required: true),
        MoneyField(controller: _monto, big: true, autofocus: true),
        const VGap.xs(),
        Wrap(spacing: Gap.xs, children: [
          for (final v in [50000, 100000, 200000])
            ActionChip(label: Text(cop(v)), onPressed: () => _monto.text = miles(v)),
          if (falta > 0) ActionChip(label: const Text('Lo que falta'), onPressed: () => _monto.text = miles(falta.round())),
        ]),
        const FieldLabel('Tomar el dinero de'),
        _cuentaDropdown(
          cuentas: cuentas,
          value: _cuenta,
          nula: 'No descontar de ninguna cuenta',
          onChanged: (v) => setState(() => _cuenta = v),
        ),
        const SizedBox(height: 6),
        Text(
          'Si eliges una cuenta, se registra un gasto de ahorro y se descuenta su saldo.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

// ─────────────────────────── Presupuesto ───────────────────────────

class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, required this.categoria, required this.estado, required this.mes});
  final CategoriaFinanzas categoria;
  final EstadoCategoria estado;
  final DateTime mes;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late final TextEditingController _limite;

  @override
  void initState() {
    super.initState();
    _limite = TextEditingController(text: montoInicial(widget.estado.limite));
  }

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = widget.categoria;
    final e = widget.estado;
    return SheetScaffold(
      title: 'Límite para ${c.label}',
      subtitle: '${mesesLargos[widget.mes.month - 1]} · gastado ${cop(e.gastado)}',
      icon: iconoPorNombre(c.icono),
      primaryLabel: 'Guardar límite',
      secondary: e.presupuesto == null
          ? null
          : OutlinedButton(
              onPressed: () => _ejecutar(context, () => ref.read(financeRepoProvider).quitarPresupuesto(c.valor), ok: 'Límite eliminado'),
              style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.5))),
              child: const Text('Quitar'),
            ),
      onPrimary: () => _ejecutar(
        context,
        () => ref.read(financeRepoProvider).guardarPresupuesto(
              categoria: c.valor,
              limite: parseMonto(_limite.text),
              mes: widget.mes.month,
              anio: widget.mes.year,
            ),
        ok: 'Presupuesto guardado',
        icon: Icons.pie_chart_rounded,
      ),
      children: [
        const FieldLabel('Límite mensual'),
        MoneyField(controller: _limite, big: true, autofocus: true),
        const VGap.sm(),
        Text(
          'El límite se mantiene los meses siguientes hasta que lo cambies. Te avisaremos al llegar al 80%.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

// ─────────────────────────── Categorías ───────────────────────────

class CategoriesSheet extends ConsumerStatefulWidget {
  const CategoriesSheet({super.key});

  @override
  ConsumerState<CategoriesSheet> createState() => _CategoriesSheetState();
}

class _CategoriesSheetState extends ConsumerState<CategoriesSheet> {
  final _label = TextEditingController();
  String _icono = 'sell';
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() => _error = null);
    try {
      await ref.read(financeRepoProvider).crearCategoria(_label.text, _icono);
      HapticFeedback.mediumImpact();
      _label.clear();
      setState(() => _icono = 'sell');
    } on FinanzasError catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cats = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final enUso = ref.watch(categoriasEnUsoProvider).value ?? const <String>{};
    return SheetScaffold(
      title: 'Categorías de gasto',
      icon: Icons.category_rounded,
      children: [
        const FieldLabel('Nueva categoría'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _crear(),
                decoration: InputDecoration(hintText: 'Ej. Mascotas', errorText: _error, prefixIcon: Icon(iconoPorNombre(_icono))),
              ),
            ),
            const HGap.xs(),
            IconButton.filled(tooltip: 'Crear categoría', onPressed: _crear, icon: const Icon(Icons.add_rounded)),
          ],
        ),
        const VGap.sm(),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (n, l, i) in iconosCategoria)
                Padding(
                  padding: const EdgeInsets.only(right: Gap.xs),
                  child: Tooltip(
                    message: l,
                    child: _Seleccionable(
                      selected: n == _icono,
                      color: p.accent,
                      onTap: () => setState(() => _icono = n),
                      child: Icon(i, color: n == _icono ? p.accent : p.textSecondary, size: IconSizes.md),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const VGap.lg(),
        Text('Tus categorías', style: context.text.titleSmall),
        const VGap.xs(),
        for (final c in cats)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: IconBadge(iconoPorNombre(c.icono), color: colorCategoria(c.valor), size: 38),
            title: Text(c.label),
            subtitle: Text(c.esDefault ? 'Predeterminada' : (enUso.contains(c.valor) ? 'En uso' : 'Personalizada'), style: context.text.bodySmall),
            trailing: c.esDefault
                ? null
                : IconButton(
                    tooltip: enUso.contains(c.valor) ? 'En uso: no se puede eliminar' : 'Eliminar',
                    onPressed: enUso.contains(c.valor)
                        ? null
                        : () async {
                            try {
                              await ref.read(financeRepoProvider).eliminarCategoria(c);
                            } on FinanzasError catch (e) {
                              if (context.mounted) toast(context, e.mensaje, error: true);
                            }
                          },
                    icon: Icon(Icons.delete_outline_rounded, color: enUso.contains(c.valor) ? p.textSecondary.withValues(alpha: 0.4) : p.danger),
                  ),
          ),
      ],
    );
  }
}
