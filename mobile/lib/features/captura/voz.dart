import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictado con el reconocimiento del propio teléfono: gratis y sin servidor.
abstract class ReconocedorVoz {
  /// Pide permiso si hace falta. false: no se puede dictar en este teléfono.
  Future<bool> preparar();

  /// Empieza a escuchar. [alTexto] recibe lo reconocido hasta ahora y
  /// [alTerminar] avisa cuando deja de escuchar por cualquier motivo.
  Future<void> escuchar({required void Function(String texto) alTexto, required void Function() alTerminar});

  Future<void> detener();
}

class VozInerte implements ReconocedorVoz {
  @override
  Future<bool> preparar() async => false;
  @override
  Future<void> escuchar({required void Function(String texto) alTexto, required void Function() alTerminar}) async => alTerminar();
  @override
  Future<void> detener() async {}
}

class VozDispositivo implements ReconocedorVoz {
  final _voz = SpeechToText();
  void Function()? _alTerminar;

  void _termino() {
    final f = _alTerminar;
    _alTerminar = null;
    f?.call();
  }

  @override
  Future<bool> preparar() async {
    try {
      return await _voz.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _termino();
        },
        onError: (_) => _termino(),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> escuchar({required void Function(String texto) alTexto, required void Function() alTerminar}) async {
    _alTerminar = alTerminar;
    await _voz.listen(
      onResult: (r) => alTexto(r.recognizedWords),
      localeId: 'es_CO', // ignore: deprecated_member_use
      listenFor: const Duration(seconds: 30), // ignore: deprecated_member_use
      pauseFor: const Duration(seconds: 4), // ignore: deprecated_member_use
    );
  }

  @override
  Future<void> detener() async {
    await _voz.stop();
    _termino();
  }
}

final reconocedorVozProvider = Provider<ReconocedorVoz>((ref) => kIsWeb ? VozInerte() : VozDispositivo());
