import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../app/theme/app_module.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../citas/citas_models.dart';
import '../citas/citas_repository.dart';
import '../finance/pagos/pagos_repository.dart';

/// Lo que muestran los widgets de la pantalla de inicio del teléfono.
class ResumenWidget {
  const ResumenWidget({this.proximoTitulo = '', this.proximoCuando = '', this.citasHoy = 0, this.gastoMes = '', this.porClasificar = 0});

  final String proximoTitulo;
  final String proximoCuando;
  final int citasHoy;
  final String gastoMes;
  final int porClasificar;

  Map<String, Object> toMap() => {
        'proximo_titulo': proximoTitulo,
        'proximo_cuando': proximoCuando,
        'citas_hoy': citasHoy,
        'gasto_mes': gastoMes,
        'por_clasificar': porClasificar,
      };
}

abstract class PublicadorWidgets {
  Future<void> publicar(ResumenWidget r);
}

class PublicadorInerte implements PublicadorWidgets {
  @override
  Future<void> publicar(ResumenWidget r) async {}
}

/// Android: lo guarda donde lo leen `WidgetHoy` y `WidgetProximo`.
class PublicadorAndroid implements PublicadorWidgets {
  @override
  Future<void> publicar(ResumenWidget r) async {
    try {
      for (final e in r.toMap().entries) {
        await HomeWidget.saveWidgetData<Object>(e.key, e.value);
      }
      await HomeWidget.updateWidget(androidName: 'WidgetHoy');
      await HomeWidget.updateWidget(androidName: 'WidgetProximo');
    } catch (e) {
      debugPrint('No se pudo actualizar el widget: $e');
    }
  }
}

final publicadorWidgetsProvider = Provider<PublicadorWidgets>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? PublicadorAndroid() : PublicadorInerte(),
);

/// Siguiente evento con hora a partir de [ahora] (o de hoy sin hora).
Evento? _proximo(List<Evento> eventos, DateTime ahora) {
  final hoy = ymd(ahora);
  final horaAhora = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
  final vigentes = eventos.where((e) => e.fecha.compareTo(hoy) > 0 || (e.fecha == hoy && (e.hora == null || e.hora!.compareTo(horaAhora) >= 0))).toList()
    ..sort((a, b) => '${a.fecha}${a.hora ?? '00:00'}'.compareTo('${b.fecha}${b.hora ?? '00:00'}'));
  return vigentes.firstOrNull;
}

/// Mantiene al día los widgets. Sin sesión los deja vacíos: lo privado no se
/// queda a la vista en la pantalla de inicio al cerrar la sesión.
final widgetsInicioProvider = Provider<void>((ref) {
  final publicador = ref.watch(publicadorWidgetsProvider);
  if (ref.watch(usuarioIdProvider) == 0) {
    publicador.publicar(const ResumenWidget());
    return;
  }
  final activos = ref.watch(modulosActivosProvider);
  final ahora = DateTime.now();
  final sig = DateTime(ahora.year, ahora.month + 1);
  final mes = ref.watch(monthProvider((ahora.year, ahora.month))).value;
  if (mes == null) return;
  final mesSig = ref.watch(monthProvider((sig.year, sig.month))).value;

  final evento = activos.contains(AppModule.eventos) ? _proximo([...mes.eventos, ...?mesSig?.eventos], ahora) : null;
  final hoy = hoyYmd();
  final citas = activos.contains(AppModule.citas)
      ? (ref.watch(citasPorDiaProvider)[hoy] ?? const <CitaAgenda>[]).where((c) => c.estado == EstadoCita.confirmada).length
      : 0;
  final finanzas = activos.contains(AppModule.finanzas);
  final gasto = mes.transacciones.where((t) => t.tipo == 'gasto').fold(0.0, (s, t) => s + t.monto);
  final pagos = finanzas ? (ref.watch(pagosPendientesProvider).value?.length ?? 0) : 0;

  publicador.publicar(ResumenWidget(
    proximoTitulo: evento?.titulo ?? '',
    proximoCuando: evento == null ? '' : [fechaRelativa(evento.fecha), if (evento.hora != null) hora12(evento.hora)].join(' · '),
    citasHoy: citas,
    gastoMes: finanzas ? cop(gasto) : '',
    porClasificar: pagos,
  ));
});
