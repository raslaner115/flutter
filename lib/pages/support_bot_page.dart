import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/pages/search.dart';
import 'package:untitled1/pages/analytics_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupportBotPage extends StatefulWidget {
  const SupportBotPage({super.key});

  @override
  State<SupportBotPage> createState() => _SupportBotPageState();
}

class _SupportBotPageState extends State<SupportBotPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  String? _userName;
  String _userType = 'normal'; 

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userName = doc.data()?['name']?.toString().split(' ').first;
          _userType = doc.data()?['userType'] ?? 'normal';
        });
      }
    }
    _addBotMessage(_getGreeting());
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting = "Good day";
    if (hour < 12) timeGreeting = "Good morning";
    else if (hour < 17) timeGreeting = "Good afternoon";
    else timeGreeting = "Good evening";

    return "👋 $timeGreeting${_userName != null ? ' $_userName' : ''}! I'm your HireHub AI Assistant. I can help you find pros, check status, or answer questions about payments and safety. How can I help?";
  }

  void _addBotMessage(String text, {Widget? action}) async {
    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': text,
          'isBot': true,
          'action': action,
        });
      });
      _scrollToBottom();
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({'text': text, 'isBot': false});
    });
    _scrollToBottom();
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

  void _handleManualInput(String query) {
    if (query.trim().isEmpty) return;
    _inputController.clear();
    _addUserMessage(query);
    _processQuery(query.toLowerCase());
  }

  void _processQuery(String query) {
    // English Logic
    if (query.contains("pay") || query.contains("money") || query.contains("cost") || query.contains("price")) {
      _addBotMessage("💰 **Payment Information:**\nHireHub is free to use for browsing. You pay the professional directly after the service is completed. We recommend using our **Invoice Builder** (found in your profile) to keep a record of your payments.");
    } else if (query.contains("cancel")) {
      _addBotMessage("🚫 **Cancellation:**\nTo cancel a request, simply open the chat with the professional and let them know. If you've already scheduled a time, it's best to inform them as early as possible to maintain a good rating!");
    } else if (query.contains("safety") || query.contains("trust") || query.contains("verify")) {
      _addBotMessage("🛡️ **Safety & Trust:**\nYour safety is our priority. Look for the **Verified** badges (green/orange) on pro profiles. These indicate that we've verified their ID or Business license. Always read reviews before hiring!");
    } else if (query.contains("delete") || query.contains("account")) {
      _addBotMessage("⚙️ **Account Management:**\nYou can update your info or manage your account in **Profile > Settings > Account**. If you wish to permanently delete your account, please contact us at support@hirehub.com.");
    } else if (query.contains("hello") || query.contains("hi")) {
      _addBotMessage("Hi there! How can I help you today? I'm ready for your questions!");
    } else if (query.contains("status")) {
      _checkStatus();
    } else if (query.contains("find") || query.contains("pro") || query.contains("search")) {
      _findAProFlow();
    }
    // Hebrew Logic
    else if (query.contains("שלם") || query.contains("כסף") || query.contains("מחיר") || query.contains("עלות")) {
      _addBotMessage("💰 **מידע על תשלומים:**\nהשימוש ב-HireHub הוא בחינם. התשלום מתבצע ישירות מול בעל המקצוע לאחר סיום העבודה. מומלץ להשתמש ב**מפיק החשבוניות** שלנו (נמצא בפרופיל) לתיעוד בטוח.");
    } else if (query.contains("בטל") || query.contains("ביטול")) {
      _addBotMessage("🚫 **ביטול:**\nכדי לבטל בקשה, פשוט פתח את הצ'אט עם בעל המקצוע ועדכן אותו. אם כבר נקבע מועד, עדיף להודיע מוקדם ככל האפשר כדי לשמור על דירוג טוב!");
    } else if (query.contains("בטיחות") || query.contains("אמון") || query.contains("אימות")) {
      _addBotMessage("🛡️ **בטיחות ואמון:**\nהבטיחות שלך חשובה לנו. חפש את תגי ה**אימות** (ירוק/כתום) בפרופילים. זה מעיד שאימתנו את תעודת הזהות או רישיון העסק שלהם.");
    } else {
      _addBotMessage("🤔 I'm not sure I understand that. You can ask about **payments, safety, status, or how to hire**. Alternatively, I can connect you with a human representative.");
    }
  }

  void _findAProFlow() {
    _addBotMessage("Great! What kind of professional are you looking for today?",
      action: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTradeChip("Plumber", Icons.plumbing),
            _buildTradeChip("Electrician", Icons.electrical_services),
            _buildTradeChip("Painter", Icons.format_paint),
            _buildTradeChip("Handyman", Icons.build),
          ],
        ),
      )
    );
  }

  Widget _buildTradeChip(String trade, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, top: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: const Color(0xFF1976D2)),
        label: Text(trade),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage(initialTrade: trade))),
        backgroundColor: Colors.white,
      ),
    );
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _addBotMessage("You'll need to sign in to see your active requests.");
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('notifications')
        .orderBy('timestamp', descending: true).limit(1).get();

    if (snap.docs.isEmpty) {
      _addBotMessage("I don't see any recent requests. Ready to start your first project?",
        action: _buildNavBtn("Browse Professionals", const SearchPage()));
    } else {
      final data = snap.docs.first.data();
      String status = data['status'] ?? 'pending';
      String name = data['fromName'] ?? 'the pro';
      _addBotMessage("Your latest request with $name is currently **${status.toUpperCase()}**. You'll receive a push notification the moment it updates!");
    }
  }

  Widget _buildNavBtn(String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          side: const BorderSide(color: Color(0xFF1976D2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0, 
          backgroundColor: Colors.white, 
          foregroundColor: const Color(0xFF1976D2),
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF1976D2),
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? "עוזר HireHub" : "HireHub AI Assistant", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(isRtl ? "פעיל" : "Always Active", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
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
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) return _buildTyping();
                  final m = _messages[index];
                  return _buildBubble(m);
                },
              ),
            ),
            _buildSmartOptions(isRtl),
            _buildInputArea(isRtl),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> m) {
    bool isBot = m['isBot'];
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isBot ? Colors.white : const Color(0xFF1976D2),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isBot ? Radius.zero : const Radius.circular(18),
                bottomRight: isBot ? const Radius.circular(18) : Radius.zero,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Text(
              m['text'],
              style: TextStyle(
                color: isBot ? const Color(0xFF334155) : Colors.white,
                height: 1.4,
              )
            ),
          ),
          if (isBot && m['action'] != null) m['action'],
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1976D2)),
        ),
      )
    );
  }

  Widget _buildSmartOptions(bool isRtl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_userType == 'worker') ...[
              _optionChip(isRtl ? "הסטטיסטיקה שלי" : "My Stats", () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsPage(userId: FirebaseAuth.instance.currentUser!.uid, strings: const {})))),
            ] else ...[
              _optionChip(isRtl ? "חיפוש מקצוען" : "Hire a Pro", _findAProFlow),
              _optionChip(isRtl ? "סטטוס בקשה" : "Check Status", _checkStatus),
            ],
            _optionChip(isRtl ? "נציג אנושי" : "Talk to Human", () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatPage(receiverId: 'hirehub_manager', receiverName: 'HireHub Support')))),
          ],
        ),
      ),
    );
  }

  Widget _optionChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        onPressed: onTap,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF1976D2), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildInputArea(bool isRtl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _handleManualInput,
              decoration: InputDecoration(
                hintText: isRtl ? "שאל אותי משהו..." : "Ask me anything...",
                hintStyle: const TextStyle(fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF1976D2),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: () => _handleManualInput(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}
