import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/bento.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models.dart';
import '../finance_logic.dart';
import '../finance_providers.dart';
import '../finance_repository.dart';
import '../inversiones/inversion_sheets.dart';
import '../inversiones/inversiones_logica.dart';
import '../inversiones/inversiones_repository.dart';
import '../prestamos/prestamo_sheets.dart';
import '../prestamos/prestamos_logica.dart';
import '../prestamos/prestamos_repository.dart';
import '../sheets/finance_sheets.dart';

/// Tu dinero, ordenado por lo que es: lo disponible, lo que debes, lo invertido y
/// lo que te deben. Las tarjetas de color son dinero tuyo o de tu banco; las claras,
/// dinero en manos de otra persona.
class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key, required this.cuentas, required this.mes});
  final List<Cuenta> cuentas;
  final DateTime mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inversiones = ref.watch(inversionesProvider).value ?? const <Inversion>[];
    final prestamos = ref.watch(prestamosProvider).value ?? const <Prestamo>[];
    final ahora = DateTime.now();
    final txHoy = ref.watch(txMesProvider((ahora.year, ahora.month))).value ?? const <Transaccion>[];

    final disponibles = cuentas.where((c) => !esCredito(c.tipo) && c.tipo != 'cdt').toList();
    final creditos = cuentas.where((c) => esCredito(c.tipo)).toList();
    final cdts = cuentas.where((c) => c.tipo == 'cdt').toList();
    final dolares = inversiones.where((i) => i.esDolares && !i.vendida).toList();
    final otras = inversiones.where((i) => !i.esDolares && !i.vendida).toList();
    final vacio = cuentas.isEmpty && dolares.isEmpty && otras.isEmpty && prestamos.isEmpty;
    double gano(Cuenta c) => gananciaDelMes(txHoy, c.id);

    final totalDisponible = disponibles.fold(0.0, (s, c) => s + c.saldo);
    final totalDeuda = creditos.fold(0.0, (s, c) => s + c.saldo);
    final totalInvertido = cdts.fold(0.0, (s, c) => s + c.saldo) + valorTotalInversiones([...dolares, ...otras]);
    var i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Acciones(puedeTransferir: cuentas.length >= 2),
        const VGap.lg(),
        if (vacio)
          const EmptyState(
            icon: Icons.account_balance_rounded,
            title: 'Aún no tienes cuentas',
            message: 'Agrega tus cuentas, tarjetas y efectivo, los dólares que compres o lo que le prestes a alguien, para verlo todo al día.',
          ),
        if (disponibles.isNotEmpty) ...[
          _Seccion('Efectivo y bancos', subtitulo: _cantidad(disponibles.length, 'cuenta', 'cuentas'), valor: cop(totalDisponible)),
          BentoGrid(celdas: [
            for (final (k, c) in disponibles.indexed)
              CeldaBento(
                Entrance(index: i++, child: _TarjetaSaldo(cuenta: c, ganadoMes: gano(c))),
                // La última, si queda sola, ocupa toda la fila.
                ancha: disponibles.length.isOdd && k == disponibles.length - 1,
              ),
          ]),
          const VGap.lg(),
        ],
        if (creditos.isNotEmpty) ...[
          _Seccion('Tarjetas y créditos', subtitulo: 'Lo que debes hoy', valor: cop(totalDeuda)),
          for (final c in creditos)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Entrance(index: i++, child: _TarjetaCredito(cuenta: c)),
            ),
          const VGap.sm(),
        ],
        if (dolares.isNotEmpty || cdts.isNotEmpty || otras.isNotEmpty) ...[
          _Seccion('Inversiones', subtitulo: 'Lo que vale hoy', valor: cop(totalInvertido)),
          for (final d in dolares)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Entrance(index: i++, child: _TarjetaDolares(inversion: d)),
            ),
          for (final c in cdts)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Entrance(index: i++, child: _TarjetaCdt(cuenta: c, ganadoMes: gano(c))),
            ),
          if (otras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: _FilaOtrasInversiones(inversiones: otras),
            ),
          const VGap.sm(),
        ],
        if (prestamos.isNotEmpty) ...[
          _Prestamos(prestamos: prestamos),
          const VGap.lg(),
        ],
        if (cuentas.length >= 2) _Transferencias(mes: mes, cuentas: cuentas),
      ],
    );
  }
}

