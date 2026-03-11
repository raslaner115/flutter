import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:untitled1/language_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:untitled1/pages/edit_profile.dart';
import 'package:untitled1/pages/sighn_in.dart';
import 'package:untitled1/pages/schedule.dart';
import 'package:untitled1/pages/average_prices.dart';
import 'package:untitled1/pages/complete_worker_profile.dart';

class profile extends StatefulWidget {
  final String? userId; 
  const profile({super.key, this.userId});

  @override
  State<profile> createState() => _ProfileState();
}

class _ProfileState extends State<profile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  
  String _userName = "";
  String _bio = "";
  String _phoneNumber = "";
  String _altPhoneNumber = "";
  String _email = "";
  String _town = "";
  String _profileImageUrl = "";
  String _userType = "";
  List<String> _userProfessions = [];
  List<Map<String, dynamic>> _userReviews = [];
  List<Map<String, dynamic>> _projects = [];
  
  bool _isOwnProfile = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final targetUid = widget.userId ?? currentUser?.uid;

    if (mounted) {
      setState(() {
        _isOwnProfile = (targetUid == null || (currentUser != null && targetUid == currentUser.uid));
        _isLoading = true;
      });
    }

    if (targetUid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();
      
      final userSnapshot = await dbRef.child('users').child(targetUid).get();
      if (userSnapshot.exists && mounted) {
        final dynamic userDataValue = userSnapshot.value;
        if (userDataValue is Map) {
          final data = Map<String, dynamic>.from(userDataValue);
          setState(() {
            _userName = data['name']?.toString() ?? "";
            _bio = data['description']?.toString() ?? "";
            _phoneNumber = data['phone']?.toString() ?? "";
            _altPhoneNumber = data['optionalPhone']?.toString() ?? "";
            _email = data['email']?.toString() ?? "";
            _town = data['town']?.toString() ?? "";
            _profileImageUrl = data['profileImageUrl']?.toString() ?? "";
            _userType = data['userType']?.toString() ?? "normal";
            
            if (data['professions'] is List) {
              _userProfessions = List<String>.from(data['professions']);
            } else if (data['profession'] != null) {
              _userProfessions = [data['profession'].toString()];
            } else {
              _userProfessions = [];
            }
          });

          _userReviews = _processDataList(data['reviews']);
          _projects = _processDataList(data['projects']);

          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("FETCH ERROR: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _processDataList(dynamic source) {
    List<Map<String, dynamic>> results = [];
    if (source != null) {
      if (source is Map) {
        source.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> itemMap = Map<String, dynamic>.from(value);
            itemMap['id'] = key.toString();
            results.add(itemMap);
          }
        });
      } else if (source is List) {
        for (int i = 0; i < source.length; i++) {
          if (source[i] != null && source[i] is Map) {
            final Map<String, dynamic> itemMap = Map<String, dynamic>.from(source[i]);
            itemMap['id'] = i.toString();
            results.add(itemMap);
          }
        }
      }
    }
    return results;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'פרופיל',
          'user_name': _userName.isNotEmpty ? _userName : 'שם משתמש',
          'edit_profile': 'ערוך פרופיל',
          'share_profile': 'שתף פרופיל',
          'bio': _bio.isNotEmpty ? _bio : 'כאן יופיע התיאור האישי שלך...',
          'projects': 'פרויקטים',
          'reviews': 'חוות דעת',
          'about': 'אודות',
          'add_project': 'הוסף פרויקט',
          'call': 'התקשר',
          'message': 'הודעה',
          'contact_info': 'מידע ליצירת קשר',
          'no_reviews': 'אין עדיין ביקורות',
          'rating_title': 'דרג את העובד',
          'rating_hint': 'כתוב ביקורת...',
          'submit': 'שלח',
          'cancel': 'ביטול',
          'description': 'תיאור',
          'take_photo': 'צלם תמונה',
          'pick_gallery': 'בחר מהגלריה',
          'add': 'הוסף',
          'guest_msg': 'עליך להירשם כדי לבצע פעולה זו',
          'login': 'התחברות',
          'schedule': 'לו"ז',
          'price_guide': 'מחירון מומלץ',
          'report': 'דווח',
          'add_review': 'הוסף ביקורת',
          'report_success': 'הדיווח נשלח בהצלחה',
          'please_login': 'אנא התחבר כדי לצפות בפרופיל שלך',
          'upgrade_pro': 'שדרוג לבעל מקצוע',
          'error': 'שגיאה בהעלאה',
          'comments': 'תגובות',
          'add_comment': 'הוסף תגובה...',
          'write_on_image': 'כתוב על התמונה (אופציונלי)',
          'delete_project': 'מחיקת פרויקט',
          'confirm_delete': 'האם אתה בטוח שברצונך למחוק פרויקט זה?',
          'delete': 'מחק',
        };
      default:
        return {
          'title': 'Profile',
          'user_name': _userName.isNotEmpty ? _userName : 'User Name',
          'edit_profile': 'Edit profile',
          'share_profile': 'Share profile',
          'bio': _bio.isNotEmpty ? _bio : 'Professional service provider.',
          'projects': 'Projects',
          'reviews': 'Reviews',
          'about': 'About',
          'add_project': 'Add Project',
          'call': 'Call',
          'message': 'Message',
          'contact_info': 'Contact Info',
          'no_reviews': 'No reviews yet',
          'rating_title': 'Rate Worker',
          'rating_hint': 'Write a review...',
          'submit': 'Submit',
          'cancel': 'Cancel',
          'description': 'Description',
          'take_photo': 'Take Photo',
          'pick_gallery': 'Pick from Gallery',
          'add': 'Add',
          'delete_project': 'Delete Project',
          'delete_confirm': 'Are you sure you want to delete this project?',
          'delete': 'Delete',
          'upgrade_pro': 'Upgrade to Pro',
          'guest_msg': 'You must sign up to perform this action',
          'login': 'Sign In',
          'schedule': 'Schedule',
          'price_guide': 'Price Guide',
          'report': 'Report',
          'add_review': 'Add Review',
          'report_success': 'Report sent successfully',
          'please_login': 'Please log in to view your profile',
          'error': 'Upload Error',
          'comments': 'Comments',
          'add_comment': 'Add a comment...',
          'write_on_image': 'Write on image (Optional)',
          'delete_project_title': 'Delete Project',
          'confirm_delete': 'Are you sure you want to delete this project?',
        };
    }
  }

  bool _isGuest() => FirebaseAuth.instance.currentUser == null || FirebaseAuth.instance.currentUser!.isAnonymous;

  void _showGuestDialog(BuildContext context, Map<String, String> strings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings['guest_msg']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage()));
            },
            child: Text(strings['login']!),
          ),
        ],
      ),
    );
  }

  void _shareProfile(Map<String, String> strings) {
    Share.share("${strings['user_name']}: $_userName\n${strings['bio']}: $_bio");
  }

  Future<void> _addProject() async {
    final strings = _getLocalizedStrings(context);
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }
    
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    final descriptionController = TextEditingController();
    final bool? shouldPublish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings['add_project']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(pickedFile.path), height: 150, fit: BoxFit.cover),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: strings['write_on_image'],
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings['cancel']!)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(strings['add']!)),
        ],
      ),
    );

    if (shouldPublish != true) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final storageRef = FirebaseStorage.instance.ref().child('projects/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();

      final dbRef = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
      ).ref();

      await dbRef.child('users').child(user.uid).child('projects').push().set({
        'imageUrl': downloadUrl,
        'description': descriptionController.text.trim(),
        'timestamp': ServerValue.timestamp,
      });

      await _fetchUserData();
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${strings['error']}: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reportUser(Map<String, String> strings) async {
    if (_isGuest()) { _showGuestDialog(context, strings); return; }
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings['report']!),
        content: TextField(controller: reasonController, decoration: InputDecoration(hintText: strings['rating_hint']), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
          ElevatedButton(
            onPressed: () async {
              final targetUid = widget.userId;
              if (targetUid == null) return;
              await FirebaseDatabase.instanceFor(app: FirebaseAuth.instance.app, databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com').ref()
                  .child('reports').push().set({'reporterId': FirebaseAuth.instance.currentUser!.uid, 'reportedId': targetUid, 'reason': reasonController.text, 'timestamp': ServerValue.timestamp});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['report_success']!)));
            },
            child: Text(strings['submit']!),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(Map<String, String> strings) async {
    if (_isGuest()) { _showGuestDialog(context, strings); return; }
    double selectedStars = 5;
    final commentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings['rating_title']!),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < selectedStars ? Icons.star : Icons.star_border, color: Colors.amber), onPressed: () => setDialogState(() => selectedStars = i + 1.0)))),
            TextField(controller: commentController, decoration: InputDecoration(hintText: strings['rating_hint']), maxLines: 3),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel']!)),
            ElevatedButton(
              onPressed: () async {
                final targetUid = widget.userId;
                if (targetUid == null) return;
                
                String authorName = FirebaseAuth.instance.currentUser!.displayName ?? "User";
                if (authorName == "User") {
                   final nameSnap = await FirebaseDatabase.instanceFor(app: FirebaseAuth.instance.app, databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com').ref()
                      .child('users').child(FirebaseAuth.instance.currentUser!.uid).child('name').get();
                   if (nameSnap.exists) authorName = nameSnap.value.toString();
                }

                await FirebaseDatabase.instanceFor(app: FirebaseAuth.instance.app, databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com').ref()
                    .child('users').child(targetUid).child('reviews').push().set({'userId': FirebaseAuth.instance.currentUser!.uid, 'userName': authorName, 'stars': selectedStars, 'comment': commentController.text, 'timestamp': ServerValue.timestamp});

                Navigator.pop(context);
                _fetchUserData();
              },
              child: Text(strings['submit']!),
            ),
          ],
        ),
      ),
    );
  }

  void _showProjectDetail(Map<String, dynamic> project) {
    final strings = _getLocalizedStrings(context);
    final targetUid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailPage(
          project: project,
          userId: targetUid,
          localizedStrings: strings,
          onDelete: _isOwnProfile ? () async {
            await FirebaseDatabase.instanceFor(
              app: FirebaseAuth.instance.app,
              databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
            ).ref().child('users').child(targetUid).child('projects').child(project['id']).remove();
            _fetchUserData();
          } : null,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProject(Map<String, dynamic> project) async {
    if (!_isOwnProfile) return;
    final strings = _getLocalizedStrings(context);
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings['delete_project']!),
        content: Text(strings['confirm_delete']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings['cancel']!)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: Text(strings['delete']!),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final targetUid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseDatabase.instanceFor(
          app: FirebaseAuth.instance.app,
          databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
        ).ref().child('users').child(targetUid).child('projects').child(project['id']).remove();
        
        await _fetchUserData();
      } catch (e) {
        debugPrint("DELETE ERROR: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_isOwnProfile && _isGuest() && widget.userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings['title']!), backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
          Text(strings['please_login']!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage())), child: Text(strings['login']!)),
        ])),
      );
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        key: _scaffoldKey,
        body: DefaultTabController(
          length: 4,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 400, pinned: true, stretch: true, backgroundColor: const Color(0xFF1976D2),
                actions: [
                  IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _shareProfile(strings)),
                  if (!_isOwnProfile) IconButton(icon: const Icon(Icons.report_problem_outlined, color: Colors.white70), onPressed: () => _reportUser(strings)),
                  if (_isOwnProfile && !_isGuest())
                    IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(userData: {'name': _userName, 'bio': _bio, 'phone': _phoneNumber, 'town': _town}))))
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    _profileImageUrl.isNotEmpty ? Image.network(_profileImageUrl, fit: BoxFit.cover) : Container(color: const Color(0xFF1E3A8A), child: const Icon(Icons.person, size: 100, color: Colors.white24)),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                    Positioned(bottom: 60, left: 20, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)), if (_userType == 'worker') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.verified, color: Colors.blue, size: 20))]),
                      if (_userProfessions.isNotEmpty) Text(_userProfessions.join(', '), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                      Row(children: [const Icon(Icons.location_on, color: Colors.white70, size: 16), Text(_town, style: const TextStyle(color: Colors.white70, fontSize: 14))]),
                    ])),
                  ]),
                ),
              ),
              SliverPersistentHeader(pinned: true, delegate: _SliverAppBarDelegate(TabBar(labelColor: const Color(0xFF1976D2), unselectedLabelColor: Colors.grey, indicatorColor: const Color(0xFF1976D2), tabs: [Tab(text: strings['projects']), Tab(text: strings['schedule']), Tab(text: strings['reviews']), Tab(text: strings['about'])]))),
            ],
            body: TabBarView(children: [_buildProjectsGrid(strings), SchedulePage(workerId: widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? "", workerName: _userName), _buildReviewsTab(strings), _buildAboutTab(strings)]),
          ),
        ),
        bottomNavigationBar: _buildBottomAction(strings),
      ),
    );
  }

  Widget _buildProjectsGrid(Map<String, String> strings) {
    bool canAdd = _isOwnProfile && !_isGuest();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _projects.length + (canAdd ? 1 : 0),
      itemBuilder: (context, index) {
        if (canAdd && index == 0) return InkWell(onTap: _addProject, child: Container(decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF1976D2), size: 32)));
        final project = _projects[canAdd ? index - 1 : index];
        return GestureDetector(
          onTap: () => _showProjectDetail(project),
          onLongPress: () => _confirmDeleteProject(project),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(project['imageUrl'], fit: BoxFit.cover)),
        );
      },
    );
  }

  Widget _buildReviewsTab(Map<String, String> strings) {
    if (_userReviews.isEmpty) return Center(child: Text(strings['no_reviews']!));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: _userReviews.length, itemBuilder: (context, index) {
      final r = _userReviews[index];
      return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(title: Text(r['userName'] ?? "User"), subtitle: Text(r['comment'] ?? ""), trailing: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, color: Colors.amber, size: 16), Text("${r['stars']}")])));
    });
  }

  Widget _buildAboutTab(Map<String, String> strings) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(strings['bio']!, style: const TextStyle(fontSize: 16, height: 1.5)),
      const SizedBox(height: 32),
      Text(strings['contact_info']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ListTile(leading: const Icon(Icons.phone), title: Text(_phoneNumber)),
      ListTile(leading: const Icon(Icons.email), title: Text(_email)),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AveragePricesPage())), icon: const Icon(Icons.price_change), label: Text(strings['price_guide']!))),
    ]));
  }

  Widget _buildBottomAction(Map<String, String> strings) {
    if (_isOwnProfile && _userType == 'normal' && !_isGuest()) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompleteWorkerProfilePage())),
          icon: const Icon(Icons.upgrade_rounded, color: Colors.white),
          label: Text(strings['upgrade_pro']!),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], minimumSize: const Size(double.infinity, 50)),
        ),
      );
    }

    if (_isOwnProfile) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: () { if (_isGuest()) _showGuestDialog(context, strings); else launchUrl(Uri.parse("tel:$_phoneNumber")); }, icon: const Icon(Icons.call, color: Colors.white), label: Text(strings['call']!), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(onPressed: () { if (_isGuest()) _showGuestDialog(context, strings); else launchUrl(Uri.parse("sms:$_phoneNumber")); }, icon: const Icon(Icons.message, color: Colors.white), label: Text(strings['message']!), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)))),
        ]),
        if (_userType == 'worker') ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _showReviewDialog(strings), icon: const Icon(Icons.rate_review, color: Colors.white), label: Text(strings['add_review']!), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]))),
        ],
      ]),
    );
  }
}

