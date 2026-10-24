// Uji inferensi NYATA lewat FFI shim + model LFM2.5-350M host.
// Dijalankan bila berkas tersedia:
//   native/build-host/libmoonpet.so + native/build-host/model.gguf
// Lewati bila tidak (mis. mesin tanpa model).
// Jalankan dari android_app/:
//   LD_LIBRARY_PATH=../native/build-host/bin flutter test test/ffi_real_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonpet/brain/chat.dart';
import 'package:moonpet/brain/llama_ffi.dart';

void main() {
  final libSo = File('../native/build-host/libmoonpet.so');
  final model = File('../native/build-host/model.gguf');

  TestWidgetsFlutterBinding.ensureInitialized();

  test('inferensi LFM2.5-350M nyata via shim FFI', () async {
    if (!libSo.existsSync() || !model.existsSync()) {
      // ignore: avoid_print
      print('LEWATI: libmoonpet.so / model.gguf host tidak ada');
      return;
    }
    final engine = MomoEngine();
    try {
      final msg = await engine.load(model.path, nCtx: 2048, nThreads: 4,
          libPath: libSo.path);
      // ignore: avoid_print
      print(msg);
      expect(engine.isLoaded, isTrue);

      final prompt = buildPrompt(
        system: systemPrompt('senang'),
        history: [
          {'role': 'user', 'content': 'im so lonely today momo'},
        ],
        fewShot: kFewShot,
      );

      final acc = StringBuffer();
      await for (final piece in engine.generate(prompt)) {
        acc.write(piece);
      }
      final out = cleanReply(acc.toString());
      // ignore: avoid_print
      print('BALASAN: $out');
      // ignore: avoid_print
      print('--- panjang: ${out.length}');
      expect(out, isNotEmpty);

      // uji interrupt
      final long = buildPrompt(
        system: systemPrompt('biasa'),
        history: [
          {'role': 'user', 'content': 'write a long story about a cat'},
        ],
        fewShot: const [],
      );
      final b = StringBuffer();
      final sub = engine.generate(long,
          p: const GenParams(maxTokens: 200, temp: 0.8)).listen(b.write);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      engine.abort();
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(engine.isGenerating, isFalse);
    } finally {
      engine.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