String _cantidad(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// Un monto dentro de una frase: el signo no se separa del número al cambiar de línea.
String _copJunto(num v) => cop(v).replaceAll(' ', '\u00A0');

/// 10,5 y no 10.5.
String _porcentaje(double v) => '${v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'.replaceAll('.', ',')}%';

/// Título de un grupo con su total a la derecha.
class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo, {this.subtitulo, this.valor});
  final String titulo;
  final String? subtitulo;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      titulo,
      subtitle: subtitulo,
      action: valor == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(valor!, style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
    );
  }
}

// ─────────────────────────── Acciones ───────────────────────────

class _Acciones extends StatelessWidget {
  const _Acciones({required this.puedeTransferir});
  final bool puedeTransferir;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Accion(icono: Icons.add_card_rounded, etiqueta: 'Cuenta', color: p.accent, onTap: () => showAppSheet(context, (_) => const AccountSheet()))),
        if (puedeTransferir) Expanded(child: _Accion(icono: Icons.swap_horiz_rounded, etiqueta: 'Transferir', color: p.info, onTap: () => showAppSheet(context, (_) => const TransferSheet()))),
        Expanded(child: _Accion(icono: Icons.attach_money_rounded, etiqueta: 'Dólares', color: p.gold, onTap: () => showAppSheet(context, (_) => const InversionSheet(tipoInicial: 'dolares')))),
        Expanded(child: _Accion(icono: Icons.handshake_rounded, etiqueta: 'Préstamo', color: p.success, onTap: () => showAppSheet(context, (_) => const PrestamoSheet()))),
      ],
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({required this.icono, required this.etiqueta, required this.color, required this.onTap});
  final IconData icono;
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Agregar: $etiqueta',
      scale: 0.94,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBadge(icono, color: color, size: 52),
          const SizedBox(height: Gap.xxs + 2),
          Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: context.palette.text)),
        ]),
      ),
    );
  }
}

// ─────────────────────────── Tarjetas de color ───────────────────────────

const _blanco = Colors.white;

/// Texto secundario sobre las tarjetas: sigue pasando 4,5:1 en la parte más clara.
final _suave = Colors.white.withValues(alpha: 0.92);

/// Marca de agua de las tarjetas de color.
class _Arcos extends CustomPainter {
  const _Arcos();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = Colors.white.withValues(alpha: 0.07);
    final centro = Offset(size.width, 0);
    canvas.drawCircle(centro, 62, pincel);
    canvas.drawCircle(centro, 108, pincel);
  }

  @override
  bool shouldRepaint(_Arcos oldDelegate) => false;
}

class _TarjetaColor extends StatelessWidget {
  const _TarjetaColor({required this.colores, required this.child, required this.onTap, required this.semantica});
  final List<Color> colores;
  final Widget child;
  final VoidCallback onTap;
  final String semantica;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      semanticLabel: semantica,
      scale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colores),
          borderRadius: Radii.rLg,
          border: Border.all(color: p.bordeTarjeta),
          boxShadow: p.sombraSuave,
        ),
        child: CustomPaint(
          painter: const _Arcos(),
          child: Padding(padding: const EdgeInsets.all(Gap.md), child: child),
        ),
      ),
    );
  }
}

/// Ícono de la tarjeta dentro de su círculo translúcido.
class _IconoTarjeta extends StatelessWidget {
  const _IconoTarjeta(this.icono);
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
      child: Icon(icono, size: IconSizes.md, color: _blanco),
    );
  }
}

