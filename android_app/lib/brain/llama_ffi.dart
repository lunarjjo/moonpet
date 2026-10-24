/// Binding FFI ke shim native `libmoonpet.so` (llama.cpp + moonpet.c).
///
/// API shim bersifat "pull": generasi berjalan di thread C internal;
/// Dart melakukan polling mp_status/mp_poll — aman terhadap aturan
/// dart:ffi (tanpa callback lintas thread).
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ---------- tipe FFI ----------
typedef _MpInitC = Int32 Function();
typedef _MpInitD = int Function();
typedef _MpCreateC = Pointer<Void> Function(Pointer<Utf8>, Int32, Int32);
typedef _MpCreateD = Pointer<Void> Function(Pointer<Utf8>, int, int);
typedef _MpStartC = Int32 Function(
    Pointer<Void>, Pointer<Utf8>, Int32, Float, Float, Float, Int32, Uint64);
typedef _MpStartD = int Function(
    Pointer<Void>, Pointer<Utf8>, int, double, double, double, int, int);
typedef _MpPollC = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef _MpPollD = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _MpStatusC = Int32 Function(Pointer<Void>);
typedef _MpStatusD = int Function(Pointer<Void>);
typedef _MpInterruptC = Void Function(Pointer<Void>);
typedef _MpInterruptD = void Function(Pointer<Void>);
typedef _MpErrorC = Pointer<Utf8> Function(Pointer<Void>);
typedef _MpErrorD = Pointer<Utf8> Function(Pointer<Void>);
typedef _MpTpsC = Float Function(Pointer<Void>);
typedef _MpTpsD = double Function(Pointer<Void>);
typedef _MpDestroyC = Void Function(Pointer<Void>);
typedef _MpDestroyD = void Function(Pointer<Void>);

class MpStatus {
  static const int idle = 0;
  static const int running = 1;
  static const int done = 2;
  static const int error = 3;
}

/// Loosely typed handle ke konteks native.
class NativeBrain {
  final Pointer<Void> handle;
  final DynamicLibrary lib;
  NativeBrain(this.handle, this.lib);

  bool get isValid => handle != nullptr;
}

/// Buka pustaka native sesuai platform (hanya Android & pengujian host).
DynamicLibrary openMoonPetLib({String? explicitPath}) {
  if (explicitPath != null) return DynamicLibrary.open(explicitPath);
  if (Platform.isAndroid) return DynamicLibrary.open('libmoonpet.so');
  if (Platform.isLinux) {
    // pengujian host: build-host/libmoonpet.so
    for (final p in [
      'build-host/libmoonpet.so',
      '../native/build-host/libmoonpet.so',
      'libmoonpet.so',
    ]) {
      if (File(p).existsSync()) return DynamicLibrary.open(p);
    }
    return DynamicLibrary.open('libmoonpet.so');
  }
  throw UnsupportedError('platform tidak didukung untuk FFI native');
}

/// Inisialisasi backend (sekali per proses).
void mpInit(DynamicLibrary lib) {
  final f = lib.lookupFunction<_MpInitC, _MpInitD>('mp_init');
  f();
}

/// Buat konteks model — bisa berat (~1-3 dtk), jalankan via [Isolate.run].
Future<NativeBrain> mpCreateAsync(
  String modelPath,
  int nCtx,
  int nThreads, {
  String? libPath,
}) async {
  final addr = await Isolate.run(() {
    final lib = openMoonPetLib(explicitPath: libPath);
    mpInit(lib);
    final f = lib.lookupFunction<_MpCreateC, _MpCreateD>('mp_create');
    final h = f(modelPath.toNativeUtf8(), nCtx, nThreads);
    return h.address;
  });
  final lib = openMoonPetLib(explicitPath: libPath);
  return NativeBrain(Pointer<Void>.fromAddress(addr), lib);
}

// ---------- pembungkus tingkat tinggi ----------

class GenParams {
  final int maxTokens;
  final double temp;
  final double topP;
  final double penRepeat;
  final int penLastN;
  const GenParams({
    this.maxTokens = 60,
    this.temp = 0.6,
    this.topP = 0.95,
    this.penRepeat = 1.1,
    this.penLastN = 64,
  });
}

/// Hasil satu generasi.
class GenResult {
  final String text;
  final double tokensPerSecond;
  final bool aborted;
  final String? error;
  const GenResult(this.text, this.tokensPerSecond, this.aborted, this.error);
}

