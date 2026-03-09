import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

enum VoiceStatus { idle, listening, processing, success, error }

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  VoiceStatus _status = VoiceStatus.idle;

  // Track initialization
  final Completer<void> _initCompleter = Completer();
  Future<void> get initialized => _initCompleter.future;

  // Streams for real-time updates
  final _onStatusChanged = StreamController<VoiceStatus>.broadcast();
  final _onPartialText = StreamController<String>.broadcast();
  final _onError = StreamController<String>.broadcast();

  Stream<VoiceStatus> get statusStream => _onStatusChanged.stream;
  Stream<String> get partialTextStream => _onPartialText.stream;
  Stream<String> get errorStream => _onError.stream;

  VoiceStatus get currentStatus => _status;

  Future<void> init() async {
    if (_initCompleter.isCompleted) return;

    try {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
      }

      if (status.isPermanentlyDenied) {
        _onError.add('Microphone permission permanently denied. Please enable in settings.');
        _setStatus(VoiceStatus.error);
        if (!_initCompleter.isCompleted) _initCompleter.complete();
        return;
      }

      if (status.isGranted) {
        _isAvailable = await _speech.initialize(
          onStatus: (status) {
            print('Speech Status: $status');
            if (status == 'listening') _setStatus(VoiceStatus.listening);
            else if (status == 'notListening') _setStatus(VoiceStatus.idle);
          },
          onError: (errorNotification) {
            print('Speech Error: ${errorNotification.errorMsg}');
            _onError.add(errorNotification.errorMsg);
            _setStatus(VoiceStatus.error);
          },
        );
      }
    } catch (e) {
      _onError.add('Initialization error: $e');
      _setStatus(VoiceStatus.error);
    } finally {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  void _setStatus(VoiceStatus status) {
    if (_status != status) {
      _status = status;
      _onStatusChanged.add(status);
    }
  }

  Future<void> startListening() async {
    await initialized;
    
    if (_isAvailable && !_speech.isListening) {
      _setStatus(VoiceStatus.listening);
      _speech.listen(
        onResult: (result) {
          // Actualiza con el último texto, pero no detenemos la escucha automáticamente
          if (result.finalResult) {
            _onStatusChanged.add(VoiceStatus.processing);
            _onPartialText.add(result.recognizedWords); 
          } else {
            _onPartialText.add(result.recognizedWords);
          }
        },
        localeId: 'es_ES', // Default to Spanish as requested via prompt language ("gasté 50")
        listenFor: const Duration(hours: 24), // Tiempo máximo
        pauseFor: const Duration(hours: 24),  // Para que no se pause por silencio
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation, // Dictation es mucho más robusto contra ruido de fondo
          cancelOnError: false, // Evita que un error por ruido corte la grabación de inmediato
        ),
      );
    } else {
      if (!_isAvailable) {
        _onError.add('Speech recognition not available.');
        _setStatus(VoiceStatus.error);
      }
    }
  }

  void stopListening() {
    if (_speech.isListening) {
      _speech.stop();
      _setStatus(VoiceStatus.idle);
    }
  }

  void cancelListening() {
    if (_speech.isListening) {
      _speech.cancel();
      _setStatus(VoiceStatus.idle);
    }
  }
}
