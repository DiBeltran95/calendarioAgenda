import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import '../events/event_categories.dart';
import '../events/events_repository.dart';
import '../events/widgets/event_form_sheet.dart';
import '../finance/finance_providers.dart';
import '../finance/finance_repository.dart';
import '../finance/pagos/pagos_logica.dart';
import '../finance/pagos/pagos_repository.dart';
import '../finance/sheets/transaction_sheet.dart';
import 'interprete.dart';
import 'voz.dart';

Future<void> abrirCaptura(BuildContext context, {bool escuchar = false}) => showAppSheet(context, (_) => CapturaSheet(escuchar: escuchar));

/// Registrar algo escribiéndolo o diciéndolo como se le contaría a alguien.
class CapturaSheet extends ConsumerStatefulWidget {
  const CapturaSheet({super.key, this.escuchar = false});

  /// Abre directamente con el micrófono encendido.
  final bool escuchar;

  @override
  ConsumerState<CapturaSheet> createState() => _CapturaSheetState();
}

class _CapturaSheetState extends ConsumerState<CapturaSheet> {
  final _texto = TextEditingController();
  bool _escuchando = false;

  static const _ejemplos = ['almuerzo 25 mil', 'me pagaron 2 millones', 'cita con Ana mañana 3pm', 'cumpleaños de mamá 12 de marzo'];

  Interpretacion? get _resultado => interpretarFrase(_texto.text, DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.escuchar) WidgetsBinding.instance.addPostFrameCallback((_) => _alternarVoz());
  }

  @override
  void dispose() {
    if (_escuchando) ref.read(reconocedorVozProvider).detener();
    _texto.dispose();
    super.dispose();
  }

  void _fijar(String v) {
    _texto.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    setState(() {});
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
    final r = _resultado;
    if (r == null) return;
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    try {
      final String aviso;
      switch (r) {
        case MovimientoCapturado m:
          await ref.read(financeRepoProvider).crearTransaccion(TransaccionInput(
                tipo: m.ingreso ? 'ingreso' : 'gasto',
                monto: m.monto,
                descripcion: m.descripcion,
                fecha: m.fecha,
                categoria: _categoriaDe(m),
              ));
          aviso = '${m.ingreso ? 'Ingreso' : 'Gasto'} guardado: ${cop(m.monto)}';
        case EventoCapturado e:
          await ref.read(eventsRepoProvider).crear(EventoInput(
                titulo: e.titulo,
                fecha: e.fecha,
                hora: e.hora,
                categoria: e.categoria,
                costo: e.monto ?? 0,
                tipoTransaccion: e.monto == null ? 'ninguno' : 'gasto',
              ));
          aviso = 'Evento guardado: ${e.titulo}';
        case CumpleCapturado c:
          await ref.read(eventsRepoProvider).crearCumple(CumpleInput(nombre: c.nombre, fecha: c.fecha));
          aviso = 'Cumpleaños guardado: ${c.nombre}';
      }
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
    final r = _resultado;
    if (r == null) return;
    final padre = Navigator.of(context, rootNavigator: true).context;
    _texto.clear();
    Navigator.pop(context);
    switch (r) {
      case MovimientoCapturado m:
        abrirTransaccion(padre, fecha: m.fecha, tipo: m.ingreso ? 'ingreso' : 'gasto', monto: m.monto, descripcion: m.descripcion, categoria: _categoriaDe(m));
      case EventoCapturado e:
        abrirFormularioEvento(padre, fecha: e.fecha, categoriaInicial: e.categoria, tituloInicial: e.titulo, horaInicial: e.hora, montoInicial: e.monto);
      case CumpleCapturado c:
        abrirFormularioEvento(padre, fecha: c.fecha, categoriaInicial: 'cumpleanos', tituloInicial: c.nombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = _resultado;
    return SheetScaffold(
      title: 'Registrar rápido',
      subtitle: 'Escríbelo o dilo como se lo contarías a alguien',
      icon: Icons.bolt_rounded,
      primaryLabel: 'Guardar',
      onPrimary: r == null ? null : _guardar,
      hayCambios: () => _texto.text.trim().isNotEmpty,
      secondary: r == null ? null : OutlinedButton(onPressed: _editar, child: const Text('Editar')),
      children: [
        TextField(
          controller: _texto,
          autofocus: !widget.escuchar,
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
        SmoothSwitcher(
          child: r == null
              ? Wrap(
                  key: const ValueKey('ejemplos'),
                  spacing: Gap.xs,
                  runSpacing: Gap.xs,
                  children: [
                    for (final e in _ejemplos) ActionChip(label: Text(e), onPressed: () => _fijar(e)),
                  ],
                )
              : _VistaPrevia(key: ValueKey(r.runtimeType), resultado: r, categoria: r is MovimientoCapturado ? _categoriaDe(r) : null),
        ),
      ],
    );
  }
}

/// Lo que la app entendió, antes de guardarlo.
class _VistaPrevia extends ConsumerWidget {
  const _VistaPrevia({super.key, required this.resultado, this.categoria});
  final Interpretacion resultado;
  final String? categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final categorias = ref.watch(categoriasFinProvider).value ?? const [];
    final (IconData icono, Color color, String tipo, String titulo, String detalle) = switch (resultado) {
      MovimientoCapturado m => (
          m.ingreso ? Icons.north_east_rounded : Icons.south_east_rounded,
          m.ingreso ? p.success : p.danger,
          m.ingreso ? 'Ingreso' : 'Gasto',
          cop(m.monto),
          [
            m.descripcion,
            if (!m.ingreso) categorias.where((c) => c.valor == categoria).firstOrNull?.label ?? 'Otros',
            fechaRelativa(m.fecha),
          ].join(' · '),
        ),
      EventoCapturado e => (
          categoriaEvento(e.categoria).icon,
          categoriaEvento(e.categoria).colorDe(context),
          'Evento',
          e.titulo,
          [fechaRelativa(e.fecha), e.hora == null ? 'Todo el día' : hora12(e.hora), if (e.monto != null) cop(e.monto!)].join(' · '),
        ),
      CumpleCapturado c => (Icons.cake_rounded, categoriaEvento('cumpleanos').colorDe(context), 'Cumpleaños', c.nombre, fechaConDia(c.fecha)),
    };
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
