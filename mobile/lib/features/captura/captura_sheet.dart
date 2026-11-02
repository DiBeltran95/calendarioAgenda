import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_module.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/icon_map.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../finance/finance_logic.dart';
import '../finance/finance_providers.dart';
import '../finance/finance_repository.dart';
import '../finance/pagos/pagos_logica.dart';
import '../finance/pagos/pagos_repository.dart';
import '../finance/sheets/transaction_sheet.dart';
import 'frecuentes.dart';
import 'interprete.dart';
import 'voz.dart';

Future<void> abrirCaptura(BuildContext context, {bool escuchar = false}) => showAppSheet(context, (_) => CapturaSheet(escuchar: escuchar));

/// Registrar un gasto o un ingreso escribiéndolo o diciéndolo como se le contaría a alguien.
class CapturaSheet extends ConsumerStatefulWidget {
  const CapturaSheet({super.key, this.escuchar = false});

  /// Abre directamente con el micrófono encendido.
  final bool escuchar;

  @override
  ConsumerState<CapturaSheet> createState() => _CapturaSheetState();
}

class _CapturaSheetState extends ConsumerState<CapturaSheet> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  final _monto = TextEditingController();
  bool _escuchando = false;
  bool _tecladoDecidido = false;

  /// Lo que se va a repetir, con la fecha elegida. Escribir o dictar lo reemplaza.
  Frecuente? _elegido;
  String _fecha = hoyYmd();

  static const _ejemplos = ['almuerzo 25 mil', 'taxi 15 mil', 'mercado 120 mil', 'me pagaron 2 millones'];

  MovimientoCapturado? get _resultado => interpretarFrase(_texto.text, DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.escuchar) WidgetsBinding.instance.addPostFrameCallback((_) => _alternarVoz());
    _monto.addListener(_alCambiarMonto);
    // El teclado taparía la lista: solo sale de una vez si no hay nada que sugerir.
    ref.listenManual(frecuentesProvider, fireImmediately: true, (_, v) {
      if (_tecladoDecidido || v.isLoading) return;
      _tecladoDecidido = true;
      if (!widget.escuchar && _visibles(v.value ?? const []).isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _elegido == null) _foco.requestFocus();
        });
      }
    });
  }

  void _alCambiarMonto() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_escuchando) ref.read(reconocedorVozProvider).detener();
    _texto.dispose();
    _foco.dispose();
    _monto.dispose();
    super.dispose();
  }

  void _fijar(String v) {
    _texto.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    setState(() => _elegido = null);
  }

  /// Sin el módulo activo tampoco se sugiere lo suyo.
  List<Frecuente> _visibles(List<Frecuente> lista) {
    final activos = ref.read(modulosActivosProvider);
    return activos.contains(AppModule.finanzas) ? lista : const [];
  }

  void _elegir(Frecuente f) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_escuchando) ref.read(reconocedorVozProvider).detener();
    _texto.clear();
    _monto.text = montoInicial(f.monto);
    setState(() {
      _elegido = f;
      _fecha = hoyYmd();
    });
  }

  /// La cuenta de siempre, si todavía existe.
  Cuenta? _cuentaDe(Frecuente f) => (ref.read(cuentasProvider).value ?? const <Cuenta>[]).where((c) => c.id == f.cuentaId).firstOrNull;

  bool get _puedeGuardar {
    return _elegido == null ? _resultado != null : parseMonto(_monto.text) > 0;
  }

  Future<String> _guardarElegido(Frecuente f) async {
    final monto = parseMonto(_monto.text);
    final ingreso = f.clase == ClaseFrecuente.ingreso;
    final cuenta = _cuentaDe(f);
    final esTarjeta = cuenta != null && esCredito(cuenta.tipo) && !ingreso;
    await ref.read(financeRepoProvider).crearTransaccion(TransaccionInput(
          tipo: ingreso ? 'ingreso' : 'gasto',
          monto: monto,
          descripcion: f.titulo,
          fecha: _fecha,
          cuentaId: cuenta?.id,
          categoria: f.categoria,
          cuotas: esTarjeta ? f.cuotas : 1,
        ));
    if (esTarjeta) return 'Compra registrada · ${f.cuotas == 1 ? 'cobro agendado' : '${f.cuotas} cuotas agendadas'} en Eventos';
    return '${ingreso ? 'Ingreso' : 'Gasto'} guardado: ${cop(monto)}';
  }

  Future<String> _guardarFrase(MovimientoCapturado m) async {
    await ref.read(financeRepoProvider).crearTransaccion(TransaccionInput(
          tipo: m.ingreso ? 'ingreso' : 'gasto',
          monto: m.monto,
          descripcion: m.descripcion,
          fecha: m.fecha,
          categoria: _categoriaDe(m),
        ));
    return '${m.ingreso ? 'Ingreso' : 'Gasto'} guardado: ${cop(m.monto)}';
  }

  Future<void> _alternarVoz() async {
    final voz = ref.read(reconocedorVozProvider);
    if (_escuchando) {
      await voz.detener();
      return;
    }
    final toaster = Toaster.of(context);
    if (!await voz.preparar()) {
      toaster.show('Para dictar, permite el micrófono en los ajustes del teléfono.', icon: Icons.mic_off_rounded);
      return;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _escuchando = true);
    await voz.escuchar(
      alTexto: (t) {
        if (mounted) _fijar(t);
      },
      alTerminar: () {
        if (mounted) setState(() => _escuchando = false);
      },
    );
  }

  String _categoriaDe(MovimientoCapturado m) {
    if (m.ingreso) return 'otros';
    final pago = CapturaPago(id: 0, origen: '', tipo: 'gasto', monto: m.monto, comercio: m.descripcion, tarjeta: '', app: '', fecha: DateTime.now());
    return sugerirCategoria(pago, ref.read(preferenciasPagosProvider).value ?? const [], ref.read(categoriasFinProvider).value ?? const []);
  }

  Future<void> _guardar() async {
    final f = _elegido;
    final r = _resultado;
    if (!_puedeGuardar) return;
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    try {
      final aviso = f != null ? await _guardarElegido(f) : await _guardarFrase(r!);
      HapticFeedback.mediumImpact();
      nav.pop();
      toaster.show(aviso, icon: Icons.check_circle_rounded);
    } on FinanzasError catch (e) {
      toaster.show(e.mensaje, error: true);
    } catch (e) {
      toaster.show('No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.', error: true);
    }
  }

  /// Pasa lo entendido al formulario completo para ajustar los detalles.
  void _editar() {
    final f = _elegido;
    final r = _resultado;
    if (f == null && r == null) return;
    final padre = Navigator.of(context, rootNavigator: true).context;
    _texto.clear();
    final monto = parseMonto(_monto.text);
    final cuenta = f == null ? null : _cuentaDe(f);
    Navigator.pop(context);
    if (f != null) {
      abrirTransaccion(padre, fecha: _fecha, tipo: f.clase == ClaseFrecuente.ingreso ? 'ingreso' : 'gasto', monto: monto, descripcion: f.titulo, categoria: f.categoria, cuentaId: cuenta?.id);
      return;
    }
    abrirTransaccion(padre, fecha: r!.fecha, tipo: r.ingreso ? 'ingreso' : 'gasto', monto: r.monto, descripcion: r.descripcion, categoria: _categoriaDe(r));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = _resultado;
    final f = _elegido;
    final frecuentes = ref.watch(frecuentesProvider);
    ref.watch(modulosActivosProvider);
    final lista = _visibles(frecuentes.value ?? const []);
    final escrito = normalizarRegistro(r?.descripcion ?? _texto.text);
    final parecidos = escrito.length < 2 ? const <Frecuente>[] : lista.where((x) => normalizarRegistro(x.titulo).contains(escrito)).take(3).toList();
    return SheetScaffold(
      title: 'Registrar rápido',
      subtitle: f == null ? 'Escribe o di un gasto o un ingreso' : 'Revisa y guarda',
      icon: Icons.bolt_rounded,
      primaryLabel: 'Guardar',
      onPrimary: _puedeGuardar ? _guardar : null,
      hayCambios: () => _texto.text.trim().isNotEmpty || (f != null && _monto.text != montoInicial(f.monto)),
      secondary: f == null && r == null ? null : OutlinedButton(onPressed: _editar, child: const Text('Editar')),
      children: [
        if (f == null) ...[
          TextField(
            controller: _texto,
            focusNode: _foco,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_resultado != null) _guardar();
            },
            decoration: InputDecoration(
              hintText: _escuchando ? 'Te escucho…' : 'Ej.: almuerzo 25 mil',
              helperText: r == null && !_escuchando && _texto.text.trim().isNotEmpty ? 'Falta el monto. Por ejemplo: taxi 15 mil' : null,
              suffixIcon: Semantics(
                liveRegion: true,
                child: IconButton(
                  tooltip: _escuchando ? 'Dejar de escuchar' : 'Dictar',
                  onPressed: _alternarVoz,
                  icon: Icon(_escuchando ? Icons.stop_circle_rounded : Icons.mic_rounded, color: _escuchando ? p.danger : p.accent),
                ),
              ),
            ),
          ),
          const VGap.md(),
        ],
        SmoothSwitcher(
          child: f != null
              ? _FrecuenteElegido(
                  key: ValueKey(f.clave),
                  frecuente: f,
                  cuenta: _cuentaDe(f),
                  monto: _monto,
                  fecha: _fecha,
                  alCambiarFecha: (v) => setState(() => _fecha = v),
                  alQuitar: () => setState(() => _elegido = null),
                )
              : r != null
                  ? _VistaPrevia(key: const ValueKey('vista'), resultado: r, categoria: _categoriaDe(r))
                  : frecuentes.isLoading && !frecuentes.hasValue
                      ? const _FrecuentesCargando(key: ValueKey('cargando'))
                      : parecidos.isNotEmpty
                          ? _ListaFrecuentes(key: const ValueKey('parecidos'), titulo: '¿Es uno de estos?', lista: parecidos, alElegir: _elegir)
                          : lista.isNotEmpty
                              ? _ListaFrecuentes(key: const ValueKey('frecuentes'), titulo: 'Lo que más registras', subtitulo: 'Toca uno para repetirlo', lista: lista, alElegir: _elegir)
                              : Wrap(
                                  key: const ValueKey('ejemplos'),
                                  spacing: Gap.xs,
                                  runSpacing: Gap.xs,
                                  children: [
                                    for (final e in _ejemplos) ActionChip(label: Text(e), onPressed: () => _fijar(e)),
                                  ],
                                ),
        ),
        if (f == null && r != null && parecidos.isNotEmpty) ...[
          const VGap.md(),
          _ListaFrecuentes(titulo: '¿Es uno de estos?', lista: parecidos, alElegir: _elegir),
        ],
      ],
    );
  }
}

