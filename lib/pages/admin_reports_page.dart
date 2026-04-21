import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/pages/fullscreen_media_viewer.dart';
import 'package:untitled1/ptofile.dart';
import 'package:untitled1/widgets/cached_video_player.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'all';

  static const List<String> _filters = ['all', 'open', 'resolved'];

  String _titleCase(String value) {
    final normalized = value.replaceAll('_', ' ');
    if (normalized.isEmpty) return '-';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  ({Color bg, Color fg, IconData icon}) _statusMeta(String status) {
    switch (status) {
      case 'resolved':
        return (
          bg: Colors.green.withValues(alpha: 0.12),
          fg: Colors.green.shade800,
          icon: Icons.check_circle_outline,
        );
      case 'in_progress':
        return (
          bg: Colors.blue.withValues(alpha: 0.12),
          fg: Colors.blue.shade800,
          icon: Icons.sync,
        );
      default:
        return (
          bg: Colors.orange.withValues(alpha: 0.12),
          fg: Colors.orange.shade800,
          icon: Icons.pending_outlined,
        );
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String content,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _markResolved(String reportId) async {
    final confirmed = await _confirmAction(
      title: 'Resolve Report',
      content: 'Mark this report as resolved?',
      confirmLabel: 'Mark Resolved',
    );
    if (!confirmed) return;

    try {
      final reportDoc = await _firestore
          .collection('reports')
          .doc(reportId)
          .get();
      final reportData = reportDoc.data() ?? <String, dynamic>{};
      final reporterId = (reportData['reporterId'] ?? '').toString();
      final subject = (reportData['subject'] ?? reportData['reason'] ?? 'דיווח')
          .toString()
          .trim();
      final wasResolved =
          (reportData['status'] ?? 'open').toString() == 'resolved';

      await _firestore.collection('reports').doc(reportId).set({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      if (!wasResolved) {
        await _firestore.collection('metadata').doc('system').set({
          'reportsCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }

      await _sendResolvedMessageToReporter(
        reportId: reportId,
        reporterId: reporterId,
        subject: subject,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report marked as resolved.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update report status.')),
      );
    }
  }

  String _getChatRoomId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  Future<void> _sendResolvedMessageToReporter({
    required String reportId,
    required String reporterId,
    required String subject,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null || reporterId.isEmpty || reporterId == 'app') return;

    final chatRoomId = _getChatRoomId(adminId, reporterId);

    final existingResolved = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('type', isEqualTo: 'report_resolved')
        .where('reportId', isEqualTo: reportId)
        .limit(1)
        .get();

    if (existingResolved.docs.isNotEmpty) return;

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': adminId,
          'receiverId': reporterId,
          'message':
              'הדיווח שלך סומן כטופל: ${subject.isEmpty ? 'דיווח' : subject}',
          'type': 'report_resolved',
          'reportId': reportId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': '✅ הדיווח טופל',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [adminId, reporterId],
    }, SetOptions(merge: true));

    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'unreadCount.$reporterId': FieldValue.increment(1),
    });
  }

  Future<void> _deleteReport(String reportId) async {
    final confirmed = await _confirmAction(
      title: 'Delete Report',
      content: 'This action cannot be undone. Delete this report?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await _firestore.collection('reports').doc(reportId).delete();
      await _firestore.collection('metadata').doc('system').set({
        'reportsCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete report.')));
    }
  }

  String _displayTimestamp(Timestamp? ts) {
    if (ts == null) return 'Unknown time';
    final d = ts.toDate();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$month-$day $hour:$minute';
  }

  Widget _statusBadge(String status) {
    final meta = _statusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.fg),
          const SizedBox(width: 4),
          Text(
            _titleCase(status),
            style: TextStyle(color: meta.fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(int total, int open, int resolved) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Total: $total  |  Open: $open  |  Resolved: $resolved',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: _filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_titleCase(filter)),
              selected: _statusFilter == filter,
              onSelected: (_) => setState(() => _statusFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final msg = _statusFilter == 'all'
        ? 'No reports found.'
        : 'No ${_titleCase(_statusFilter).toLowerCase()} reports.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _extractAttachments(Map<String, dynamic> data) {
    return ((data['attachments'] ?? []) as List)
        .whereType<Map>()
        .map(
          (e) => {
            'type': (e['type'] ?? '').toString(),
            'url': (e['url'] ?? '').toString(),
          },
        )
        .where((e) => e['url']!.isNotEmpty)
        .toList();
  }

  Widget _buildAttachmentsPreview(List<Map<String, String>> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = attachments[index];
          final isImage = item['type'] == 'image';
          final url = item['url'] ?? '';
          return InkWell(
            onTap: () => _openMediaViewer(attachments, index),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 170,
                color: Colors.black12,
                child: isImage
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.broken_image)),
                      )
                    : CachedVideoPlayer(url: url, play: false),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openMediaViewer(List<Map<String, String>> attachments, int index) {
    final urls = attachments
        .map((item) => (item['url'] ?? '').toString())
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenMediaViewer(urls: urls, initialIndex: index),
      ),
    );
  }

  Future<void> _openReportDetails(
    String reportId,
    Map<String, dynamic> data,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminReportDetailsPage(reportId: reportId, data: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Reports')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load reports right now.'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;
          final openCount = allDocs.where((d) {
            return (d.data()['status'] ?? 'open').toString() != 'resolved';
          }).length;
          final resolvedCount = allDocs.length - openCount;

          final docs = allDocs.where((d) {
            if (_statusFilter == 'all') return true;
            return (d.data()['status'] ?? 'open').toString() == _statusFilter;
          }).toList();

          if (docs.isEmpty) {
            return Column(
              children: [
                _buildSummary(allDocs.length, openCount, resolvedCount),
                _buildFilters(),
                Expanded(child: _buildEmptyState()),
              ],
            );
          }

          return Column(
            children: [
              _buildSummary(allDocs.length, openCount, resolvedCount),
              _buildFilters(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final reportId = doc.id;
                    final reporterId = (data['reporterId'] ?? '').toString();
                    final reportedId = (data['reportedId'] ?? '').toString();
                    final subject = (data['subject'] ?? '').toString();
                    final reason = (data['reason'] ?? '').toString();
                    final details = (data['details'] ?? '').toString();
                    final reportType = (data['reportType'] ?? '').toString();
                    final source = (data['source'] ?? '').toString();
                    final status = (data['status'] ?? 'open').toString();
                    final timestamp = data['timestamp'] as Timestamp?;
                    final attachments = _extractAttachments(data);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0.6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openReportDetails(reportId, data),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      subject.isNotEmpty
                                          ? subject
                                          : (reason.isEmpty
                                                ? 'General issue'
                                                : reason),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  _statusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reporter: ${reporterId.isEmpty ? '-' : reporterId}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              Text(
                                'Reported: ${reportedId.isEmpty ? '-' : reportedId}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      'Created: ${_displayTimestamp(timestamp)}',
                                    ),
                                  ),
                                  if (source.isNotEmpty)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('Source: $source'),
                                    ),
                                  if (reportType.isNotEmpty)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('Type: $reportType'),
                                    ),
                                ],
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  details,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (attachments.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildAttachmentsPreview(attachments),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () =>
                                        _openReportDetails(reportId, data),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Take Me to Report'),
                                  ),
                                  if (status != 'resolved')
                                    OutlinedButton.icon(
                                      onPressed: () => _markResolved(reportId),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text('Resolve'),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => _deleteReport(reportId),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminReportDetailsPage extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const AdminReportDetailsPage({
    super.key,
    required this.reportId,
    required this.data,
  });

  @override
  State<AdminReportDetailsPage> createState() => _AdminReportDetailsPageState();
}

class _AdminReportDetailsPageState extends State<AdminReportDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
  }

  String _displayTimestamp(Timestamp? ts) {
    if (ts == null) return 'Unknown time';
    final d = ts.toDate();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$month-$day $hour:$minute';
  }

  String _titleCase(String value) {
    final normalized = value.replaceAll('_', ' ');
    if (normalized.isEmpty) return '-';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  ({Color bg, Color fg, IconData icon}) _statusMeta(String status) {
    switch (status) {
      case 'resolved':
        return (
          bg: Colors.green.withValues(alpha: 0.12),
          fg: Colors.green.shade800,
          icon: Icons.check_circle_outline,
        );
      case 'in_progress':
        return (
          bg: Colors.blue.withValues(alpha: 0.12),
          fg: Colors.blue.shade800,
          icon: Icons.sync,
        );
      default:
        return (
          bg: Colors.orange.withValues(alpha: 0.12),
          fg: Colors.orange.shade800,
          icon: Icons.pending_outlined,
        );
    }
  }

  Widget _statusBadge(String status) {
    final meta = _statusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.fg),
          const SizedBox(width: 4),
          Text(
            _titleCase(status),
            style: TextStyle(color: meta.fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String content,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _markResolved() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmAction(
      title: 'Resolve Report',
      content: 'Mark this report as resolved?',
      confirmLabel: 'Mark Resolved',
    );
    if (!confirmed) return;

    try {
      final now = Timestamp.now();
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final reporterId = (_data['reporterId'] ?? '').toString();
      final subject = (_data['subject'] ?? _data['reason'] ?? 'דיווח')
          .toString()
          .trim();
      final reportDoc = await _firestore
          .collection('reports')
          .doc(widget.reportId)
          .get();
      final wasResolved =
          (reportDoc.data()?['status'] ?? _data['status'] ?? 'open')
              .toString() ==
          'resolved';
      await _firestore.collection('reports').doc(widget.reportId).set({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': adminId,
      }, SetOptions(merge: true));

      if (!wasResolved) {
        await _firestore.collection('metadata').doc('system').set({
          'reportsCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }

      await _sendResolvedMessageToReporter(
        reportId: widget.reportId,
        reporterId: reporterId,
        subject: subject,
      );

      if (!mounted) return;
      setState(() {
        _data['status'] = 'resolved';
        _data['resolvedAt'] = now;
        _data['resolvedBy'] = adminId;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Report marked as resolved.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update report status.')),
      );
    }
  }

  Future<void> _deleteReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmAction(
      title: 'Delete Report',
      content: 'This action cannot be undone. Delete this report?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await _firestore.collection('reports').doc(widget.reportId).delete();
      await _firestore.collection('metadata').doc('system').set({
        'reportsCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Report deleted.')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete report.')),
      );
    }
  }

  String _getChatRoomId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  Future<void> _sendResolvedMessageToReporter({
    required String reportId,
    required String reporterId,
    required String subject,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null || reporterId.isEmpty || reporterId == 'app') return;

    final chatRoomId = _getChatRoomId(adminId, reporterId);

    final existingResolved = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('type', isEqualTo: 'report_resolved')
        .where('reportId', isEqualTo: reportId)
        .limit(1)
        .get();

    if (existingResolved.docs.isNotEmpty) return;

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': adminId,
          'receiverId': reporterId,
          'message':
              'הדיווח שלך סומן כטופל: ${subject.isEmpty ? 'דיווח' : subject}',
          'type': 'report_resolved',
          'reportId': reportId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': '✅ הדיווח טופל',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'users': [adminId, reporterId],
    }, SetOptions(merge: true));

    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'unreadCount.$reporterId': FieldValue.increment(1),
    });
  }

  Future<void> _answerReporter(String reporterId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || reporterId.isEmpty || reporterId == 'app') {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final chatRoomId = _getChatRoomId(currentUserId, reporterId);
    final subject = (_data['subject'] ?? _data['reason'] ?? 'Report')
        .toString()
        .trim();

    try {
      final existingReference = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('type', isEqualTo: 'report_reference')
          .where('reportId', isEqualTo: widget.reportId)
          .limit(1)
          .get();

      if (existingReference.docs.isEmpty) {
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .add({
              'senderId': currentUserId,
              'receiverId': reporterId,
              'message': 'Admin replied to your report: $subject',
              'type': 'report_reference',
              'reportId': widget.reportId,
              'timestamp': FieldValue.serverTimestamp(),
            });

        await _firestore.collection('chat_rooms').doc(chatRoomId).set({
          'lastMessage': '📌 Report update',
          'lastTimestamp': FieldValue.serverTimestamp(),
          'users': [currentUserId, reporterId],
        }, SetOptions(merge: true));

        await _firestore.collection('chat_rooms').doc(chatRoomId).update({
          'unreadCount.$reporterId': FieldValue.increment(1),
        });
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            receiverId: reporterId,
            receiverName: reporterId,
            reportContextId: widget.reportId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to open chat with report link.')),
      );
    }
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _profileLinkField(String label, String userId) {
    final isClickable = userId.isNotEmpty && userId != 'app';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: isClickable
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Profile(userId: userId),
                        ),
                      );
                    }
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  userId.isEmpty ? '-' : userId,
                  style: TextStyle(
                    color: isClickable ? Colors.blue.shade700 : Colors.black87,
                    decoration: isClickable
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: isClickable
                        ? Colors.blue.shade700
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _extractAttachments(Map<String, dynamic> data) {
    return ((data['attachments'] ?? []) as List)
        .whereType<Map>()
        .map(
          (e) => {
            'type': (e['type'] ?? '').toString(),
            'url': (e['url'] ?? '').toString(),
          },
        )
        .where((e) => e['url']!.isNotEmpty)
        .toList();
  }

  Widget _buildAttachmentsPreview(List<Map<String, String>> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = attachments[index];
          final isImage = item['type'] == 'image';
          final url = item['url'] ?? '';
          return InkWell(
            onTap: () => _openMediaViewer(attachments, index),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 240,
                color: Colors.black12,
                child: isImage
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.broken_image)),
                      )
                    : CachedVideoPlayer(url: url, play: false),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openMediaViewer(List<Map<String, String>> attachments, int index) {
    final urls = attachments
        .map((item) => (item['url'] ?? '').toString())
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenMediaViewer(urls: urls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = (_data['subject'] ?? '').toString();
    final reason = (_data['reason'] ?? '').toString();
    final details = (_data['details'] ?? '').toString();
    final status = (_data['status'] ?? 'open').toString();
    final source = (_data['source'] ?? '').toString();
    final reportType = (_data['reportType'] ?? '').toString();
    final reporterId = (_data['reporterId'] ?? '').toString();
    final reportedId = (_data['reportedId'] ?? '').toString();
    final resolvedBy = (_data['resolvedBy'] ?? '').toString();
    final timestamp = _data['timestamp'] as Timestamp?;
    final resolvedAt = _data['resolvedAt'] as Timestamp?;
    final attachments = _extractAttachments(_data);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.isNotEmpty
                                ? subject
                                : (reason.isEmpty ? 'General issue' : reason),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Created: ${_displayTimestamp(timestamp)}',
                          ),
                        ),
                        if (source.isNotEmpty)
                          Chip(label: Text('Source: $source')),
                        if (reportType.isNotEmpty)
                          Chip(label: Text('Type: $reportType')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Report ID', widget.reportId),
                    _profileLinkField('Reporter ID', reporterId),
                    _profileLinkField('Reported ID', reportedId),
                    _field('Resolved At', _displayTimestamp(resolvedAt)),
                    _field('Resolved By', resolvedBy),
                    if (reason.isNotEmpty && subject.isNotEmpty)
                      _field('Reason', reason),
                  ],
                ),
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(details),
                    ],
                  ),
                ),
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildAttachmentsPreview(attachments),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Raw Data',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: _data.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _field(entry.key, entry.value?.toString() ?? ''),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (reporterId.isNotEmpty && reporterId != 'app')
                  FilledButton.icon(
                    onPressed: () => _answerReporter(reporterId),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Answer Reporter'),
                  ),
                FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: widget.reportId),
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Report ID copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Report ID'),
                ),
                if (reportedId.isNotEmpty && reportedId != 'app')
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Profile(userId: reportedId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Open Profile'),
                  ),
                if (status != 'resolved')
                  OutlinedButton.icon(
                    onPressed: _markResolved,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Resolved'),
                  ),
                TextButton.icon(
                  onPressed: _deleteReport,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
