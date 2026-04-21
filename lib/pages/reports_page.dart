import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/widgets/cached_video_player.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  String _statusFilter = 'all';
  static const int _maxReportAttachments = 5;

  static const List<String> _statuses = ['all', 'open', 'resolved'];
  static const List<String> _readySubjects = [
    'General',
    'Bug Report',
    'Payment Issue',
    'Login Problem',
    'Feature Request',
    'Account Support',
    'Performance Issue',
    'Content Problem',
  ];

  String _titleCaseStatus(String status) {
    final normalized = status.replaceAll('_', ' ');
    if (normalized.isEmpty) return 'Unknown';
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
      case 'rejected':
        return (
          bg: Colors.red.withValues(alpha: 0.12),
          fg: Colors.red.shade800,
          icon: Icons.cancel_outlined,
        );
      case 'open':
      default:
        return (
          bg: Colors.orange.withValues(alpha: 0.12),
          fg: Colors.orange.shade800,
          icon: Icons.pending_outlined,
        );
    }
  }

  Future<void> _openCreateReportDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    String selectedSubject = _readySubjects.first;
    final attachments = <_DraftReportAttachment>[];

    Future<void> pickImage(StateSetter setDialogState) async {
      if (attachments.length >= _maxReportAttachments) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can attach up to 5 files only.')),
        );
        return;
      }
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (pickedFiles.isEmpty) return;

      final remainingSlots = _maxReportAttachments - attachments.length;
      final filesToAdd = pickedFiles.take(remainingSlots).toList();
      setDialogState(() {
        attachments.addAll(
          filesToAdd.map((f) => _DraftReportAttachment(type: 'image', file: f)),
        );
      });

      if (pickedFiles.length > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only 5 total attachments are allowed.'),
          ),
        );
      }
    }

    Future<void> pickVideo(StateSetter setDialogState) async {
      if (attachments.length >= _maxReportAttachments) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can attach up to 5 files only.')),
        );
        return;
      }
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      setDialogState(() {
        attachments.add(_DraftReportAttachment(type: 'video', file: picked));
      });
    }

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create Report'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell us what happened so we can investigate quickly.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _readySubjects
                        .map(
                          (subject) => DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedSubject = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Short title for the issue',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 5,
                    maxLength: 600,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      hintText: 'Describe the issue and steps to reproduce...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Attachments (images/videos)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${attachments.length}/$_maxReportAttachments selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => pickImage(setDialogState),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Add Image'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => pickVideo(setDialogState),
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Add Video'),
                      ),
                    ],
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 90,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(attachments.length, (index) {
                            final item = attachments[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == attachments.length - 1 ? 0 : 8,
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: item.type == 'image'
                                        ? Image.file(
                                            File(item.file.path),
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.black87,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.videocam_rounded,
                                                  color: Colors.white70,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.file.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          attachments.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );

    if (submit != true) return;

    final subject = selectedSubject.trim();
    final reason = reasonController.text.trim();
    final details = detailsController.text.trim();
    final progress = ValueNotifier<double>(attachments.isEmpty ? 0.8 : 0.0);

    try {
      var progressDialogShown = false;
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                title: const Text('Sending report'),
                content: ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (context, value, _) {
                    final clamped = value.clamp(0.0, 1.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: clamped),
                        const SizedBox(height: 10),
                        Text('${(clamped * 100).toStringAsFixed(0)}%'),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
        progressDialogShown = true;
      }

      List<Map<String, String>> uploadedAttachments = [];
      if (attachments.isNotEmpty) {
        uploadedAttachments = await _uploadReportAttachments(
          reporterId: user.uid,
          attachments: attachments,
          onProgress: (value) {
            progress.value = value * 0.85;
          },
        );
      }

      progress.value = 0.9;
      await _firestore.collection('reports').add({
        'reporterId': user.uid,
        'reportedId': 'app',
        'reportType': 'user_report',
        'source': 'reports_page',
        'subject': subject.isEmpty ? 'General' : subject,
        'reason': reason.isEmpty ? 'General issue' : reason,
        'details': details,
        'attachments': uploadedAttachments,
        'status': 'open',
        'timestamp': FieldValue.serverTimestamp(),
      });

      progress.value = 0.98;
      await _firestore.collection('metadata').doc('system').set({
        'reportsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      progress.value = 1.0;

      if (!mounted) return;
      if (progressDialogShown &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
    } catch (_) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to submit report.')));
    } finally {
      progress.dispose();
    }
  }

  Future<List<Map<String, String>>> _uploadReportAttachments({
    required String reporterId,
    required List<_DraftReportAttachment> attachments,
    void Function(double progress)? onProgress,
  }) async {
    final uploaded = <Map<String, String>>[];
    for (var i = 0; i < attachments.length; i++) {
      final item = attachments[i];
      final ext = item.file.name.contains('.')
          ? item.file.name.split('.').last
          : (item.type == 'image' ? 'jpg' : 'mp4');
      final path =
          'reports/$reporterId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final ref = _storage.ref().child(path);
      final task = ref.putFile(
        File(item.file.path),
        SettableMetadata(
          contentType: item.type == 'image' ? 'image/jpeg' : 'video/mp4',
        ),
      );
      final subscription = task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final current = snapshot.bytesTransferred;
        final fileProgress = total > 0 ? current / total : 0.0;
        final overall = (i + fileProgress) / attachments.length;
        onProgress?.call(overall);
      });
      await task;
      await subscription.cancel();
      onProgress?.call((i + 1) / attachments.length);
      final url = await ref.getDownloadURL();
      uploaded.add({'type': item.type, 'url': url, 'fileName': item.file.name});
    }
    return uploaded;
  }

  Query<Map<String, dynamic>> _reportsQuery(String uid) {
    var query = _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: uid);
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    return query;
  }

  String _formatDate(DateTime createdAt) {
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '${createdAt.year}-$month-$day $hour:$minute';
  }

  Widget _statusBadge(String status) {
    final statusMeta = _statusMeta(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusMeta.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusMeta.icon, size: 14, color: statusMeta.fg),
          const SizedBox(width: 4),
          Text(
            _titleCaseStatus(status),
            style: TextStyle(
              color: statusMeta.fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0.6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline, size: 46, color: Colors.blueGrey),
                  SizedBox(height: 12),
                  Text(
                    'Sign in required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please sign in to create reports and track their status updates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: _statuses.map((status) {
          final selected = _statusFilter == status;
          final statusMeta = _statusMeta(status);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: status == 'all'
                  ? const Icon(Icons.apps, size: 16)
                  : Icon(statusMeta.icon, size: 16),
              label: Text(_titleCaseStatus(status)),
              selected: selected,
              onSelected: (_) => setState(() => _statusFilter = status),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopSummary() {
    final activeFilter = _statusFilter == 'all'
        ? 'Showing all reports'
        : 'Filtered by ${_titleCaseStatus(_statusFilter)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_outlined, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Reports',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeFilter,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _statusFilter == 'all'
        ? 'No reports yet. Start by creating your first report.'
        : 'No ${_titleCaseStatus(_statusFilter).toLowerCase()} reports found.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.report_problem_outlined,
                size: 44,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openCreateReportDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data, String id) {
    final reason = (data['reason'] ?? '').toString();
    final details = (data['details'] ?? '').toString();
    final status = (data['status'] ?? 'open').toString();
    final subject = (data['subject'] ?? data['priority'] ?? 'General')
        .toString()
        .trim();
    final attachments = ((data['attachments'] ?? []) as List)
        .whereType<Map>()
        .map(
          (e) => {
            'type': (e['type'] ?? '').toString(),
            'url': (e['url'] ?? '').toString(),
            'fileName': (e['fileName'] ?? '').toString(),
          },
        )
        .where((e) => e['url']!.isNotEmpty)
        .toList();
    final ts = data['timestamp'] as Timestamp?;
    final createdAt = ts?.toDate();
    final dateText = createdAt == null
        ? 'Pending time sync'
        : _formatDate(createdAt);

    return Card(
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
                    reason.isEmpty ? 'General issue' : reason,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Subject: ${subject.isEmpty ? 'General' : subject}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  dateText,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(details),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = attachments[index];
                    final isImage = item['type'] == 'image';
                    final url = item['url'] ?? '';
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 180,
                        color: Colors.black12,
                        child: isImage
                            ? Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(Icons.broken_image),
                                    ),
                              )
                            : CachedVideoPlayer(url: url, play: false),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ID: $id',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: id));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report ID copied'),
                        duration: Duration(milliseconds: 1200),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 15),
                  label: const Text('Copy ID'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      floatingActionButton: user == null || user.isAnonymous
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateReportDialog,
              icon: const Icon(Icons.edit_note),
              label: const Text('New Report'),
            ),
      body: user == null || user.isAnonymous
          ? _buildSignedOutState()
          : Column(
              children: [
                _buildTopSummary(),
                _buildFilterBar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _reportsQuery(user.uid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 48,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Could not load reports. Please try again shortly.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final ta = a.data()['timestamp'] as Timestamp?;
                          final tb = b.data()['timestamp'] as Timestamp?;
                          if (ta == null && tb == null) return 0;
                          if (ta == null) return 1;
                          if (tb == null) return -1;
                          return tb.compareTo(ta);
                        });

                      if (docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return _buildReportCard(doc.data(), doc.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _DraftReportAttachment {
  final String type;
  final XFile file;

  const _DraftReportAttachment({required this.type, required this.file});
}
