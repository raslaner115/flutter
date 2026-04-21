import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:intl/intl.dart' as intl;

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSearching = false;
  bool _isResolvingPhoneSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Set<String>> _phoneSearchTokensByUserId = {};
  final Set<String> _phoneFetchInProgressIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    if (user == null || user.isAnonymous) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            isRtl ? 'הודעות' : 'Messages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 24),
                Text(
                  isRtl
                      ? 'אנא התחבר כדי לצפות בהודעות'
                      : 'Please log in to view messages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isRtl ? 'חפש משתמש...' : 'Search user...',
                    border: InputBorder.none,
                    hintStyle: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  style: const TextStyle(fontSize: 18),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                )
              : Text(
                  isRtl ? 'הודעות' : 'Messages',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1976D2),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    isRtl ? 'צ׳אטים אחרונים' : 'Recent Chats',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[50],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chat_rooms')
                    .where('users', arrayContains: user.uid)
                    .orderBy('lastTimestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint("Stream error: \\${snapshot.error}");
                    return _buildErrorState(isRtl);
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1976D2),
                      ),
                    );
                  }

                  var docs = (snapshot.data?.docs ?? []).where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final users = data['users'] as List<dynamic>? ?? [];
                    return !users.contains('hiro_manager');
                  }).toList();

                  if (_isSearching &&
                      _searchController.text.trim().isNotEmpty) {
                    final query = _searchController.text.trim();
                    final queryLower = query.toLowerCase();
                    final queryDigits = _digitsOnly(query);
                    final queryTokens = _phoneMatchTokens(query);
                    _primePhoneCacheForDocs(docs, user.uid);

                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userNames =
                          data['userNames'] as Map<String, dynamic>? ?? {};
                      final users = data['users'] as List<dynamic>? ?? [];
                      final String otherUserId = users.firstWhere(
                        (id) => id != user.uid,
                        orElse: () => "",
                      );
                      final String otherUserName =
                          userNames[otherUserId]?.toString() ?? "";
                      final nameMatch = otherUserName.toLowerCase().contains(
                        queryLower,
                      );
                      if (nameMatch) return true;
                      if (queryDigits.isEmpty) return false;
                      final phoneTokens =
                          _phoneSearchTokensByUserId[otherUserId] ?? {};
                      for (final phoneToken in phoneTokens) {
                        if (phoneToken.contains(queryDigits)) return true;
                        for (final queryToken in queryTokens) {
                          if (queryToken.isEmpty) continue;
                          if (phoneToken.contains(queryToken)) return true;
                        }
                      }
                      return false;
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    if (_isSearching &&
                        _searchController.text.trim().isNotEmpty) {
                      return _buildPhoneSearchEmptyState(
                        localeCode: locale,
                        query: _searchController.text.trim(),
                      );
                    }
                    return _buildEmptyState(isRtl);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 20,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final List<dynamic> users = data['users'] ?? [];

                      if (users.length < 2) return const SizedBox.shrink();

                      final String otherUserId = users.firstWhere(
                        (id) => id != user.uid,
                        orElse: () => "",
                      );
                      if (otherUserId.isEmpty) return const SizedBox.shrink();

                      final Map<String, dynamic> userNames =
                          data['userNames'] ?? {};
                      final String otherUserName =
                          userNames[otherUserId] ?? "User";

                      final Map<String, dynamic> unreadCount =
                          (data['unreadCount'] as Map<String, dynamic>?) ?? {};
                      final int unread =
                          (unreadCount[user.uid] as num?)?.toInt() ?? 0;

                      return _buildChatTile(
                        context,
                        otherUserName,
                        data['lastMessage'] ?? "",
                        data['lastTimestamp'],
                        otherUserId,
                        unread,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    String name,
    String message,
    dynamic timestamp,
    String otherId,
    int unread,
  ) {
    final bool hasUnread = unread > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: const TextStyle(
            color: Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timestamp != null)
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? const Color(0xFF1976D2) : Colors.grey[500],
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasUnread ? const Color(0xFF1E293B) : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (hasUnread)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  unread > 99 ? '99+' : unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatPage(receiverId: otherId, receiverName: name),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isRtl) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isRtl ? 'אין הודעות עדיין' : 'No messages yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRtl
                ? 'ההודעות שלך יופיעו כאן'
                : 'Your conversations will appear here',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSearchEmptyState({
    required String localeCode,
    required String query,
  }) {
    final isRtl = localeCode == 'he' || localeCode == 'ar';
    final title = localeCode == 'he'
        ? 'לא נמצא משתמש'
        : localeCode == 'ar'
        ? 'تعذّر العثور على المستخدم'
        : "Can't find the user";
    final subtitle = localeCode == 'he'
        ? 'לא נמצא משתמש ברשימת השיחות לפי השם או המספר שחיפשת.'
        : localeCode == 'ar'
        ? 'لا يوجد مستخدم في قائمة المحادثات بالاسم أو الرقم الذي بحثت عنه.'
        : 'No user in your inbox list matches that name or phone number.';
    final buttonLabel = localeCode == 'he'
        ? 'חפש משתמש לפי מספר'
        : localeCode == 'ar'
        ? 'ابحث عن المستخدم بالرقم'
        : 'Search user by phone number';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 18),
            Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: FilledButton.icon(
                onPressed: _isResolvingPhoneSearch
                    ? null
                    : () {
                        if (_looksLikePhoneQuery(query)) {
                          _handleSearchSubmit(query, localeCode);
                          return;
                        }
                        _showPhoneSearchMessage(
                          localeCode == 'he'
                              ? 'כדי לחפש לפי מספר, הזן מספר טלפון.'
                              : localeCode == 'ar'
                              ? 'للبحث بالرقم، أدخل رقم هاتف.'
                              : 'To search by phone, enter a phone number.',
                        );
                      },
                icon: _isResolvingPhoneSearch
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_search_rounded),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isRtl) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            isRtl ? 'שגיאה בטעינת הודעות' : 'Error loading messages',
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () => setState(() {}),
            child: Text(isRtl ? 'נסה שוב' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return intl.DateFormat.Hm().format(date);
      }
      return intl.DateFormat('dd/MM/yy').format(date);
    }
    return "";
  }

  String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  Set<String> _phoneMatchTokens(String input) {
    final digits = _digitsOnly(input);
    if (digits.isEmpty) return {};
    final tokens = <String>{digits};

    if (digits.startsWith('0') && digits.length == 10) {
      tokens.add(digits.substring(1)); // 05xxxxxxxx -> 5xxxxxxxx
      tokens.add('972${digits.substring(1)}');
    }
    if (digits.startsWith('972') && digits.length >= 12) {
      tokens.add(digits.substring(3)); // +9725xxxxxxx -> 5xxxxxxx
      if (digits.substring(3).isNotEmpty) {
        tokens.add('0${digits.substring(3)}'); // 05xxxxxxxx
      }
    }
    if (digits.length == 9) {
      tokens.add('0$digits');
      tokens.add('972$digits');
    }
    return tokens;
  }

  void _primePhoneCacheForDocs(
    List<QueryDocumentSnapshot> docs,
    String currentUserId,
  ) {
    final missingIds = <String>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final users = data['users'] as List<dynamic>? ?? [];
      final String otherUserId = users.firstWhere(
        (id) => id != currentUserId,
        orElse: () => "",
      );
      if (otherUserId.isEmpty) continue;
      if (_phoneSearchTokensByUserId.containsKey(otherUserId)) continue;
      if (_phoneFetchInProgressIds.contains(otherUserId)) continue;
      _phoneFetchInProgressIds.add(otherUserId);
      missingIds.add(otherUserId);
    }

    if (missingIds.isEmpty) return;
    _fetchPhoneIndexForUserIds(missingIds);
  }

  Future<void> _fetchPhoneIndexForUserIds(List<String> userIds) async {
    for (var i = 0; i < userIds.length; i += 10) {
      final chunk = userIds.sublist(
        i,
        i + 10 > userIds.length ? userIds.length : i + 10,
      );

      try {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        final loaded = <String>{};
        for (final doc in snapshot.docs) {
          loaded.add(doc.id);
          final data = doc.data();
          final phone = (data['phone'] ?? data['phoneNumber'] ?? '')
              .toString()
              .trim();
          _phoneSearchTokensByUserId[doc.id] = _phoneMatchTokens(phone);
        }

        for (final id in chunk) {
          _phoneFetchInProgressIds.remove(id);
          if (!loaded.contains(id)) {
            _phoneSearchTokensByUserId[id] = {};
          }
        }

        if (mounted) setState(() {});
      } catch (e) {
        for (final id in chunk) {
          _phoneFetchInProgressIds.remove(id);
        }
        debugPrint('Failed to preload phone index for inbox search: $e');
      }
    }
  }

  Future<void> _handleSearchSubmit(String rawQuery, String localeCode) async {
    final query = rawQuery.trim();
    if (query.isEmpty || !_looksLikePhoneQuery(query)) return;
    if (_isResolvingPhoneSearch) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isResolvingPhoneSearch = true);
    try {
      final match = await _findUserByPhone(
        rawPhoneQuery: query,
        currentUserId: currentUser.uid,
      );

      if (!mounted) return;
      if (match == null) {
        _showPhoneSearchMessage(
          localeCode == 'he'
              ? 'אין משתמש עם מספר הטלפון הזה.'
              : localeCode == 'ar'
              ? 'لا يوجد مستخدم بهذا الرقم.'
              : 'There is no user with this phone number.',
        );
        return;
      }

      final shouldOpenChat = await _showUserCardBeforeChat(
        match: match,
        localeCode: localeCode,
      );
      if (!mounted || !shouldOpenChat) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            receiverId: match['id'] as String,
            receiverName: match['name'] as String,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingPhoneSearch = false);
      }
    }
  }

  bool _looksLikePhoneQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(trimmed)) return false;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7;
  }

  List<String> _phoneCandidates(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    final candidates = <String>{};

    if (normalized.isNotEmpty) {
      candidates.add(normalized);
    }
    if (digits.isNotEmpty) {
      candidates.add(digits);
    }

    if (digits.startsWith('0') && digits.length == 10) {
      candidates.add('+972${digits.substring(1)}');
    }
    if (digits.length == 9) {
      candidates.add('0$digits');
      candidates.add('+972$digits');
    }
    if (digits.startsWith('972')) {
      candidates.add('+$digits');
      if (digits.length > 4 && digits[3] == '0') {
        candidates.add('+972${digits.substring(4)}');
      }
    }
    if (normalized.startsWith('+9720') && normalized.length > 5) {
      candidates.add('+972${normalized.substring(5)}');
    }

    return candidates.take(10).toList();
  }

  Future<Map<String, dynamic>?> _findUserByPhone({
    required String rawPhoneQuery,
    required String currentUserId,
  }) async {
    final candidates = _phoneCandidates(rawPhoneQuery);
    if (candidates.isEmpty) return null;

    for (final field in ['phone', 'phoneNumber']) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .where(field, whereIn: candidates)
            .limit(10)
            .get();

        for (final doc in snapshot.docs) {
          if (doc.id == currentUserId) continue;
          final data = doc.data();
          final name = (data['name'] ?? '').toString().trim();
          final phone = (data['phone'] ?? data['phoneNumber'] ?? '')
              .toString()
              .trim();
          final role = (data['role'] ?? '').toString().trim();
          final city = (data['city'] ?? '').toString().trim();
          return {
            'id': doc.id,
            'name': name.isNotEmpty ? name : 'User',
            'phone': phone,
            'role': role,
            'city': city,
          };
        }
      } catch (e) {
        debugPrint('Phone lookup failed on field $field: $e');
      }
    }
    return null;
  }

  void _showPhoneSearchMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _showUserCardBeforeChat({
    required Map<String, dynamic> match,
    required String localeCode,
  }) async {
    final isRtl = localeCode == 'he' || localeCode == 'ar';
    final title = localeCode == 'he'
        ? 'משתמש נמצא'
        : localeCode == 'ar'
        ? 'تم العثور على المستخدم'
        : 'User found';
    final openChat = localeCode == 'he'
        ? 'פתח צ׳אט'
        : localeCode == 'ar'
        ? 'فتح الدردشة'
        : 'Open chat';
    final cancel = localeCode == 'he'
        ? 'ביטול'
        : localeCode == 'ar'
        ? 'إلغاء'
        : 'Cancel';
    final roleLabel = localeCode == 'he'
        ? 'תפקיד'
        : localeCode == 'ar'
        ? 'الدور'
        : 'Role';
    final cityLabel = localeCode == 'he'
        ? 'עיר'
        : localeCode == 'ar'
        ? 'المدينة'
        : 'City';
    final phoneLabel = localeCode == 'he'
        ? 'טלפון'
        : localeCode == 'ar'
        ? 'الهاتف'
        : 'Phone';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final name = (match['name'] ?? 'User').toString();
        final phone = (match['phone'] ?? '').toString();
        final role = (match['role'] ?? '').toString();
        final city = (match['city'] ?? '').toString();
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(
                        0xFF1976D2,
                      ).withValues(alpha: 0.12),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '$phoneLabel: ${phone.isNotEmpty ? phone : '-'}',
                    ),
                  ),
                  if (role.isNotEmpty)
                    Text(
                      '$roleLabel: $role',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  if (city.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$cityLabel: $city',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: Text(cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: Text(openChat),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result == true;
  }
}
