import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:untitled1/ptofile.dart';

class AdminPanel extends StatefulWidget {
  final bool showAppBar;
  const AdminPanel({super.key, this.showAppBar = true});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('Admin System Control'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('User Management'),
            _buildAdminTile(
              context,
              icon: Icons.people_alt_rounded,
              title: 'Normal Users',
              subtitle: 'View and manage client accounts',
              onTap: () => _showUserList(context, 'normal_users', 'Normal Users'),
            ),
            _buildAdminTile(
              context,
              icon: Icons.engineering_rounded,
              title: 'All Workers',
              subtitle: 'Manage all professional worker accounts',
              onTap: () => _showUserList(context, 'workers', 'Professional Workers'),
            ),
            _buildAdminTile(
              context,
              icon: Icons.verified_rounded,
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
              icon: Icons.campaign_rounded,
              title: 'System Broadcast / Ads',
              subtitle: 'Send ads with images and popups to all users',
              onTap: () => _showMarketingBroadcastDialog(context),
            ),
            const Divider(),
            _buildAdminTile(
              context,
              icon: Icons.sync_rounded,
              title: 'Sync Professions',
              subtitle: 'Upload all localized names and icons from JSON',
              onTap: () => _syncProfessionsFromJson(),
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

  Widget _buildAdminTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.red[900]),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Future<void> _syncProfessionsFromJson() async {
    try {
      final String response = await rootBundle.loadString('assets/profeissions.json');
      final List<dynamic> data = json.decode(response);
      
      WriteBatch batch = _firestore.batch();
      
      for (var item in data) {
        final String docId = item['id'].toString();
        final docRef = _firestore.collection('professions').doc(docId);
        batch.set(docRef, {
          'id': item['id'],
          'en': item['en'],
          'he': item['he'],
          'ar': item['ar'],
          'ru': item['ru'],
          'am': item['am'],
          'logo': item['logo'],
          'color': item['color'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      final metadataRef = _firestore.collection('metadata').doc('professions');
      batch.set(metadataRef, {
        'list': data.map((item) => item['en'].toString()).toList(),
        'items': data,
      }, SetOptions(merge: true));
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All professions synced to Firestore!'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync Error: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showUserList(BuildContext context, String collection, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserManagementSheet(
        title: title,
        collection: collection,
        firestore: _firestore,
        onDelete: (uid, name) => _confirmDeleteUser(uid, name, collection),
        onBan: (uid, name, isCurrentlyBanned) => _confirmBanUser(uid, name, collection, isCurrentlyBanned),
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

  void _showMarketingBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final msgController = TextEditingController();
    final linkController = TextEditingController();
    final btnTextController = TextEditingController(text: 'Learn More');
    File? imageFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.red),
              SizedBox(width: 10),
              Text('Marketing Ads / Popup'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Ad Title', hintText: 'Special Announcement')),
                TextField(controller: msgController, decoration: const InputDecoration(labelText: 'Ad Message', hintText: 'Write your message here...'), maxLines: 3),
                TextField(controller: linkController, decoration: const InputDecoration(labelText: 'Action Link (Optional)', hintText: 'https://...')),
                TextField(controller: btnTextController, decoration: const InputDecoration(labelText: 'Button Label', hintText: 'e.g. Visit Website')),
                const SizedBox(height: 16),
                if (imageFile != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(imageFile!, height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => setState(() => imageFile = null),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                      if (picked != null) {
                        setState(() => imageFile = File(picked.path));
                      }
                    },
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add Marketing Image'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (titleController.text.isEmpty || msgController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Message are required')));
                  return;
                }
                
                setState(() => isUploading = true);
                
                try {
                  String? imageUrl;
                  if (imageFile != null) {
                    final ref = FirebaseStorage.instance.ref().child('broadcasts/${DateTime.now().millisecondsSinceEpoch}.jpg');
                    await ref.putFile(imageFile!);
                    imageUrl = await ref.getDownloadURL();
                  }

                  await _firestore.collection('system_announcements').add({
                    'title': titleController.text,
                    'message': msgController.text,
                    'imageUrl': imageUrl,
                    'link': linkController.text.trim(),
                    'buttonText': btnTextController.text.trim(),
                    'type': 'marketing',
                    'isPopup': true,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint("Broadcast Error: $e");
                } finally {
                  if (mounted) setState(() => isUploading = false);
                }
              },
              child: isUploading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Blast to Everyone'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleVerification(String uid, bool approved) async {
    await _firestore.collection('verifications').doc(uid).update({'status': approved ? 'approved' : 'rejected'});
    if (approved) {
      await _firestore.collection('workers').doc(uid).update({
        'isBusinessVerified': true,
        'businessVerificationStatus': 'approved'
      });
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDeleteUser(String uid, String? name, String collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete $name? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Account'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection(collection).doc(uid).delete();
    }
  }

  Future<void> _confirmBanUser(String uid, String? name, String collection, bool isCurrentlyBanned) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCurrentlyBanned ? 'Unban User?' : 'Ban User?'),
        content: Text('Are you sure you want to ${isCurrentlyBanned ? 'unban' : 'ban'} $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isCurrentlyBanned ? Colors.green : Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isCurrentlyBanned ? 'Unban' : 'Ban User'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection(collection).doc(uid).update({
        'isBanned': !isCurrentlyBanned,
        'bannedAt': !isCurrentlyBanned ? FieldValue.serverTimestamp() : null,
      });
    }
  }

  Future<void> _removeCategory(String cat) async {
    await _firestore.collection('metadata').doc('professions').update({
      'list': FieldValue.arrayRemove([cat])
    });
  }

  Future<void> _addCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Category Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await _firestore.collection('metadata').doc('professions').update({
                'list': FieldValue.arrayUnion([controller.text.trim()])
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildViewDocButton(String label, String? url) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.file_present_rounded, color: Colors.red),
          onPressed: () { /* Launch URL */ },
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _UserManagementSheet extends StatefulWidget {
  final String title;
  final String collection;
  final FirebaseFirestore firestore;
  final Function(String, String?) onDelete;
  final Function(String, String?, bool) onBan;

  const _UserManagementSheet({
    required this.title,
    required this.collection,
    required this.firestore,
    required this.onDelete,
    required this.onBan,
  });

  @override
  State<_UserManagementSheet> createState() => _UserManagementSheetState();
}

class _UserManagementSheetState extends State<_UserManagementSheet> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestore.collection(widget.collection).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData) return const Center(child: Text('No data found'));
                
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? "").toString().toLowerCase();
                  final phone = (data['phone'] ?? "").toString().toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('No matching entries found'));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final user = docs[index].data() as Map<String, dynamic>;
                    final uid = docs[index].id;
                    final bool isBanned = user['isBanned'] ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (user['profileImageUrl'] != null && user['profileImageUrl'].toString().isNotEmpty)
                          ? NetworkImage(user['profileImageUrl']) 
                          : null,
                        child: (user['profileImageUrl'] == null || user['profileImageUrl'].toString().isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(user['name'] ?? 'No Name')),
                          if (isBanned) Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                            child: const Text('BANNED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      subtitle: Text('${user['phone'] ?? 'No Phone'}${widget.collection == 'workers' ? ' • ${user['profession'] ?? "Worker"}' : ""}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Profile(userId: uid))),
                          ),
                          IconButton(
                            icon: Icon(isBanned ? Icons.gavel_rounded : Icons.block_flipped, color: isBanned ? Colors.green : Colors.orange),
                            onPressed: () => widget.onBan(uid, user['name'], isBanned),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => widget.onDelete(uid, user['name']),
                          ),
                        ],
                      ),
                    );
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

class _AdminBottomSheet extends StatelessWidget {
  final String title;
  final Stream stream;
  final Widget Function(BuildContext, dynamic) itemBuilder;
  final bool isListStream;
  final List<Widget>? actions;

  const _AdminBottomSheet({
    required this.title,
    required this.stream,
    required this.itemBuilder,
    this.isListStream = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
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
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData) return const Center(child: Text('No data found'));
                
                final List items = isListStream ? (snapshot.data as List) : (snapshot.data as QuerySnapshot).docs;
                if (items.isEmpty) return const Center(child: Text('No entries found'));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: items.length,
                  itemBuilder: (context, index) => itemBuilder(context, items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
