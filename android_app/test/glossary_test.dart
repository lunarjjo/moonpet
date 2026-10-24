import 'package:flutter_test/flutter_test.dart';
import 'package:moonpet/brain/chat.dart';

void main() {
  group('isIndonesian', () {
    test('deteksi kalimat Indonesia umum', () {
      expect(isIndonesian('aku kesepian banget hari ini'), isTrue);
      expect(isIndonesian('momo temani aku ya'), isTrue);
      expect(isIndonesian('kenapa aku gak pernah cukup'), isTrue);
    });
    test('kalimat Inggris tidak terdeteksi', () {
      expect(isIndonesian('i am so lonely today'), isFalse);
      expect(isIndonesian('hello world how are you'), isFalse);
    });
  });

  group('idToEn', () {
    test('frasa umum diterjemahkan utuh', () {
      expect(idToEn('aku kesepian banget'), contains('lonely'));
      expect(idToEn('temani aku ya'), contains('stay with me'));
    });
    test('kata per kata', () {
      final out = idToEn('aku sedih sekali');
      expect(out, contains('i'));
      expect(out, contains('sad'));
      expect(out, contains('very'));
    });
    test('kata asing dibiarkan', () {
      expect(idToEn('blorb aku sedih'), contains('blorb'));
    });
    test('frasa panjang diprioritaskan', () {
      expect(idToEn('terima kasih banyak'), contains('thank you very much'));
    });
  });

  group('buildPrompt', () {
    test('struktur ChatML LFM2.5 benar', () {
      final p = buildPrompt(
        system: 'SYS',
        history: [
          {'role': 'user', 'content': 'U1'},
          {'role': 'assistant', 'content': 'A1'},
          {'role': 'user', 'content': 'U2'},
        ],
        fewShot: [
          {'role': 'user', 'content': 'F1'},
          {'role': 'assistant', 'content': 'F2'},
        ],
      );
      expect(p.startsWith('<|im_start|>system\nSYS<|im_end|>\n'), isTrue);
      expect(p.indexOf('F1'), lessThan(p.indexOf('U1')));
      expect(p.endsWith('<|im_start|>assistant\n'), isTrue);
      expect(p.contains('<|im_start|>user\nU2<|im_end|>\n'), isTrue);
      // tanpa BOS literal — shim menambahkannya otomatis (add_special)
      expect(p.contains('<|startoftext|>'), isFalse);
    });
  });

  group('cleanReply', () {
    test('memotong penanda template', () {
      expect(cleanReply('halo!<|im_end|>sampah'), 'halo!');
      expect(cleanReply('<|im_start|>user\nx'), '');
    });
  });

  group('systemPrompt', () {
    test('mood dan luka ikut', () {
      final p = systemPrompt('sedih', bruises: 5);
      expect(p, contains('a bit sad'));
      expect(p, contains('bruises'));
    });
  });
}
