/// Panel curhat: bubble chat + streaming dari otak lokal (FFI poll).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brain/chat.dart';
import '../brain/llama_ffi.dart';
import '../state/pet_state.dart';

class ChatSheet extends StatefulWidget {
  final MomoEngine engine;
  final PetState pet;
  final void Function(String) onAchievement;
  const ChatSheet({
    super.key,
    required this.engine,
    required this.pet,
    required this.onAchievement,
  });

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // pulihkan riwayat tersimpan
    for (final m in widget.pet.stats.chatLog.take(20)) {
      _msgs.add(_Msg(m['role'] == 'user', m['content'] ?? ''));
    }
    if (_msgs.isEmpty) {
      _msgs.add(_Msg(false,
          'Halo! Aku Momo 🌙 Cerita apa saja ke aku — aku mendengarkan kok. (balasanku bahasa Inggris sederhana ya, otakku kecil hehe)'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
  }

  void _scrollBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 40,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
    });
    _scrollBottom();

    final pet = widget.pet;
    final stats = pet.stats;

    // jembatan bahasa: model 350M tak paham Indonesia -> Inggris patah
    final sendText = isIndonesian(text) ? idToEn(text) : text;
    stats.chatLog.add({'role': 'user', 'content': sendText});
    stats.chats++;
    stats.xp += 3;
    if (stats.chats == 1) widget.onAchievement('first_chat');
    if (stats.chats >= 50) widget.onAchievement('chat_50');

    final prompt = buildPrompt(
      system: systemPrompt(pet.moodId, ko: pet.ko, bruises: stats.bruises.length),
      history: stats.chatLog.sublist(math.max(0, stats.chatLog.length - 10)),
      fewShot: kFewShot,
    );

    final live = _Msg(false, '');
    setState(() => _msgs.add(live));
    _scrollBottom();

    var acc = '';
    try {
      await for (final piece in widget.engine.generate(prompt)) {
        acc += piece;
        if (!mounted) return;
        setState(() => live.text = cleanReplyStream(acc));
        _scrollBottom();
      }
    } catch (e) {
      live.text = '⚠ otak lokal bermasalah: $e';
    }

    final clean = cleanReply(acc).trim();
    if (clean.isNotEmpty) {
      stats.chatLog.add({'role': 'assistant', 'content': clean});
      if (stats.chatLog.length > 40) {
        stats.chatLog.removeRange(0, stats.chatLog.length - 30);
      }
      pet.addMood(2);
      pet.state = 'happy';
      pet.stateT = 2500;
      pet.bubble = clean.length > 42 ? '${clean.substring(0, 42)}…' : clean;
      pet.bubbleT = 2400;
    }
    await pet.save();
    if (mounted) setState(() => _busy = false);
  }

  String cleanReplyStream(String raw) {
    var s = raw;
    for (final stop in const ['<|im_end|>', '<|im_start|>']) {
      final i = s.indexOf(stop);
      if (i >= 0) s = s.substring(0, i);
    }
    return s;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: mq.size.height * 0.68,
        decoration: const BoxDecoration(
          color: Color(0xFF1d1a30),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: Color(0x668b5cf6))),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Curhat sama Momo',
                        style:
                            TextStyle(color: Color(0xFFE8E3F5), fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF8d84ad)),
                    tooltip: 'Hapus percakapan',
                    onPressed: () {
                      widget.pet.stats.chatLog.clear();
                      widget.pet.save();
                      setState(() => _msgs.clear());
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x338b5cf6)),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(10),
                itemCount: _msgs.length,
                itemBuilder: (_, i) => _bubble(_msgs[i]),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(color: Color(0xFFE8E3F5), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cerita apa saja ke Momo…',
                          hintStyle: const TextStyle(color: Color(0xFF776f99), fontSize: 14),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF12101f),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0x558b5cf6))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF8b5cf6))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _busy
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF8b5cf6)),
                            ))
                        : IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFF8b5cf6)),
                            onPressed: _send,
                            icon: const Icon(Icons.send, color: Colors.white, size: 20)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final isMe = m.fromUser;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF8b5cf6) : const Color(0xFF2d2a44),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          border: isMe ? null : Border.all(color: const Color(0x448b5cf6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('Momo',
                    style: TextStyle(color: Color(0xFFb9a5ff), fontSize: 10)),
              ),
            Text(m.text.isEmpty && _busy && m == _msgs.last ? '…' : m.text,
                style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFFE8E3F5),
                    fontSize: 14,
                    height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final bool fromUser;
  String text;
  _Msg(this.fromUser, this.text);
}