/// Monto principal: se reduce antes que cortarse.
class _Monto extends StatelessWidget {
  const _Monto(this.valor, {this.estilo});
  final double valor;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: AnimatedMoney(valor, style: (estilo ?? context.text.headlineMedium)?.copyWith(color: _blanco, fontWeight: FontWeight.w800)),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(color: _suave, letterSpacing: 0)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valor, style: context.text.titleSmall?.copyWith(color: _blanco, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

/// Lo que está ganando la cuenta, o por qué aún no.
class _LineaGanancia extends StatelessWidget {
  const _LineaGanancia({required this.cuenta, required this.ganadoMes});
  final Cuenta cuenta;
  final double ganadoMes;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    final mes = mesesLargos[DateTime.now().month - 1].toLowerCase();
    final texto = !c.generaGanancias
        ? 'Falta la tasa: toca para agregarla'
        : c.gananciasDesde!.compareTo(hoyYmd()) >= 0
            ? 'Empieza a sumar ${c.gananciasDesde == hoyYmd() ? 'mañana' : 'después del ${fechaCorta(c.gananciasDesde!)}'}'
            : [
                '+${_copJunto(rendimientoDiarioCdt(c.saldo, c.gananciasTasa))} al día',
                if (ganadoMes > 0) '+${_copJunto(ganadoMes)} en $mes',
              ].join(' · ');
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(c.generaGanancias ? Icons.trending_up_rounded : Icons.info_outline_rounded, size: IconSizes.sm, color: _blanco),
      ),
      const SizedBox(width: Gap.xxs),
      Expanded(child: Text(texto, style: context.text.labelMedium?.copyWith(color: _blanco))),
    ]);
  }
}

void _abrirCuenta(BuildContext context, Cuenta c) => showAppSheet(context, (_) => AccountSheet(cuenta: c));

/// Cuenta de ahorros, corriente, efectivo u otra: lo que tienes disponible.
class _TarjetaSaldo extends StatelessWidget {
  const _TarjetaSaldo({required this.cuenta, required this.ganadoMes});
  final Cuenta cuenta;
  final double ganadoMes;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    final t = tipoCuenta(c.tipo);
    return _TarjetaColor(
      colores: t.colors,
      onTap: () => _abrirCuenta(context, c),
      semantica: '${c.nombre}, ${t.corto}, saldo ${cop(c.saldo)}${c.tieneGanancias ? ', genera ganancias' : ''}. Abrir cuenta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconoTarjeta(t.icon),
          const VGap.sm(),
          Text(c.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(color: _blanco)),
          Text(t.corto, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(color: _suave, letterSpacing: 0)),
          const VGap.xs(),
          _Monto(c.saldo, estilo: context.text.headlineSmall),
          if (c.tieneGanancias) ...[
            const VGap.xs(),
            _LineaGanancia(cuenta: c, ganadoMes: ganadoMes),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de crédito: cuánto debes, cuánto te queda y cuándo corta.
class _TarjetaCredito extends StatelessWidget {
  const _TarjetaCredito({required this.cuenta});
  final Cuenta cuenta;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    final t = tipoCuenta(c.tipo);
    final uso = c.limite > 0 ? c.saldo / c.limite : 0.0;
    final corte = c.diaCorte == null ? null : siguienteCorte(DateTime.now(), c.diaCorte!);
    final disponible = c.limite > c.saldo ? c.limite - c.saldo : 0.0;
    return _TarjetaColor(
      colores: t.colors,
      onTap: () => _abrirCuenta(context, c),
      semantica: '${c.nombre}, tarjeta de crédito, deuda ${cop(c.saldo)}${c.limite > 0 ? ', disponible ${cop(disponible)}' : ''}. Abrir cuenta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _IconoTarjeta(t.icon),
            const HGap.sm(),
            Expanded(child: Text(c.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(color: _blanco))),
          ]),
          const VGap.md(),
          Text('Deuda actual', style: context.text.labelMedium?.copyWith(color: _suave)),
          _Monto(c.saldo),
          if (c.limite > 0) ...[
            const VGap.sm(),
            ProgressBar(value: uso, color: _blanco, background: Colors.white.withValues(alpha: 0.24), height: 6),
            const SizedBox(height: Gap.xxs),
            Row(children: [
              if (uso > 0.8) ...[const Icon(Icons.warning_amber_rounded, size: IconSizes.sm, color: _blanco), const SizedBox(width: Gap.xxs)],
              Expanded(
                child: Text(
                  '${uso > 0.8 ? 'Uso alto: ' : 'Usas el '}${(uso * 100).toStringAsFixed(0)}% de tu cupo',
                  style: context.text.labelMedium?.copyWith(color: _suave),
                ),
              ),
            ]),
          ],
          if (c.limite > 0 || corte != null) ...[
            const VGap.sm(),
            Row(children: [
              if (c.limite > 0) _Metrica('Disponible', cop(disponible)),
              if (c.limite > 0) _Metrica('Cupo', cop(c.limite)),
              if (corte != null) _Metrica('Próximo corte', fechaCorta(ymd(corte))),
            ]),
          ],
        ],
      ),
    );
  }
}

