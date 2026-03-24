import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/pages/request_details.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'התראות',
          'empty': 'אין התראות חדשות',
          'clear': 'נקה הכל',
          'accept': 'אישור',
          'decline': 'דחייה',
          'accepted': 'התקבל',
          'declined': 'נדחה',
          'call': 'התקשר',
          'details': 'פרטים',
        };
      case 'ar':
        return {
          'title': 'الإشعارات',
          'empty': 'لا توجد إشعارات جديدة',
          'clear': 'مسح الكل',
          'accept': 'قبول',
          'decline': 'رفض',
          'accepted': 'تم القبول',
          'declined': 'تم الرفض',
          'call': 'اتصال',
          'details': 'تفاصيل',
        };
      default:
        return {
          'title': 'Notifications',
          'empty': 'No new notifications',
          'clear': 'Clear All',
          'accept': 'Accept',
          'decline': 'Decline',
          'accepted': 'Accepted',
          'declined': 'Declined',
          'call': 'Call',
          'details': 'Details',
        };
    }
  }

  Future<void> _handleCall(BuildContext context, String? userId) async {
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final phone = doc.data()?['phone'];
      if (phone != null && phone.toString().isNotEmpty) {
        final Uri url = Uri.parse('tel:$phone');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final user = FirebaseAuth.instance.currentUser;
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || 
                  Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(strings['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          actions: [
            if (user != null && !user.isAnonymous)
              TextButton(
                onPressed: () async {
                   final batch = FirebaseFirestore.instance.batch();
                   final snapshots = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .get();
                   for (var doc in snapshots.docs) {
                     batch.delete(doc.reference);
                   }
                   await batch.commit();
                },
                child: Text(strings['clear']!, style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: user == null || user.isAnonymous
            ? _buildEmptyState(strings)
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(strings);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildNotificationCard(context, doc.id, data, strings);
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(Map<String, String> strings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(strings['empty']!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, String docId, Map<String, dynamic> data, Map<String, String> strings) {
    final bool isWorkRequest = data['type'] == 'work_request';
    final bool isDeclineNotif = data['type'] == 'request_declined';
    final String status = data['status'] ?? 'none';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isWorkRequest && status == 'pending'
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsPage(notificationId: docId, data: data)))
            : null,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWorkRequest ? Icons.calendar_today : Icons.notifications_active,
                  color: const Color(0xFF1976D2)
                ),
              ),
              title: Text(
                data['title'] ?? 'Notification',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(data['body'] ?? ''),
                  if (data['timestamp'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(data['timestamp']),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ],
              ),
              trailing: isWorkRequest && status == 'pending' ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
            ),
            if ((isWorkRequest && status != 'pending') || isDeclineNotif)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: (status == 'accepted' && !isDeclineNotif) ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            isDeclineNotif ? strings['declined']! : (status == 'accepted' ? strings['accepted']! : strings['declined']!),
                            style: TextStyle(
                              color: (status == 'accepted' && !isDeclineNotif) ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (status == 'declined' || isDeclineNotif) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _handleCall(context, data['fromId']),
                        icon: const Icon(Icons.call, size: 18),
                        label: Text(strings['call']!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return '';
  }
}