/// Reserva el lugar de la lista mientras llega la primera vez.
class _FrecuentesCargando extends StatelessWidget {
  const _FrecuentesCargando({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: Gap.xs), child: Esqueleto(alto: 56, radio: Radii.md)),
      ]);
}

({IconData icono, Color color, String categoria}) _aspecto(BuildContext context, Frecuente f, List<CategoriaFinanzas> categorias) {
  if (f.clase == ClaseFrecuente.ingreso) return (icono: Icons.north_east_rounded, color: context.palette.success, categoria: 'Ingreso');
  final c = categorias.where((x) => x.valor == f.categoria).firstOrNull;
  return (icono: iconoPorNombre(c?.icono), color: colorCategoria(context, f.categoria), categoria: c?.label ?? 'Otros');
}

class _ListaFrecuentes extends ConsumerWidget {
  const _ListaFrecuentes({super.key, required this.titulo, this.subtitulo, required this.lista, required this.alElegir});
  final String titulo;
  final String? subtitulo;
  final List<Frecuente> lista;
  final ValueChanged<Frecuente> alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(titulo, subtitle: subtitulo),
      for (final (i, f) in lista.indexed) ...[
        if (i > 0) const SizedBox(height: Gap.xs),
        _FilaFrecuente(frecuente: f, categorias: categorias, alElegir: alElegir),
      ],
    ]);
  }
}