/// CDT o cajita: cuánto rinde y cuándo vence.
class _TarjetaCdt extends StatelessWidget {
  const _TarjetaCdt({required this.cuenta, required this.ganadoMes});
  final Cuenta cuenta;
  final double ganadoMes;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    final t = tipoCuenta(c.tipo);
    final tasa = c.generaGanancias ? c.gananciasTasa : c.interesTasa;
    final vence = fechaVencimiento(c);
    final faltan = diasRestantesCdt(c);
    return _TarjetaColor(
      colores: t.colors,
      onTap: () => _abrirCuenta(context, c),
      semantica: '${c.nombre}, inversión, saldo ${cop(c.saldo)}, tasa ${_porcentaje(tasa)} efectiva anual. Abrir cuenta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _IconoTarjeta(t.icon),
            const HGap.sm(),
            Expanded(child: Text(c.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(color: _blanco))),
          ]),
          const VGap.md(),
          _Monto(c.saldo),
          const VGap.sm(),
          Row(children: [
            _Metrica('Tasa E.A.', _porcentaje(tasa)),
            _Metrica('Rinde al día', cop(rendimientoDiarioCdt(c.saldo, tasa))),
            // Si la suma sola, el saldo ya trae lo ganado: solo falta lo que queda.
            if (c.plazoDias > 0) _Metrica('Al vencer', '+${cop(rendimientoTotalCdt(c.saldo, tasa, c.tieneGanancias ? faltan : c.plazoDias))}'),
          ]),
          if (vence != null) ...[
            const VGap.sm(),
            ProgressBar(value: progresoCdt(c), color: _blanco, background: Colors.white.withValues(alpha: 0.24), height: 6),
            const SizedBox(height: Gap.xxs),
            Text(
              faltan == 0 ? 'Vencido el ${fechaLarga(vence)}' : 'Vence el ${fechaLarga(vence)} · faltan ${_cantidad(faltan, 'día', 'días')}',
              style: context.text.labelMedium?.copyWith(color: _suave),
            ),
          ],
          if (c.tieneGanancias) ...[
            const VGap.xs(),
            _LineaGanancia(cuenta: c, ganadoMes: ganadoMes),
          ],
        ],
      ),
    );
  }
}

/// Dólares comprados (ARQ y similares): cuántos hay, sin entrar en acciones.
class _TarjetaDolares extends StatelessWidget {
  const _TarjetaDolares({required this.inversion});
  final Inversion inversion;

  @override
  Widget build(BuildContext context) {
    final i = inversion;
    final tasa = i.tasaActual;
    final compras = i.movimientos.where((m) => m.tipo == TipoMovimiento.aporte).toList();
    final g = i.ganancia;
    return _TarjetaColor(
      colores: coloresDolares,
      onTap: () => showAppSheet(context, (_) => InversionDetalleSheet(id: i.id)),
      semantica: '${i.nombre}, ${usd(i.usd)}, equivalen a ${cop(i.valor)}. Abrir detalle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const _IconoTarjeta(Icons.attach_money_rounded),
            const HGap.sm(),
            Expanded(child: Text(i.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(color: _blanco))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 3),
              decoration: BoxDecoration(color: Brand.oroDolares, borderRadius: Radii.rSm),
              child: Text('USD', style: context.text.labelSmall?.copyWith(color: const Color(0xFF1F1500), fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            ),
          ]),
          const VGap.md(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(usd(i.usd), style: context.text.headlineMedium?.copyWith(color: _blanco, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Text(
            tasa == null ? '≈ ${cop(i.valor)}' : '≈ ${cop(i.valor)} con el dólar a ${cop(tasa)}',
            style: context.text.bodySmall?.copyWith(color: _suave),
          ),
          const VGap.sm(),
          Row(children: [
            _Metrica('Pagaste', cop(i.invertido)),
            _Metrica(g >= 0 ? 'Ganancia' : 'Pérdida', copConSigno(g)),
            _Metrica(compras.length == 1 ? 'Compra' : 'Compras', '${compras.length}'),
          ]),
        ],
      ),
    );
  }
}