/// Otak Momo: kelola konteks native + generasi streaming (pull/poll).
class MomoEngine {
  NativeBrain? _brain;
  bool _running = false;
  bool _abort = false;
  final _buf = <int>[];

  bool get isLoaded => _brain != null && _brain!.isValid;
  bool get isGenerating => _running;

  /// Muat model dari berkas GGUF.
  Future<String> load(String modelPath, {int nCtx = 2048, int nThreads = 4, String? libPath}) async {
    final sw = Stopwatch()..start();
    _brain = await mpCreateAsync(modelPath, nCtx, nThreads, libPath: libPath);
    sw.stop();
    if (!isLoaded) {
      throw Exception('gagal memuat model: $modelPath');
    }
    return 'model termuat dalam ${sw.elapsedMilliseconds} ms';
  }

  /// Jalankan satu prompt template penuh; mengembalikan teks yang mengalir.
  Stream<String> generate(String prompt, {GenParams p = const GenParams()}) async* {
    final b = _brain;
    if (b == null || !b.isValid) {
      throw StateError('otak belum dimuat');
    }
    if (_running) return;

    final start = b.lib.lookupFunction<_MpStartC, _MpStartD>('mp_start');
    final poll = b.lib.lookupFunction<_MpPollC, _MpPollD>('mp_poll');
    final status = b.lib.lookupFunction<_MpStatusC, _MpStatusD>('mp_status');
    final interrupt = b.lib.lookupFunction<_MpInterruptC, _MpInterruptD>('mp_interrupt');
    final tps = b.lib.lookupFunction<_MpTpsC, _MpTpsD>('mp_tokens_per_second');

    _running = true;
    _abort = false;
    _buf.clear();

    final rc = start(b.handle, prompt.toNativeUtf8(), p.maxTokens, p.temp,
        p.topP, p.penRepeat, p.penLastN, 0x4D4F4D4F);
    if (rc != 1) {
      _running = false;
      throw StateError('mp_start gagal: rc=$rc');
    }

    final chunk = malloc<Uint8>(8192);
    try {
      while (true) {
        final st = status(b.handle);
        final n = poll(b.handle, chunk, 8192);
        if (n > 0) {
          final bytes = chunk.asTypedList(n);
          _buf.addAll(bytes);
          yield utf8.decode(bytes, allowMalformed: true);
        }
        if (st == MpStatus.done || st == MpStatus.error) break;
        if (_abort) {
          interrupt(b.handle);
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    } finally {
      if (_abort) {
        // pastikan benar-benar berhenti
        while (status(b.handle) == MpStatus.running) {
          interrupt(b.handle);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
      malloc.free(chunk);
      _running = false;
    }
    final st = status(b.handle);
    if (st == MpStatus.error) {
      final errF = b.lib.lookupFunction<_MpErrorC, _MpErrorD>('mp_error');
      final errPtr = errF(b.handle);
      throw StateError('generasi gagal: ${errPtr.toDartString()}');
    }
    debugPrint('[momo] ${tps(b.handle).toStringAsFixed(1)} tok/s');
  }

  void abort() => _abort = true;

  void dispose() {
    final b = _brain;
    if (b != null && b.isValid) {
      b.lib.lookupFunction<_MpDestroyC, _MpDestroyD>('mp_destroy')(b.handle);
    }
    _brain = null;
  }
}

/// Cari path model: preferensi nativeLibraryDir (model dibundel sebagai
/// jniLibs libmoonpetmodel.so — ter-extract saat install), lalu path eksplisit.
Future<String?> resolveModelPath({String? explicitPath}) async {
  if (explicitPath != null && File(explicitPath).existsSync()) return explicitPath;
  if (Platform.isAndroid) {
    try {
      final dir = await const MethodChannel('moonpet/native')
          .invokeMethod<String>('nativeLibraryDir');
      if (dir != null) {
        final p = '$dir/libmoonpetmodel.so';
        if (File(p).existsSync()) return p;
      }
    } on PlatformException {
      // diabaikan — jatuh ke null
    }
  }
  // pengujian host
  for (final p in [
    'build-host/model.gguf',
    '../native/build-host/model.gguf',
    'model.gguf',
  ]) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

const _chars = 'abcdef0123456789';
String randomId() =>
    String.fromCharCodes(Iterable.generate(8, (_) => _chars.codeUnitAt(math.Random().nextInt(16))));
