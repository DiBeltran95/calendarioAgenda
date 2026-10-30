import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/icon_map.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/net/api_client.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models.dart';
import '../finance_providers.dart';
import '../finance_repository.dart' show FinanzasError;
import '../sheets/transaction_sheet.dart';
import 'lector_pagos.dart';
import 'pagos_logica.dart';
import 'pagos_repository.dart';

/// Bandeja "Pagos por clasificar": lo que se pagó con Apple Pay o lo que
/// avisaron los bancos, listo para guardarlo con un toque.
class PagosScreen extends ConsumerStatefulWidget {
  const PagosScreen({super.key});

  @override
  ConsumerState<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends ConsumerState<PagosScreen> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    // Al volver de Ajustes (permiso) o del banco, se revisa de nuevo.
    _ciclo = AppLifecycleListener(onResume: _refrescar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refrescar());
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    if (!mounted) return;
    ref.invalidate(accesoAvisosPagosProvider);
    await ref.read(pagosRepoProvider).sincronizarAndroid();
    if (mounted) await ref.read(pagosPendientesProvider.notifier).refrescar();
  }

  Future<void> _guardarTodos(List<CapturaPago> pagos) async {
    final toaster = Toaster.of(context);
    final prefs = ref.read(preferenciasPagosProvider).value ?? const [];
    final cats = ref.read(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final cuentas = ref.read(cuentasProvider).value ?? const <Cuenta>[];
    var ok = 0;
    for (final c in pagos) {
      try {
        await ref.read(pagosRepoProvider).registrar(c, categoria: sugerirCategoria(c, prefs, cats), cuentaId: sugerirCuenta(c, prefs, cuentas));
        ok++;
      } catch (_) {}
    }
    HapticFeedback.mediumImpact();
    toaster.show(ok == pagos.length ? '$ok pagos registrados' : 'Se registraron $ok de ${pagos.length}. Revisa los demás.', error: ok != pagos.length);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pagosPendientesProvider);
    final pagos = async.value ?? const <CapturaPago>[];
    final total = pagos.fold<double>(0, (s, c) => s + (c.tipo == 'gasto' ? c.monto : 0));

    return Scaffold(
      appBar: barraPantalla(context, 'Pagos por clasificar'),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xxxl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Entrance(child: _Configuracion()),
                  const VGap.lg(),
                  if (async.isLoading && !async.hasValue)
                    const Padding(padding: EdgeInsets.all(Gap.xl), child: Center(child: CircularProgressIndicator()))
                  else if (pagos.isEmpty)
                    const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Todo clasificado',
                      message: 'Cuando pagues con el celular, el pago aparecerá aquí para asignarle una categoría.',
                    )
                  else ...[
                    Row(children: [
                      Expanded(
                        child: Text(
                          pagos.length == 1 ? '1 pago pendiente' : '${pagos.length} pagos pendientes',
                          style: context.text.titleMedium,
                        ),
                      ),
                      if (total > 0) Text(cop(total), style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ]),
                    if (pagos.length > 1) ...[
                      const VGap.xs(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _guardarTodos(pagos),
                          icon: const Icon(Icons.done_all_rounded),
                          label: const Text('Guardar todos con la categoría sugerida'),
                        ),
                      ),
                    ],
                    const VGap.xs(),
                    for (final (i, c) in pagos.indexed)
                      Entrance(index: i, child: _TarjetaPago(key: ValueKey(c.id), pago: c)),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Configuración ───────────────────────

class _Configuracion extends ConsumerWidget {
  const _Configuracion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final lector = ref.watch(lectorPagosProvider);
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (lector.soportado) {
      final acceso = ref.watch(accesoAvisosPagosProvider).value ?? false;
      return AppCard(
        borderColor: acceso ? p.success.withValues(alpha: 0.45) : p.accent.withValues(alpha: 0.45),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(acceso ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: acceso ? p.success : p.accent),
            const HGap.sm(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(acceso ? 'Lectura de pagos activa' : 'Registra tus pagos sin escribirlos', style: context.text.titleSmall),
                Text(
                  acceso
                      ? 'Google Wallet, Bancolombia, Nequi, Davivienda, DaviPlata, BBVA, Banco de Bogotá, Nu y SMS de bancos.'
                      : 'Agendaservi lee los avisos de compra de Google Wallet, tus bancos y sus SMS. Nada más: el resto de notificaciones se ignora.',
                  style: context.text.bodySmall,
                ),
              ]),
            ),
          ]),
          if (!acceso) ...[
            const VGap.sm(),
            FilledButton.icon(
              onPressed: () => ref.read(lectorPagosProvider).abrirAjustes(),
              icon: const Icon(Icons.toggle_on_rounded),
              label: const Text('Permitir acceso a notificaciones'),
            ),
            const VGap.xs(),
            Text('Busca "Agendaservi · pagos" en la lista y actívalo.', style: context.text.labelSmall),
          ],
        ]),
      );
    }

    if (ios) {
      final clave = ref.watch(claveAtajoProvider).value;
      final activo = clave?.usado != null;
      return AppCard(
        onTap: () => showAppSheet(context, (_) => const GuiaAtajoSheet()),
        semanticLabel: 'Configurar Apple Pay con Atajos',
        borderColor: activo ? p.success.withValues(alpha: 0.45) : p.accent.withValues(alpha: 0.45),
        child: Row(children: [
          IconBadge(Icons.contactless_rounded, color: activo ? p.success : p.accent),
          const HGap.sm(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activo ? 'Apple Pay conectado' : 'Conecta Apple Pay en 2 minutos', style: context.text.titleSmall),
              Text(
                activo ? 'Último pago recibido ${_haceCuanto(clave!.usado!)}. Toca para ver la configuración.' : 'Con la app Atajos, cada pago con tu iPhone llega aquí solo.',
                style: context.text.bodySmall,
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}

String _haceCuanto(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  return fechaRelativa(ymd(t.toLocal())).toLowerCase();
}

// ─────────────────────── Un pago ───────────────────────

class _TarjetaPago extends ConsumerStatefulWidget {
  const _TarjetaPago({super.key, required this.pago});
  final CapturaPago pago;

  @override
  ConsumerState<_TarjetaPago> createState() => _TarjetaPagoState();
}

class _TarjetaPagoState extends ConsumerState<_TarjetaPago> {
  String? _categoria;
  int? _cuentaId;
  bool _cuentaElegida = false;
  bool _guardando = false;

  CapturaPago get c => widget.pago;

  Future<void> _guardar(String categoria, int? cuentaId) async {
    setState(() => _guardando = true);
    final toaster = Toaster.of(context);
    try {
      await ref.read(pagosRepoProvider).registrar(c, categoria: categoria, cuentaId: cuentaId);
      HapticFeedback.mediumImpact();
      toaster.show('${c.tipo == 'gasto' ? 'Gasto' : 'Ingreso'} de ${cop(c.monto)} registrado', icon: Icons.check_circle_rounded);
    } on FinanzasError catch (e) {
      toaster.show(e.mensaje, error: true);
      if (mounted) setState(() => _guardando = false);
    } catch (_) {
      toaster.show('No se pudo registrar. Revisa tu conexión.', error: true);
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _descartar() async {
    final toaster = Toaster.of(context);
    final repo = ref.read(pagosRepoProvider);
    try {
      await repo.descartar(c);
      toaster.show('Pago descartado', onUndo: () => repo.deshacerDescarte(c));
    } catch (_) {
      toaster.show('No se pudo descartar', error: true);
    }
  }

  void _editar(String categoria, int? cuentaId) {
    abrirTransaccion(
      context,
      fecha: ymd(c.fecha.toLocal()),
      tipo: c.tipo,
      categoria: categoria,
      descripcion: c.titulo,
      monto: c.monto,
      cuentaId: cuentaId,
      alCrear: (id, input) => ref.read(pagosRepoProvider).marcarRegistrado(c, transaccionId: id, categoria: input.categoria, cuentaId: input.cuentaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prefs = ref.watch(preferenciasPagosProvider).value ?? const <PreferenciaPago>[];
    final cats = ref.watch(categoriasFinProvider).value ?? const <CategoriaFinanzas>[];
    final cuentas = ref.watch(cuentasProvider).value ?? const <Cuenta>[];
    final sugerida = sugerirCategoria(c, prefs, cats);
    final categoria = _categoria ?? sugerida;
    final cuentaId = _cuentaElegida ? _cuentaId : sugerirCuenta(c, prefs, cuentas);
    final cuenta = cuentas.where((x) => x.id == cuentaId).firstOrNull;
    final ingreso = c.tipo == 'ingreso';
    final local = c.fecha.toLocal();
    final hora = hora12('${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
    final fuente = c.origen == 'apple_pay' ? 'Apple Pay' : c.app;

    // Categorías: la sugerida primero.
    final orden = [...cats]..sort((a, b) => (a.valor == categoria ? 0 : 1).compareTo(b.valor == categoria ? 0 : 1));

    Widget fondo(Alignment lado, IconData icono, String texto, Color color) => Container(
          alignment: lado,
          margin: const EdgeInsets.only(bottom: Gap.sm),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: Radii.rLg),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, color: color),
            const HGap.xs(),
            Text(texto, style: context.text.labelLarge?.copyWith(color: color)),
          ]),
        );

    return Dismissible(
      key: ValueKey('pago-${c.id}'),
      background: fondo(Alignment.centerLeft, Icons.check_rounded, 'Guardar', p.success),
      secondaryBackground: fondo(Alignment.centerRight, Icons.close_rounded, 'Descartar', p.danger),
      // La tarjeta sale de la lista cuando el servidor confirma, no antes.
      confirmDismiss: (lado) async {
        if (_guardando) return false;
        if (lado == DismissDirection.startToEnd) {
          await _guardar(categoria, cuentaId);
        } else {
          await _descartar();
        }
        return false;
      },
      child: Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            borderRadius: Radii.rMd,
            onTap: () => _editar(categoria, cuentaId),
            child: Row(children: [
              IconBadge(c.origen == 'apple_pay' ? Icons.contactless_rounded : Icons.account_balance_rounded, color: ingreso ? p.success : p.accent),
              const HGap.sm(),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.titulo, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [fechaRelativa(ymd(local)), hora, fuente, if (c.tarjeta.isNotEmpty) c.tarjeta].join(' · '),
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              const HGap.xs(),
              Text(
                '${ingreso ? '+' : '−'}${cop(c.monto)}',
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: ingreso ? p.success : p.text, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ]),
          ),
          const VGap.sm(),
          // Categoría con un toque.
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: orden.length,
              separatorBuilder: (_, _) => const HGap.xs(),
              itemBuilder: (context, i) {
                final cat = orden[i];
                final sel = cat.valor == categoria;
                return ChoiceChip(
                  selected: sel,
                  showCheckmark: false,
                  avatar: Icon(iconoPorNombre(cat.icono), size: IconSizes.sm, color: sel ? p.onAccent : p.textSecondary),
                  label: Text(cat.valor == sugerida && _categoria == null ? '${cat.label} · sugerida' : cat.label),
                  labelStyle: TextStyle(color: sel ? p.onAccent : p.text),
                  selectedColor: p.accent,
                  onSelected: _guardando
                      ? null
                      : (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _categoria = cat.valor);
                        },
                );
              },
            ),
          ),
          const VGap.xs(),
          Row(children: [
            if (cuentas.isNotEmpty)
              Flexible(
                child: PopupMenuButton<int?>(
                  tooltip: 'Cuenta o tarjeta',
                  initialValue: cuentaId,
                  onSelected: (v) => setState(() {
                    _cuentaElegida = true;
                    _cuentaId = v == -1 ? null : v;
                  }),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: -1, child: Text('Sin cuenta')),
                    for (final x in cuentas) PopupMenuItem(value: x.id, child: Text(x.nombre)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_balance_wallet_rounded, size: IconSizes.sm, color: p.textSecondary),
                      const HGap(Gap.xxs),
                      Flexible(child: Text(cuenta?.nombre ?? 'Sin cuenta', style: context.text.labelLarge, overflow: TextOverflow.ellipsis)),
                      Icon(Icons.arrow_drop_down_rounded, color: p.textSecondary),
                    ]),
                  ),
                ),
              )
            else
              const Spacer(),
            if (cuentas.isNotEmpty) const Spacer(),
            TextButton(onPressed: _guardando ? null : _descartar, child: const Text('Descartar')),
            const HGap.xs(),
            FilledButton(
              onPressed: _guardando ? null : () => _guardar(categoria, cuentaId),
              child: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
            ),
          ]),
        ]),
      ),
      ),
    );
  }
}

