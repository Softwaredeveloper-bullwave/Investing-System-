import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/api_exception.dart';
import '../api/bullwave_api.dart';

/// Voice input (device STT or OpenAI Whisper) + female TTS via OpenAI backend.
class AiVoiceService {
  AiVoiceService._();
  static final AiVoiceService instance = AiVoiceService._();

  final _speech = SpeechToText();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _api = BullwaveApi.instance;

  bool _speechReady = false;
  bool _listening = false;
  bool _speaking = false;
  bool _recording = false;
  String? _recordPath;

  bool ttsAvailable = false;
  bool sttAvailable = false;
  bool useOpenAiStt = false;
  String voiceProvider = '';
  String voiceId = '';
  String aiProvider = '';
  String? statusMessage;

  bool get isListening => _listening;
  bool get isSpeaking => _speaking;
  bool get isRecording => _recording;

  Future<void> initialize() async {
    _speechReady = await _speech.initialize(
      onError: (e) => debugPrint('[AiVoice] STT error: $e'),
      onStatus: (s) => debugPrint('[AiVoice] STT status: $s'),
    );
    try {
      final status = await _api.getAiVoiceStatus();
      ttsAvailable = status['ttsEnabled'] == true;
      sttAvailable = status['sttEnabled'] == true;
      useOpenAiStt = status['sttProvider'] == 'openai';
      voiceProvider = (status['voiceProvider'] as String? ?? '').trim();
      voiceId = (status['voiceId'] as String? ?? '').trim();
      aiProvider = (status['aiProvider'] as String? ?? '').trim();
      statusMessage = status['message'] as String?;
    } catch (_) {
      ttsAvailable = false;
      sttAvailable = false;
      useOpenAiStt = false;
    }
  }

  Future<bool> ensureMicPermission() async {
    if (kIsWeb) return true;
    final mic = await Permission.microphone.request();
    if (mic.isGranted) return true;
    if (Platform.isAndroid) {
      final speech = await Permission.speech.request();
      return speech.isGranted || mic.isGranted;
    }
    return mic.isGranted;
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    bool preferDeviceStt = false,
  }) async {
    if (!_speechReady) await initialize();

    final allowed = await ensureMicPermission();
    if (!allowed) return false;

    if (_listening) await stopListening();

    final useWhisper = useOpenAiStt && sttAvailable && !kIsWeb && !preferDeviceStt;
    if (useWhisper) {
      return _startOpenAiRecording(onResult);
    }

    if (!_speechReady) return false;

    try {
      final started = await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      _listening = started ?? false;
    } catch (e) {
      debugPrint('[AiVoice] listen failed: $e');
      _listening = false;
      return false;
    }
    return _listening;
  }

  Future<bool> _startOpenAiRecording(void Function(String text, bool isFinal) onResult) async {
    if (!await _recorder.hasPermission()) return false;

    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/bullwave_stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: _recordPath!,
    );
    _recording = true;
    _listening = true;
    onResult('Listening… tap Stop when done', false);
    return true;
  }

  Future<void> stopListening({void Function(String text, bool isFinal)? onResult}) async {
    if (_recording && _recordPath != null) {
      await _recorder.stop();
      _recording = false;
      _listening = false;

      final path = _recordPath!;
      _recordPath = null;

      try {
        final bytes = await File(path).readAsBytes();
        if (bytes.isEmpty) return;
        final text = await _api.transcribeAiSpeech(bytes);
        if (text.isNotEmpty) {
          onResult?.call(text, true);
        }
      } on ApiException catch (e) {
        debugPrint('[AiVoice] Whisper STT failed: ${e.message}');
        rethrow;
      } catch (e) {
        debugPrint('[AiVoice] Whisper STT failed: $e');
        rethrow;
      } finally {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }
    _listening = false;
  }

  /// Speaks [text] and completes when playback finishes (or fails).
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !ttsAvailable) return;

    await stopSpeaking();

    try {
      final bytes = await _api.synthesizeAiSpeech(trimmed);
      if (bytes.isEmpty) return;

      _speaking = true;
      await _player.setReleaseMode(ReleaseMode.stop);

      final done = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        _speaking = false;
        if (!done.isCompleted) done.complete();
      });

      if (kIsWeb) {
        await _player.play(BytesSource(Uint8List.fromList(bytes)));
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/bullwave_ai_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(bytes, flush: true);
        await _player.play(DeviceFileSource(file.path));
      }

      await done.future.timeout(
        Duration(seconds: (trimmed.length / 12).ceil().clamp(8, 120)),
        onTimeout: () {
          _speaking = false;
        },
      );
      await sub.cancel();
    } on ApiException catch (e) {
      _speaking = false;
      debugPrint('[AiVoice] TTS failed: ${e.message}');
      rethrow;
    } catch (e) {
      _speaking = false;
      debugPrint('[AiVoice] TTS failed: $e');
      rethrow;
    }
  }

  Future<void> stopSpeaking() async {
    await _player.stop();
    _speaking = false;
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
    await _recorder.dispose();
    await _player.dispose();
  }
}