/// Lo demás que está invertido (ganado, una casa…) vive en su propia pantalla.
class _FilaOtrasInversiones extends StatelessWidget {
  const _FilaOtrasInversiones({required this.inversiones});
  final List<Inversion> inversiones;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = valorTotalInversiones(inversiones);
    return AppCard(
      onTap: () => context.push(rutaInversiones),
      semanticLabel: 'Otras inversiones: ${cop(total)}. Abrir inversiones',
      padding: const EdgeInsets.all(Gap.sm),
      child: Row(children: [
        IconBadge(Icons.category_rounded, color: p.gold, size: 44),
        const HGap.sm(),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Otras inversiones', style: context.text.titleSmall),
            Text(inversiones.map((i) => i.nombre).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
          ]),
        ),
        const HGap.xs(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(cop(total), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: p.textSecondary),
      ]),
    );
  }
}

// ─────────────────────────── Préstamos ───────────────────────────

class _Prestamos extends StatefulWidget {
  const _Prestamos({required this.prestamos});
  final List<Prestamo> prestamos;

  @override
  State<_Prestamos> createState() => _PrestamosState();
}

class _PrestamosState extends State<_Prestamos> {
  bool _verTerminados = false;

  @override
  Widget build(BuildContext context) {
    final activos = widget.prestamos.where((p) => p.activo).toList();
    final terminados = widget.prestamos.where((p) => !p.activo).toList();
    final diaria = activos.fold(0.0, (s, p) => s + p.gananciaDiaria);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Seccion(
          'Préstamos que hiciste',
          subtitulo: diaria > 0 ? 'Te deben · ganas ${cop(diaria)} al día' : 'Te deben',
          valor: cop(porCobrarTotal(activos)),
        ),
        for (final (k, p) in activos.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Entrance(index: k, child: _TarjetaPrestamo(prestamo: p)),
          ),
        if (terminados.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _verTerminados = !_verTerminados),
              icon: Icon(_verTerminados ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text('${_verTerminados ? 'Ocultar' : 'Ver'} terminados (${terminados.length})'),
            ),
          ),
          if (_verTerminados)
            for (final p in terminados)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _TarjetaPrestamo(prestamo: p),
              ),
        ],
      ],
    );
  }
}