// ─────────────────────── Guía del Atajo (iPhone) ───────────────────────

class GuiaAtajoSheet extends ConsumerWidget {
  const GuiaAtajoSheet({super.key});

  static const url = '${ApiClient.defaultBaseUrl}/api/capturas/atajo';
  static const enlaceApp = 'agendaservi://app/finanzas/pagos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = ref.watch(claveAtajoProvider);
    final k = clave.value?.clave;
    var n = 0;
    Widget paso(String titulo, [String? detalle, Widget? extra]) {
      n++;
      return _Paso(numero: n, titulo: titulo, detalle: detalle, extra: extra);
    }

    return SheetScaffold(
      title: 'Apple Pay → Agendaservi',
      subtitle: 'Se configura una sola vez en la app Atajos (iOS 17 o superior).',
      icon: Icons.contactless_rounded,
      children: [
        paso('Abre Atajos → Automatización → +', 'Elige "Crear automatización personal" si te lo pregunta.'),
        paso('Elige "Transacción"', 'Marca tus tarjetas de Wallet, deja todas las categorías y selecciona "Ejecutar inmediatamente". Toca Siguiente.'),
        paso('Nueva automatización en blanco → Agregar acción', 'Busca y agrega "Obtener contenido de URL".'),
        paso('Pega esta URL', null, _Copiar(valor: url, etiqueta: 'URL')),
        paso(
          'Toca la flecha de la acción y configura',
          'Método: POST. En Encabezados agrega uno llamado X-Clave con tu clave. En Cuerpo de la solicitud elige JSON y agrega tres campos de texto: '
              'monto → variable Importe, comercio → Comerciante, tarjeta → Tarjeta (toca el campo y elige la variable de la transacción).',
          k == null ? const LinearProgressIndicator() : _Copiar(valor: k, etiqueta: 'Clave X-Clave', secreta: true),
        ),
        paso('Opcional: clasificar al momento', 'Agrega la acción "Abrir URL" con este enlace para que la app se abra justo después de pagar.', const _Copiar(valor: enlaceApp, etiqueta: 'Enlace')),
        paso('Listo', 'Tu próximo pago con Apple Pay aparecerá en "Pagos por clasificar".'),
        const VGap.sm(),
        if (clave.value?.usado != null)
          Tag('Funcionando · último pago ${_haceCuanto(clave.value!.usado!)}', color: context.palette.success, icon: Icons.check_circle_rounded)
        else
          Text('Mientras no llegue el primer pago, esta guía seguirá aquí.', style: context.text.bodySmall),
        const VGap.sm(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await confirmar(
                context,
                titulo: '¿Generar una clave nueva?',
                mensaje: 'La clave actual dejará de funcionar y tendrás que pegar la nueva en el atajo.',
                confirmar: 'Generar',
              );
              if (ok) await ref.read(pagosRepoProvider).nuevaClave();
            },
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('Generar una clave nueva'),
          ),
        ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.titulo, this.detalle, this.extra});
  final int numero;
  final String titulo;
  final String? detalle;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Text('$numero', style: context.text.labelLarge?.copyWith(color: p.accent, fontWeight: FontWeight.w800)),
        ),
        const HGap.sm(),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: context.text.titleSmall),
            if (detalle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(detalle!, style: context.text.bodySmall)),
            if (extra != null) Padding(padding: const EdgeInsets.only(top: Gap.xs), child: extra),
          ]),
        ),
      ]),
    );
  }
}

class _Copiar extends StatelessWidget {
  const _Copiar({required this.valor, required this.etiqueta, this.secreta = false});
  final String valor;
  final String etiqueta;
  final bool secreta;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = secreta ? '${valor.substring(0, 6)}••••••••${valor.substring(valor.length - 4)}' : valor;
    return Material(
      color: p.surfaceHigh,
      borderRadius: Radii.rMd,
      child: InkWell(
        borderRadius: Radii.rMd,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: valor));
          HapticFeedback.selectionClick();
          if (context.mounted) Toaster.of(context).show('$etiqueta copiada', icon: Icons.copy_rounded);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.xs, Gap.xs),
          child: Row(children: [
            Expanded(child: Text(visible, style: context.text.bodySmall?.copyWith(fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis)),
            const HGap.xs(),
            Icon(Icons.copy_rounded, size: IconSizes.md, color: p.accent),
            const HGap.xs(),
            Text('Copiar', style: context.text.labelLarge?.copyWith(color: p.accent)),
          ]),
        ),
      ),
    );
  }
}
