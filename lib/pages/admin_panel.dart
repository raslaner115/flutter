import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled1/ptofile.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin System Control'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('User Management'),
            _buildAdminTile(
              context,
              icon: Icons.people_alt_rounded,
              title: 'All Users',
              subtitle: 'View, edit or delete any user account',
              onTap: () => _showAllUsers(context),
            ),
            _buildAdminTile(
              context,
              icon: Icons.engineering_rounded,
              title: 'Professional Verifications',
              subtitle: 'Approve or reject business documents',
              onTap: () => _showVerifications(context),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Content Moderation'),
            _buildAdminTile(
              context,
              icon: Icons.report_rounded,
              title: 'Reports Queue',
              subtitle: 'Handle user and project reports',
              onTap: () => _showReports(context),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('System Configuration'),
            _buildAdminTile(
              context,
              icon: Icons.category_rounded,
              title: 'Profession Categories',
              subtitle: 'Add, remove or edit system professions',
              onTap: () => _showCategoriesEditor(context),
            ),
            _buildAdminTile(
              context,
              icon: Icons.notifications_active_rounded,
              title: 'System Broadcast',
              subtitle: 'Send push notification to all users',
              onTap: () => _showBroadcastDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.red[900],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showAllUsers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminBottomSheet(
        title: 'System Users',
        stream: _firestore.collection('users').orderBy('createdAt', descending: true).snapshots(),
        itemBuilder: (context, doc) {
          final user = doc.data() as Map<String, dynamic>;
          final uid = doc.id;
          
          String type = 'Normal';
          if (user['isAdmin'] == true) type = 'Admin';
          else if (user['isWorker'] == true) type = 'Worker';

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty 
                ? NetworkImage(user['profileImageUrl']) 
                : null,
              child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(user['name'] ?? 'No Name'),
            subtitle: Text('$type • ${user['phone'] ?? 'No Phone'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Profile(userId: uid))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDeleteUser(uid, user['name']),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVerifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminBottomSheet(
        title: 'Business Verifications',
        stream: _firestore.collection('verifications').where('status', isEqualTo: 'pending').snapshots(),
        itemBuilder: (context, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              title: Text(data['businessName'] ?? 'Business'),
              subtitle: Text('ID: ${data['businessId']} • ${data['dealerType']}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow('Address', data['address']),
                      _buildInfoRow('Tax Branch', data['taxBranch']),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildViewDocButton('ID Card', data['idCardUrl']),
                          _buildViewDocButton('Certificate', data['businessCertUrl']),
                          if (data['insuranceUrl'] != null) _buildViewDocButton('Insurance', data['insuranceUrl']),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _handleVerification(doc.id, true),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              onPressed: () => _handleVerification(doc.id, false),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReports(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminBottomSheet(
        title: 'Active Reports',
        stream: _firestore.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        itemBuilder: (context, doc) {
          final report = doc.data() as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('Reason: ${report['reason']}'),
              subtitle: Text('Reported ID: ${report['reportedId']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Profile(userId: report['reportedId']))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    onPressed: () => _firestore.collection('reports').doc(doc.id).delete(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCategoriesEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminBottomSheet(
        title: 'Profession Categories',
        stream: _firestore.collection('metadata').doc('professions').snapshots().map((s) => s.exists ? (s.data() as Map<String, dynamic>)['list'] as List : []),
        isListStream: true,
        itemBuilder: (context, item) {
          final String cat = item.toString();
          return ListTile(
            title: Text(cat),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _removeCategory(cat),
            ),
          );
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: Colors.blue),
            onPressed: () => _addCategoryDialog(context),
          )
        ],
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: msgController, decoration: const InputDecoration(labelText: 'Message'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _sendBroadcast(titleController.text, msgController.text),
            child: const Text('Send to All'),
          )
        ],
      ),
    );
  }

  Future<void> _handleVerification(String uid, bool approved) async {
    await _firestore.collection('verifications').doc(uid).update({'status': approved ? 'approved' : 'rejected'});
    if (approved) {
      await _firestore.collection('users').doc(uid).update({
        'isBusinessVerified': true,
        'businessVerificationStatus': 'approved'
      });
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendBroadcast(String title, String msg) async {
    if (title.isEmpty || msg.isEmpty) return;
    await _firestore.collection('system_announcements').add({
      'title': title,
      'message': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Implementation for push notifications would go here
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDeleteUser(String uid, String? name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete $name? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection('users').doc(uid).delete();
    }
  }

  Future<void> _addCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Profession'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g. Electrician')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _firestore.collection('metadata').doc('professions').set({
        'list': FieldValue.arrayUnion([name])
      }, SetOptions(merge: true));
    }
  }

  Future<void> _removeCategory(String cat) async {
    await _firestore.collection('metadata').doc('professions').update({
      'list': FieldValue.arrayRemove([cat])
    });
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value?.toString() ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildViewDocButton(String label, String? url) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.description, color: Colors.blue),
          onPressed: () { /* Implementation to open URL */ },
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildAdminTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.red[900]),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}

class _AdminBottomSheet extends StatelessWidget {
  final String title;
  final Stream stream;
  final Widget Function(BuildContext, dynamic) itemBuilder;
  final List<Widget>? actions;
  final bool isListStream;

  const _AdminBottomSheet({
    required this.title,
    required this.stream,
    required this.itemBuilder,
    this.actions,
    this.isListStream = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (actions != null) Row(children: actions!),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final dynamic data = snapshot.data;
                if (isListStream) {
                  final list = data as List;
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) => itemBuilder(context, list[index]),
                  );
                } else {
                  final docs = (data as QuerySnapshot).docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) => itemBuilder(context, docs[index]),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
