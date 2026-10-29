import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aviso de un banco guardado por el servicio nativo de Android
/// (`PagosListener.kt`) mientras la app estaba cerrada.
class AvisoCrudo {
  const AvisoCrudo({required this.id, required this.paquete, required this.app, required this.titulo, required this.texto, required this.fecha});
  final String id;
  final String paquete;
  final String app;
  final String titulo;
  final String texto;
  final DateTime fecha;
}

/// Lectura de avisos de compra de los bancos (solo Android, con permiso).
abstract class LectorPagos {
  /// true si este teléfono puede leer avisos de bancos (Android).
  bool get soportado;
  Future<bool> acceso();
  Future<void> abrirAjustes();
  Future<List<AvisoCrudo>> pendientes();
  Future<void> quitar(List<String> ids);
  Future<void> avisar(bool valor);
  Future<List<String>> apps();
}

class LectorPagosInerte implements LectorPagos {
  @override
  bool get soportado => false;
  @override
  Future<bool> acceso() async => false;
  @override
  Future<void> abrirAjustes() async {}
  @override
  Future<List<AvisoCrudo>> pendientes() async => const [];
  @override
  Future<void> quitar(List<String> ids) async {}
  @override
  Future<void> avisar(bool valor) async {}
  @override
  Future<List<String>> apps() async => const [];
}

class LectorPagosAndroid implements LectorPagos {
  static const _canal = MethodChannel('agendaservi/pagos');

  @override
  bool get soportado => true;

  @override
  Future<bool> acceso() async => await _canal.invokeMethod<bool>('acceso') ?? false;

  @override
  Future<void> abrirAjustes() => _canal.invokeMethod<void>('abrirAjustes');

  @override
  Future<List<AvisoCrudo>> pendientes() async {
    final crudo = await _canal.invokeMethod<String>('leer') ?? '[]';
    final lista = jsonDecode(crudo);
    if (lista is! List) return const [];
    return [
      for (final o in lista.whereType<Map<String, dynamic>>())
        AvisoCrudo(
          id: '${o['id']}',
          paquete: '${o['paquete'] ?? ''}',
          app: '${o['app'] ?? ''}',
          titulo: '${o['titulo'] ?? ''}',
          texto: '${o['texto'] ?? ''}',
          fecha: DateTime.fromMillisecondsSinceEpoch((o['fecha'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch, isUtc: true),
        ),
    ];
  }

  @override
  Future<void> quitar(List<String> ids) => _canal.invokeMethod<void>('quitar', {'ids': ids});

  @override
  Future<void> avisar(bool valor) => _canal.invokeMethod<void>('avisar', {'valor': valor});

  @override
  Future<List<String>> apps() async => (await _canal.invokeListMethod<String>('apps')) ?? const [];
}

final lectorPagosProvider = Provider<LectorPagos>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? LectorPagosAndroid() : LectorPagosInerte(),
);