class _FilaFrecuente extends StatelessWidget {
  const _FilaFrecuente({required this.frecuente, required this.categorias, required this.alElegir});
  final Frecuente frecuente;
  final List<CategoriaFinanzas> categorias;
  final ValueChanged<Frecuente> alElegir;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = frecuente;
    final a = _aspecto(context, f, categorias);
    final ingreso = f.clase == ClaseFrecuente.ingreso;
    final detalle = '${a.categoria} · ${f.veces} veces';
    final valor = f.monto > 0 ? '${ingreso ? '+' : ''}${cop(f.monto)}' : null;
    return Pressable(
      onTap: () => alElegir(f),
      borderRadius: Radii.rMd,
      semanticLabel: '${f.titulo}, $detalle${valor == null ? '' : ', $valor'}. Toca para revisarlo y guardarlo.',
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
        decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd),
        child: Row(children: [
          IconBadge(a.icono, color: a.color, size: 40),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              Text(detalle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            ]),
          ),
          if (valor != null) ...[
            const HGap.sm(),
            Text(valor, style: context.text.titleSmall?.copyWith(color: ingreso ? p.success : null, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ]),
      ),
    );
  }
}

/// Lo elegido de la lista, listo para guardar: normalmente solo cambia el monto o el día.
class _FrecuenteElegido extends ConsumerWidget {
  const _FrecuenteElegido({super.key, required this.frecuente, required this.cuenta, required this.monto, required this.fecha, required this.alCambiarFecha, required this.alQuitar});
  final Frecuente frecuente;
  final Cuenta? cuenta;
  final TextEditingController monto;
  final String fecha;
  final ValueChanged<String> alCambiarFecha;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final f = frecuente;
    final a = _aspecto(context, f, ref.watch(categoriasFinProvider).value ?? const []);
    final hoy = hoyYmd();
    final ayer = sumarDiasYmd(hoy, -1);
    final otra = fecha != hoy && fecha != ayer;
    final tarjeta = cuenta != null && esCredito(cuenta!.tipo);
    final detalle = [
      a.categoria,
      cuenta?.nombre ?? 'Sin cuenta',
      if (tarjeta && f.clase == ClaseFrecuente.gasto && f.cuotas > 1) '${f.cuotas} cuotas',
    ].join(' · ');