class ProjectDetailPage extends StatefulWidget {
  final Map<String, dynamic> project;
  final String userId;
  final Map<String, String> localizedStrings;
  final VoidCallback? onDelete;

  const ProjectDetailPage({
    Key? key,
    required this.project,
    required this.userId,
    required this.localizedStrings,
    this.onDelete,
  }) : super(key: key);

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
  ).ref();

  @override
  void initState() {
    super.initState();
    _listenToComments();
  }

  void _listenToComments() {
    _dbRef.child('users').child(widget.userId).child('projects').child(widget.project['id']).child('comments').onValue.listen((event) {
      final dynamic data = event.snapshot.value;
      List<Map<String, dynamic>> loaded = [];
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final comment = Map<String, dynamic>.from(value);
            comment['id'] = key;
            loaded.add(comment);
          }
        });
        loaded.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      }
      if (mounted) setState(() => _comments = loaded);
    });
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    if (_commentController.text.trim().isEmpty) return;

    String authorName = user.displayName ?? "User";
    if (authorName == "User") {
      final nameSnap = await _dbRef.child('users').child(user.uid).child('name').get();
      if (nameSnap.exists) authorName = nameSnap.value.toString();
    }

    await _dbRef.child('users').child(widget.userId).child('projects').child(widget.project['id']).child('comments').push().set({
      'userId': user.uid,
      'userName': authorName,
      'text': _commentController.text.trim(),
      'timestamp': ServerValue.timestamp,
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                widget.onDelete!();
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(widget.project['imageUrl'], fit: BoxFit.contain),
                    if (widget.project['description'] != null && widget.project['description'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.black54,
                        width: double.infinity,
                        child: Text(
                          widget.project['description'],
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 300,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(widget.localizedStrings['comments']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c['userName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(c['text'] ?? ""),
                      );
                    },
                  ),
                ),
                if (FirebaseAuth.instance.currentUser != null && !FirebaseAuth.instance.currentUser!.isAnonymous)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: widget.localizedStrings['add_comment'],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(onPressed: _addComment, icon: const Icon(Icons.send, color: Color(0xFF1976D2))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
