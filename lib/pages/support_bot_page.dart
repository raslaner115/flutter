import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/search.dart';
import 'package:untitled1/pages/analytics_page.dart';
import 'package:untitled1/pages/verify_business.dart';
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
  String _userRole = 'customer';

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
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _userName = doc.data()?['name']?.toString().split(' ').first;
            _userRole = doc.data()?['role'] ?? 'customer';
          });
        }
      }
    }
    _addBotMessage(_getGreeting(), quickReplies: _getInitialQuickReplies());
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting = "Good day";
    if (hour < 12) {
      timeGreeting = "Good morning";
    } else if (hour < 17) {
      timeGreeting = "Good afternoon";
    } else {
      timeGreeting = "Good evening";
    }

    final isHe = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he';
    if (isHe) {
      if (hour < 12) timeGreeting = "בוקר טוב";
      else if (hour < 17) timeGreeting = "צהריים טובים";
      else timeGreeting = "ערב טוב";
      
      return "👋 $timeGreeting${_userName != null ? ' $_userName' : ''}! אני העוזר החכם של HireHub. אני יכול לעזור לך למצוא אנשי מקצוע, לבדוק סטטוס פרויקטים, או לענות על שאלות בנושאי תשלום ובטיחות. במה אוכל לעזור?";
    }

    return "👋 $timeGreeting${_userName != null ? ' $_userName' : ''}! I'm your HireHub AI Assistant. I can help you find pros, check status, or answer questions about payments and safety. How can I help?";
  }

  List<String> _getInitialQuickReplies() {
    final isHe = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he';
    if (_userRole == 'worker') {
      return isHe 
        ? ["אימות עסק", "סטטיסטיקות", "איך לקבל עבודות?", "תמיכה אנושית"]
        : ["Verify Business", "My Stats", "How to get jobs?", "Talk to human"];
    }
    return isHe 
      ? ["חיפוש בעל מקצוע", "בדיקת סטטוס", "ביטחון ותשלומים", "נציג אנושי"]
      : ["Find a Pro", "Check Status", "Safety & Payments", "Talk to human"];
  }

  void _addBotMessage(String text, {Widget? action, List<String>? quickReplies}) async {
    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': text,
          'isBot': true,
          'action': action,
          'quickReplies': quickReplies,
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
    final isHe = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he';

    // Payment & Money
    if (query.contains("pay") || query.contains("money") || query.contains("cost") || query.contains("price") ||
        query.contains("שלם") || query.contains("כסף") || query.contains("מחיר") || query.contains("עלות")) {
      _addBotMessage(isHe 
          ? "💰 **מידע על תשלומים:**\nהשימוש ב-HireHub הוא בחינם. התשלום מתבצע ישירות מול בעל המקצוע לאחר סיום העבודה. מומלץ להשתמש ב**מפיק החשבוניות** שלנו לתיעוד בטוח."
          : "💰 **Payment Info:**\nHireHub is free to browse. You pay the pro directly after service. We recommend using our **Invoice Builder** (in profile) for secure records.",
          quickReplies: isHe ? ["איך להפיק חשבונית?", "שיטות תשלום"] : ["How to make invoice?", "Payment methods"]);
    } 
    // Verification & Identity
    else if (query.contains("verify") || query.contains("trust") || query.contains("safety") || query.contains("identity") ||
             query.contains("אימות") || query.contains("בטיחות") || query.contains("זהות") || query.contains("מסמכים")) {
      _addBotMessage(isHe
          ? "🛡️ **אימות ובטיחות:**\nאנו ממליצים לעבוד רק עם בעלי מקצוע בעלי תג **מאומת**. אם אתה בעל מקצוע, תוכל להגיש מסמכים ב'פרופיל > אימות עסק'."
          : "🛡️ **Safety & Verification:**\nWe recommend working with pros having the **Verified** badge. If you are a pro, submit docs in 'Profile > Verify Business'.",
          action: _userRole == 'worker' ? _buildNavBtn(isHe ? "עבור לאימות עסק" : "Go to Verification", const VerifyBusinessPage()) : null,
          quickReplies: isHe ? ["איך זה עובד?", "למה זה חשוב?"] : ["How it works?", "Why verify?"]);
    }
    // Cancellation
    else if (query.contains("cancel") || query.contains("delete") || query.contains("בטל") || query.contains("ביטול") || query.contains("מחק")) {
      _addBotMessage(isHe
          ? "🚫 **ביטול וניהול חשבון:**\nביטול פרויקט מתבצע מול בעל המקצוע בצ'אט. מחיקת חשבון אפשרית דרך הגדרות הפרופיל."
          : "🚫 **Cancellation & Account:**\nCancel projects via chat with the pro. Account deletion is available in Profile Settings.",
          quickReplies: isHe ? ["תמיכה אנושית"] : ["Human Support"]);
    }
    // Status
    else if (query.contains("status") || query.contains("update") || query.contains("סטטוס") || query.contains("עדכון")) {
      _checkStatus();
    }
    // Search / Find
    else if (query.contains("find") || query.contains("pro") || query.contains("search") || query.contains("hire") ||
             query.contains("מצא") || query.contains("חפש") || query.contains("עבודה") || query.contains("מקצוע")) {
      _findAProFlow();
    }
    // Hello
    else if (query.contains("hello") || query.contains("hi") || query.contains("hey") || query.contains("שלום") || query.contains("היי")) {
      _addBotMessage(isHe ? "שלום! במה אוכל לעזור לך היום?" : "Hi there! How can I help you today?");
    }
    // Human
    else if (query.contains("human") || query.contains("person") || query.contains("manager") || query.contains("support") ||
             query.contains("אדם") || query.contains("נציג") || query.contains("מנהל") || query.contains("תמיכה")) {
      _addBotMessage(isHe ? "מעביר אותך לנציג אנושי..." : "Connecting you to a human representative...");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatPage(receiverId: 'hirehub_manager', receiverName: 'HireHub Support')));
      });
    }
    else {
      _addBotMessage(isHe 
          ? "🤔 לא בטוח שהבנתי. אפשר לשאול על **תשלומים, בטיחות, סטטוס או חיפוש עבודה**. או פשוט לבקש נציג אנושי."
          : "🤔 I'm not sure I understand. Ask about **payments, safety, status, or search**. Or ask for a human representative.",
          quickReplies: _getInitialQuickReplies());
    }
  }

  void _findAProFlow() {
    final isHe = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he';
    _addBotMessage(isHe ? "מעולה! איזה בעל מקצוע אתה מחפש היום?" : "Great! What kind of professional are you looking for today?",
      action: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _buildTradeChip(isHe ? "אינסטלטור" : "Plumber", Icons.plumbing),
              _buildTradeChip(isHe ? "חשמלאי" : "Electrician", Icons.electrical_services),
              _buildTradeChip(isHe ? "צבעי" : "Painter", Icons.format_paint),
              _buildTradeChip(isHe ? "הנדימן" : "Handyman", Icons.build),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildTradeChip(String trade, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: const Color(0xFF1976D2)),
        label: Text(trade),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage(initialTrade: trade))),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
    );
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    final isHe = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he';

    if (user == null || user.isAnonymous) {
      _addBotMessage(isHe ? "עליך להתחבר כדי לראות את הבקשות שלך." : "You'll need to sign in to see your active requests.");
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('notifications')
        .orderBy('timestamp', descending: true).limit(1).get();

    if (snap.docs.isEmpty) {
      _addBotMessage(isHe ? "לא מצאתי בקשות אחרונות. רוצה להתחיל פרויקט חדש?" : "I don't see any recent requests. Ready to start your first project?",
        action: _buildNavBtn(isHe ? "חיפוש אנשי מקצוע" : "Browse Professionals", const SearchPage()));
    } else {
      final data = snap.docs.first.data();
      String status = data['status'] ?? 'pending';
      String name = data['fromName'] ?? (isHe ? 'בעל המקצוע' : 'the pro');
      _addBotMessage(isHe 
          ? "הבקשה האחרונה שלך מול $name נמצאת כרגע בסטטוס: **${status.toUpperCase()}**. תקבל התראה ברגע שיהיה עדכון נוסף!"
          : "Your latest request with $name is currently **${status.toUpperCase()}**. You'll receive a notification the moment it updates!");
    }
  }

  Widget _buildNavBtn(String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ElevatedButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          centerTitle: false,
          title: Row(
            children: [
              Stack(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1976D2),
                    child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? "עוזר HireHub" : "HireHub AI Assistant", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(isRtl ? "פעיל" : "Online", style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                  return _buildBubble(m, isRtl);
                },
              ),
            ),
            _buildInputArea(isRtl),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> m, bool isRtl) {
    bool isBot = m['isBot'];
    List<String>? quickReplies = m['quickReplies'];
    
    return Column(
      crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isBot) ...[
              const CircleAvatar(radius: 12, backgroundColor: Colors.transparent, child: Icon(Icons.smart_toy, size: 16, color: Colors.grey)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isBot ? Colors.white : const Color(0xFF1976D2),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isBot ? Radius.zero : const Radius.circular(20),
                    bottomRight: isBot ? const Radius.circular(20) : Radius.zero,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  m['text'],
                  style: TextStyle(
                    color: isBot ? const Color(0xFF334155) : Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  )
                ),
              ),
            ),
            if (!isBot) const SizedBox(width: 8),
          ],
        ),
        if (isBot && m['action'] != null) 
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32),
            child: m['action'],
          ),
        if (isBot && quickReplies != null && quickReplies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 8, bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickReplies.map((reply) => _buildQuickReplyChip(reply)).toList(),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildQuickReplyChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
      onPressed: () {
        _addUserMessage(label);
        _processQuery(label.toLowerCase());
      },
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF1976D2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      pressElevation: 2,
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 8),
            Text(Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he' ? "העוזר מקליד..." : "AI is typing...", 
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      )
    );
  }

  Widget _buildInputArea(bool isRtl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _inputController,
                  onSubmitted: _handleManualInput,
                  decoration: InputDecoration(
                    hintText: isRtl ? "שאל אותי משהו..." : "Ask me anything...",
                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _handleManualInput(_inputController.text),
              child: const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF1976D2),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
