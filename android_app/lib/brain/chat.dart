/// Persona, template chat LFM2.5 (ChatML-like), dan jembatan bahasa
/// Indonesia -> Inggris patah (model 350M tidak dilatih untuk bahasa
/// Indonesia — terverifikasi; Inggris sederhana sangat baik dipahami).
library;

import 'dart:math' as math;

const String kMomoSystemBase =
    'You are Momo the cute moon-cat pet. You love your owner. '
    'Reply in simple sweet English, max 2 short sentences, cute emoticons allowed. '
    'The owner may write in simple or broken English.';

const List<Map<String, String>> kFewShot = [
  {
    'role': 'user',
    'content': 'momo, i lonely very today. stay with me',
  },
  {
    'role': 'assistant',
    'content': 'Aww dont be sad! Momo is here with you forever (=^..^=)',
  },
  {
    'role': 'user',
    'content': 'my work day heavy very, want vent to you',
  },
  {
    'role': 'assistant',
    'content': 'You did great today 💜 Momo is proud of you, rest now.',
  },
];

String moodForPrompt(String moodId, {bool ko = false, int bruises = 0}) {
  const map = {
    'senang': 'happy',
    'biasa': 'relaxed',
    'sedih': 'a bit sad',
    'ngambek': 'sulking (but secretly forgiving)',
  };
  var p = map[moodId] ?? 'relaxed';
  if (ko) p = 'knocked out (reply very short and silly)';
  if (bruises >= 3) p += ', has funny cartoon bruises and a bandage';
  return p;
}

String systemPrompt(String moodId, {bool ko = false, int bruises = 0}) =>
    '$kMomoSystemBase Mood: ${moodForPrompt(moodId, ko: ko, bruises: bruises)}.';

/// Template ChatML ala LFM2.5 — TANPA BOS literal (shim menambahkan BOS
/// otomatis via add_special). Sama seperti uji host yang menghasilkan
/// balasan koheren.
String buildPrompt({
  required String system,
  required List<Map<String, String>> history,
  required List<Map<String, String>> fewShot,
}) {
  final sb = StringBuffer();
  sb.write('<|im_start|>system\n$system<|im_end|>\n');
  for (final m in fewShot) {
    sb.write('<|im_start|>${m['role']}\n${m['content']}<|im_end|>\n');
  }
  for (final m in history) {
    sb.write('<|im_start|>${m['role']}\n${m['content']}<|im_end|>\n');
  }
  sb.write('<|im_start|>assistant\n');
  return sb.toString();
}

// ---------- kamus Indonesia -> Inggris (curhat umum) ----------

const Map<String, String> kIdPhrases = {
  'terima kasih': 'thank you',
  'terima kasih banyak': 'thank you very much',
  'makasih banyak': 'thank you very much',
  'apa kabar': 'how are you',
  'gimana kabarmu': 'how are you',
  'gimana kabar': 'how are you',
  'aku sayang kamu': 'i love you',
  'sayang banget': 'love very much',
  'sudah makan': 'have you eaten',
  'semangat ya': 'cheer up',
  'semangatin aku': 'cheer me up',
  'aku kesepian banget': 'i feel so lonely',
  'temani aku': 'stay with me',
  'nggak apa apa': 'its okay',
  'gak apa apa': 'its okay',
  'tidak apa apa': 'its okay',
  'maafin aku': 'forgive me',
  'aku minta maaf': 'i am sorry',
  'peluk aku': 'hug me',
  'elus aku': 'pet me',
  'jangan pergi': 'dont go',
  'aku capek banget': 'i am so tired',
  'capek banget': 'so tired',
  'hari berat': 'hard day',
  'kerjaanku berat': 'my work is heavy',
  'mau curhat': 'want to vent',
  'sedih banget': 'very sad',
  'aku sedih': 'i am sad',
  'aku marah': 'i am angry',
  'aku takut': 'i am afraid',
  'kangen kamu': 'miss you',
  'rindu kamu': 'miss you',
  'selamat malam': 'good night',
  'selamat pagi': 'good morning',
  'aku gak bisa': 'i cannot',
  'gak bisa': 'cannot',
  'bantu aku': 'help me',
  'dengerin aku': 'listen to me',
  'dengarkan aku': 'listen to me',
  'butuh kamu': 'need you',
  'sama kamu': 'with you',
  'buat kamu': 'for you',
};