class _TarjetaPrestamo extends StatelessWidget {
  const _TarjetaPrestamo({required this.prestamo});
  final Prestamo prestamo;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final p = prestamo;
    final dias = p.diasParaVencer();
    final vencido = p.activo && dias != null && dias < 0;
    final tasa = _porcentaje(p.tasaMensual);
    final estado = p.cerrado
        ? 'Dejaste de cobrar'
        : p.pagado
            ? 'Pagado'
            : vencido
                ? 'Venció hace ${_cantidad(-dias, 'día', 'días')}'
                : dias == null
                    ? null
                    : dias == 0
                        ? 'Vence hoy'
                        : 'Vence en ${_cantidad(dias, 'día', 'días')}';
    return AppCard(
      onTap: () => showAppSheet(context, (_) => PrestamoDetalleSheet(id: p.id)),
      semanticLabel: '${p.persona} te debe ${cop(p.pendiente)}. Le prestaste ${cop(p.prestado)}${p.conInteres ? ' al $tasa mensual' : ', sin intereses'}${estado == null ? '' : '. $estado'}. Abrir préstamo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.success.withValues(alpha: context.isDark ? 0.16 : 0.12), shape: BoxShape.circle),
              child: Text(iniciales(p.persona), style: context.text.titleSmall?.copyWith(color: c.success)),
            ),
            const HGap.sm(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.persona, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text(p.conInteres ? '$tasa mensual' : 'Sin intereses', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ]),
            ),
            const HGap.xs(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Te debe', style: context.text.labelSmall?.copyWith(letterSpacing: 0)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(cop(p.pendiente), style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ]),
            ),
          ]),
          const VGap.sm(),
          ProgressBar(value: p.progreso, color: c.success, height: 6),
          const SizedBox(height: Gap.xxs),
          Row(children: [
            Expanded(
              child: Text(
                [
                  'Te ha pagado ${_copJunto(p.cobrado)} de ${_copJunto(p.prestado + p.interesCausado)}',
                  if (p.gananciaDiaria > 0) 'gana ${_copJunto(p.gananciaDiaria)} al día',
                ].join(' · '),
                style: context.text.bodySmall,
              ),
            ),
          ]),
          if (estado != null) ...[
            const SizedBox(height: Gap.xxs),
            Row(children: [
              Icon(
                vencido ? Icons.warning_amber_rounded : (p.activo ? Icons.event_rounded : Icons.check_circle_outline_rounded),
                size: IconSizes.sm,
                color: vencido ? c.warning : c.textSecondary,
              ),
              const SizedBox(width: Gap.xxs),
              Expanded(child: Text(estado, style: context.text.labelMedium?.copyWith(color: vencido ? c.warning : c.textSecondary))),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Transferencias ───────────────────────────

/// El mes solo importa aquí: los saldos de arriba siempre son los de hoy.
class _Transferencias extends ConsumerWidget {
  const _Transferencias({required this.mes, required this.cuentas});
  final DateTime mes;
  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final lista = ref.watch(transferenciasMesProvider((mes.year, mes.month))).value ?? const <Transferencia>[];
    final nombre = {for (final c in cuentas) c.id: c.nombre};
    final cursor = ref.read(mesFinanzasProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Transferencias', style: context.text.titleMedium)),
        Row(children: [
          IconButton(tooltip: 'Mes anterior', onPressed: () => cursor.mover(-1), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: Text('${mesesLargos[mes.month - 1]} ${mes.year}', textAlign: TextAlign.center, style: context.text.labelLarge?.copyWith(color: p.text))),
          IconButton(tooltip: 'Mes siguiente', onPressed: () => cursor.mover(1), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height: Gap.xxs),
        if (lista.isEmpty)
          Text('No moviste dinero entre tus cuentas este mes.', style: context.text.bodySmall)
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Gap.xxs),
            child: Column(children: [
              for (final (k, t) in lista.indexed) ...[
                if (k > 0) Divider(height: 1, indent: Gap.md, endIndent: Gap.md, color: p.surfaceHighest),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xxs, Gap.xs),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${nombre[t.cuentaOrigenId] ?? '—'} → ${nombre[t.cuentaDestinoId] ?? '—'}', style: context.text.titleSmall),
                        Text([fechaCorta(t.fecha), if (t.descripcion.isNotEmpty) t.descripcion].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      ]),
                    ),
                    const HGap.xs(),
                    Text(cop(t.monto), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    IconButton(
                      tooltip: 'Eliminar transferencia',
                      icon: Icon(Icons.delete_outline_rounded, color: p.textSecondary),
                      onPressed: () async {
                        final ok = await confirmar(
                          context,
                          titulo: '¿Eliminar transferencia?',
                          mensaje: 'Se revertirán los cambios en los saldos de ambas cuentas.',
                          confirmar: 'Eliminar',
                          destructivo: true,
                        );
                        if (ok) {
                          HapticFeedback.mediumImpact();
                          await ref.read(financeRepoProvider).eliminarTransferencia(t);
                        }
                      },
                    ),
                  ]),
                ),
              ],
            ]),
          ),
      ],
    );
  }
}