    Widget dia(String etiqueta, bool activo, VoidCallback alTocar, {IconData? icono}) => ChoiceChip(
          label: Text(etiqueta),
          selected: activo,
          avatar: icono == null || activo ? null : Icon(icono, size: IconSizes.sm),
          onSelected: (_) => alTocar(),
        );

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(a.icono, color: a.color, size: 44),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              Text(detalle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            ]),
          ),
          TextButton(onPressed: alQuitar, child: const Text('Cambiar')),
        ]),
        const VGap.md(),
        MoneyField(controller: monto, label: 'Monto', big: true),
        const VGap.sm(),
        Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
          dia('Hoy', fecha == hoy, () => alCambiarFecha(hoy)),
          dia('Ayer', fecha == ayer, () => alCambiarFecha(ayer)),
          dia(otra ? fechaConDia(fecha) : 'Otro día', otra, () async {
            final d = await showDatePicker(context: context, initialDate: parseYmd(fecha), firstDate: DateTime(2000), lastDate: DateTime(2100), locale: const Locale('es', 'CO'));
            if (d != null) alCambiarFecha(ymd(d));
          }, icono: Icons.calendar_today_rounded),
        ]),
      ]),
    );
  }
}

/// Lo que la app entendió, antes de guardarlo.
class _VistaPrevia extends ConsumerWidget {
  const _VistaPrevia({super.key, required this.resultado, this.categoria});
  final MovimientoCapturado resultado;
  final String? categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final categorias = ref.watch(categoriasFinProvider).value ?? const [];
    final m = resultado;
    final icono = m.ingreso ? Icons.north_east_rounded : Icons.south_east_rounded;
    final color = m.ingreso ? p.success : p.danger;
    final tipo = m.ingreso ? 'Ingreso' : 'Gasto';
    final titulo = cop(m.monto);
    final detalle = [
      m.descripcion,
      if (!m.ingreso) categorias.where((c) => c.valor == categoria).firstOrNull?.label ?? 'Otros',
      fechaRelativa(m.fecha),
    ].join(' · ');
    return Semantics(
      liveRegion: true,
      label: 'Se guardará como $tipo: $titulo. $detalle',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd),
        child: Row(children: [
          IconBadge(icono, color: color, size: 44),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tag(tipo, color: color),
              const SizedBox(height: Gap.xxs),
              Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              Text(detalle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}