const Map<String, String> kIdWords = {
  'aku': 'i', 'saya': 'i', 'ku': 'my', 'kamu': 'you', 'kau': 'you', 'mu': 'your',
  'kalian': 'you all', 'kita': 'we', 'kami': 'we', 'mereka': 'they',
  'dia': 'he/she', 'ia': 'he/she', 'momo': 'momo', 'ini': 'this', 'itu': 'that',
  'sini': 'here', 'sana': 'there',
  'kesepian': 'lonely', 'sepi': 'quiet-lonely', 'sendirian': 'alone',
  'sendiri': 'alone', 'sedih': 'sad', 'nangis': 'cry', 'ngedumel': 'grumble',
  'bahagia': 'happy', 'senang': 'happy', 'gembira': 'glad', 'bangga': 'proud',
  'marah': 'angry', 'kesal': 'upset', 'benci': 'hate', 'takut': 'afraid',
  'khawatir': 'worried', 'cemas': 'anxious', 'capek': 'tired', 'lelah': 'tired',
  'letih': 'tired', 'pusing': 'dizzy', 'sakit': 'sick-hurt', 'hati': 'heart',
  'pikiran': 'mind', 'perasaan': 'feeling',
  'banget': 'very', 'sekali': 'very', 'amat': 'very', 'terlalu': 'too',
  'paling': 'most', 'cukup': 'enough',
  'kenapa': 'why', 'mengapa': 'why', 'gimana': 'how', 'bagaimana': 'how',
  'kapan': 'when', 'dimana': 'where', 'siapa': 'who', 'apa': 'what',
  'gak': 'not', 'nggak': 'not', 'tidak': 'not', 'enggak': 'not',
  'belum': 'not yet', 'sudah': 'already', 'udah': 'already',
  'akan': 'will', 'mau': 'want', 'pengen': 'want', 'bisa': 'can',
  'harus': 'must', 'jangan': 'dont', 'tolong': 'please',
  'ya': 'yes', 'iya': 'yes', 'oh': 'oh', 'sih': '', 'deh': '', 'dong': '',
  'kok': '', 'lah': '', 'nih': '', 'tuh': '', 'kayak': 'like',
  'juga': 'also', 'lagi': 'still', 'saja': 'only', 'doang': 'only',
  'cuma': 'only', 'masih': 'still', 'pernah': 'ever',
  'hari': 'day', 'kemarin': 'yesterday', 'besok': 'tomorrow',
  'sekarang': 'now', 'nanti': 'later',
  'pagi': 'morning', 'siang': 'afternoon', 'sore': 'evening', 'malam': 'night',
  'jam': 'hour', 'waktu': 'time', 'tahun': 'year', 'bulan': 'month', 'minggu': 'week',
  'kerja': 'work', 'kerjaan': 'work', 'kantor': 'office', 'sekolah': 'school',
  'kuliah': 'college', 'ujian': 'exam', 'nilai': 'grade',
  'teman': 'friend', 'sahabat': 'best friend', 'keluarga': 'family',
  'pacar': 'partner', 'gebetan': 'crush', 'jodoh': 'soulmate',
  'orang': 'person', 'semua': 'all', 'banyak': 'many', 'sedikit': 'little',
  'beberapa': 'some',
  'sayang': 'love', 'cinta': 'love', 'kangen': 'miss', 'rindu': 'miss',
  'peluk': 'hug', 'cium': 'kiss', 'elus': 'pet',
  'makan': 'eat', 'minum': 'drink', 'tidur': 'sleep', 'bangun': 'wake',
  'istirahat': 'rest', 'main': 'play', 'game': 'game',
  'musik': 'music', 'lagu': 'song', 'film': 'movie', 'buku': 'book',
  'catatan': 'note', 'cerita': 'story', 'curhat': 'vent',
  'bagus': 'good', 'baik': 'good', 'buruk': 'bad', 'jelek': 'bad',
  'cantik': 'pretty', 'ganteng': 'handsome', 'lucu': 'cute',
  'besar': 'big', 'kecil': 'small', 'panas': 'hot', 'dingin': 'cold',
  'hujan': 'rain', 'bintang': 'star', 'langit': 'sky',
  'rumah': 'home', 'kamar': 'room', 'kasur': 'bed', 'kucing': 'cat',
  'anjing': 'dog', 'makanan': 'food', 'air': 'water',
  'makasih': 'thanks', 'trims': 'thanks', 'sorry': 'sorry', 'maaf': 'sorry',
  'halo': 'hello', 'hai': 'hi',
  'tunggu': 'wait', 'dengar': 'listen', 'lihat': 'see', 'tahu': 'know',
  'pikir': 'think', 'ingat': 'remember', 'lupa': 'forget',
  'semangat': 'spirit', 'sabar': 'patient', 'kuat': 'strong', 'lemah': 'weak',
  'nyaman': 'comfortable', 'aman': 'safe',
  'hidup': 'life', 'mati': 'death', 'dunia': 'world', 'tuhan': 'god',
  'doa': 'prayer', 'rezeki': 'fortune',
};

final RegExp _stripPunct = RegExp(r'[^a-z0-9\s-]');

/// Deteksi sederhana: >=25% kata dikenali kamus Indonesia.
bool isIndonesian(String text) {
  final words = text
      .toLowerCase()
      .replaceAll(_stripPunct, ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 2)
      .toList();
  if (words.isEmpty) return false;
  final hits = words.where((w) => kIdWords.containsKey(w)).length;
  return hits / words.length >= 0.25;
}

/// Terjemahan kata-per-kata (dengan frasa lebih dulu) — Inggris patah yang
/// dipahami baik oleh model 350M.
String idToEn(String text) {
  var t = ' ${text.toLowerCase().replaceAll(_stripPunct, ' ')} ';
  // frasa panjang dulu
  final phrases = kIdPhrases.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final id in phrases) {
    t = t.replaceAll(' $id ', ' ${kIdPhrases[id]} ');
  }
  final out = t.trim().split(RegExp(r'\s+')).map((w) {
    final key = w.trim();
    if (key.isEmpty) return '';
    return kIdWords[key] ?? w;
  }).where((w) => w.isNotEmpty).join(' ');
  return out.isEmpty ? text : out;
}

/// Bersihkan balasan model: potong di penanda template yang lolos.
String cleanReply(String raw) {
  var s = raw;
  for (final stop in ['<|im_end|>', '<|im_start|>', '<|startoftext|>']) {
    final i = s.indexOf(stop);
    if (i >= 0) s = s.substring(0, i);
  }
  return s.trim();
}

/// Pilih acak.
T pick<T>(List<T> list) => list[math.Random().nextInt(list.length)];
