import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({Key? key}) : super(key: key);

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isBotTyping = false;

  final Color _primaryColor = const Color(0xffF9A826);

  static const String _apiKey = '';

  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(
          "Kamu adalah Customer Service Virtual bernama 'AURA' untuk aplikasi 'TA Management'. "
              "Tugasmu membantu penghuni dan pemilik apartemen. Jawablah dengan ramah, profesional, sopan, dan singkat. "
              "Informasi Aplikasi: "
              "1. Untuk bayar tagihan (IPL, Listrik, Air), arahkan user ke menu 'Total Outstanding Balance' di Home, klik 'Pay'. "
              "2. Untuk lapor kerusakan (AC, Bocor, dll), arahkan ke menu 'Report Issue' di Home. "
              "3. Untuk pinjam kolam renang/gym, arahkan ke menu 'Book Facility'. "
              "4. Untuk daftar parkir mobil/motor, arahkan ke menu 'Parking Member'. "
              "5. Untuk daftarin tamu/paket, arahkan ke menu 'Visitor Access'. "
              "6. Kalau user tanya hal di luar apartemen, tolak dengan halus dan bilang kamu cuma urus apartemen."
      ),
    );

    _chatSession = _model.startChat();

    _messages.add(
      ChatMessage(
        text: "Halo! 👋 Saya AURA, Virtual Assistant TA Management.\nAda yang bisa saya bantu terkait fasilitas, tagihan, atau keluhan hari ini?",
        isUser: false,
      ),
    );
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = text.trim();
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isBotTyping = true;
    });

    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(userMessage));

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: response.text ?? _getManualFallbackResponse(userMessage), isUser: false));
          _isBotTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("🚨 API GAGAL: $e -> BERALIH KE MODE MANUAL 🚨");

      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: _getManualFallbackResponse(userMessage), isUser: false));
          _isBotTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _getManualFallbackResponse(String userMessage) {
    String lowerCaseMsg = userMessage.toLowerCase();

    if (lowerCaseMsg.contains("bantuan") || lowerCaseMsg.contains("help") || lowerCaseMsg.contains("menu")) {
      return "Tentu! Ini beberapa hal yang bisa AURA bantu jelaskan:\n\n1. Tagihan & Pembayaran\n2. Lapor Kerusakan (Maintenance)\n3. Info Fasilitas\n4. Aturan Apartemen\n5. Parkir & Tamu\n\nSilakan ketik salah satu topik di atas ya!";
    }
    else if (lowerCaseMsg.contains("tagihan") || lowerCaseMsg.contains("bayar") || lowerCaseMsg.contains("ipl")) {
      return "Untuk urusan tagihan (IPL, Air, Listrik), Bos bisa mengeceknya langsung di menu 'Home' pada bagian 'Total Outstanding Balance'. Tekan tombol 'Pay' di sana untuk melakukan pembayaran ya. 💸";
    }
    else if (lowerCaseMsg.contains("rusak") || lowerCaseMsg.contains("maintenance") || lowerCaseMsg.contains("bocor") || lowerCaseMsg.contains("ac")) {
      return "Waduh, ada fasilitas unit yang bermasalah? 🛠️\nSilakan buka menu 'Report Issue' di Home untuk membuat tiket perbaikan. Tim teknisi kami akan segera meluncur ke unit Bos!";
    }
    else if (lowerCaseMsg.contains("fasilitas") || lowerCaseMsg.contains("kolam") || lowerCaseMsg.contains("gym") || lowerCaseMsg.contains("renang")) {
      return "Kolam renang dan Gym buka setiap hari dari jam 06:00 - 22:00. Jangan lupa, pastikan Bos sudah melakukan *booking* dulu di menu 'Book Facility' ya! 🏊‍♂️🏋️‍♂️";
    }
    else if (lowerCaseMsg.contains("aturan") || lowerCaseMsg.contains("rules")) {
      return "Aturan dasar apartemen kita:\n1. Harap menjaga ketenangan di atas jam 22:00.\n2. Buanglah sampah pada tempat penampungan di dekat tangga darurat.\n3. Dilarang menjemur pakaian di balkon.\n\nTerima kasih sudah menjadi penghuni yang baik! 😊";
    }
    else if (lowerCaseMsg.contains("parkir") || lowerCaseMsg.contains("motor") || lowerCaseMsg.contains("mobil")) {
      return "Mau daftar langganan parkir? Gampang! Bos tinggal masuk ke menu 'Parking Member' di halaman Home. Pendaftaran kendaraan baru akan diproses maksimal 1x24 jam. 🚗🛵";
    }
    else if (lowerCaseMsg.contains("tamu") || lowerCaseMsg.contains("visitor") || lowerCaseMsg.contains("paket")) {
      return "Ada tamu atau kerabat yang mau datang? Daftarkan saja mereka lewat menu 'Visitor Access' di Home biar dapat QR Code. Satpam kita pasti langsung kasih akses masuk! 👮‍♂️";
    }
    else if (lowerCaseMsg.contains("halo") || lowerCaseMsg.contains("hai") || lowerCaseMsg.contains("pagi") || lowerCaseMsg.contains("siang") || lowerCaseMsg.contains("malam") || lowerCaseMsg.contains("ping")) {
      return "Halo juga Bosku! AURA di sini. Ada keluhan atau pertanyaan seputar apartemen hari ini? Ketik 'bantuan' kalau bingung ya.";
    }
    else if (lowerCaseMsg.contains("terima kasih") || lowerCaseMsg.contains("makasih") || lowerCaseMsg.contains("thanks")) {
      return "Sama-sama, Bos! AURA selalu siap membantu. Kalau ada apa-apa lagi, *chat* aja ya! 😉";
    }
    else {
      return "Maaf Bos, AURA belum ngerti maksudnya karena sedang mode offline. 😅\nCoba ketik kata kunci seperti 'tagihan', 'rusak', 'parkir', 'fasilitas', atau 'bantuan'.";
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent, color: _primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Support Center", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                Text("Online 24/7 (AURA)", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),

          if (_isBotTyping)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("AURA is typing...", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSubmitted,
                        decoration: const InputDecoration(
                          hintText: "Tanya AURA di sini...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _handleSubmitted(_textController.text),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    bool isUser = message.isUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _primaryColor.withOpacity(0.2),
              child: Icon(Icons.smart_toy_rounded, color: _primaryColor, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(5),
                  bottomRight: isUser ? const Radius.circular(5) : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 24),
        ],
      ),
    );
  }
}