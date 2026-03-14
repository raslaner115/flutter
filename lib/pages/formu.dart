import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/language_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:untitled1/pages/sighn_in.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _postsSubscription;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  int _postLimit = 10;
  final Set<String> _hiddenPostIds = {};
  String _sortBy = 'newest'; // 'newest' or 'likes'

  @override
  void initState() {
    super.initState();
    _listenToPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && !_isLoading && _posts.length >= _postLimit) {
        _loadMorePosts();
      }
    }
  }

  void _loadMorePosts() {
    setState(() {
      _isMoreLoading = true;
      _postLimit += 10;
    });
    _listenToPosts();
  }

  void _listenToPosts() {
    _postsSubscription?.cancel();
    
    Query query = _firestore.collection('blog_posts');
    
    if (_sortBy == 'newest') {
      query = query.orderBy('timestamp', descending: true);
    } else if (_sortBy == 'likes') {
      query = query.orderBy('likes', descending: true);
    }
    
    _postsSubscription = query.limit(_postLimit).snapshots().listen((snapshot) {
      List<Map<String, dynamic>> loadedPosts = [];
      for (var doc in snapshot.docs) {
        final post = doc.data() as Map<String, dynamic>;
        post['id'] = doc.id;
        loadedPosts.add(post);
      }

      if (mounted) {
        setState(() {
          _posts = loadedPosts;
          _isLoading = false;
          _isMoreLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("FETCH ERROR: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
        });
      }
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isLoading = true;
      _postLimit = 10;
    });
    _listenToPosts();
    // Return a dummy future to satisfy RefreshIndicator
    return Future.delayed(const Duration(milliseconds: 500));
  }

  void _sortPosts() {
    setState(() {
      _isLoading = true;
      _postLimit = 10;
    });
    _listenToPosts();
  }

  Map<String, dynamic> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'קהילה וטיפים',
          'create_post': 'שתף עם הקהילה',
          'edit_post': 'ערוך פוסט',
          'post_title': 'כותרת',
          'post_category': 'סוג הפוסט',
          'post_content': 'מה תרצה לשתף?',
          'publish': 'פרסם',
          'update': 'עדכן',
          'cancel': 'ביטול',
          'categories': ['שאלה', 'טיפ', 'מדריך', 'המלצה', 'אחר'],
          'upload_photo': 'הוסף תמונה',
          'no_posts': 'אין פוסטים עדיין',
          'delete': 'מחק',
          'share': 'שתף',
          'report': 'דווח',
          'hide': 'הסתר',
          'edit': 'ערוך',
          'comments': 'תגובות',
          'add_comment': 'הוסף תגובה...',
          'sort': 'מיין לפי',
          'newest': 'הכי חדש',
          'most_liked': 'הכי הרבה לייקים',
          'guest_msg': 'עליך להירשם כדי לבצע פעולה זו',
          'login': 'התחברות',
          'error': 'שגיאה: חסרה הרשאה או בעיית תקשורת',
          'empty_fields': 'נא למלא כותרת ותוכן',
        };
      default:
        return {
          'title': 'Community & Tips',
          'create_post': 'Share with Community',
          'edit_post': 'Edit Post',
          'post_title': 'Title',
          'post_category': 'Category',
          'post_content': 'What\'s on your mind?',
          'publish': 'Publish',
          'update': 'Update',
          'cancel': 'Cancel',
          'categories': ['Question', 'Tip', 'Guide', 'Recommendation', 'Other'],
          'upload_photo': 'Add Photo',
          'no_posts': 'No posts yet',
          'delete': 'Delete',
          'share': 'Share',
          'report': 'Report',
          'hide': 'Hide',
          'edit': 'Edit',
          'comments': 'Comments',
          'add_comment': 'Add a comment...',
          'sort': 'Sort by',
          'newest': 'Newest',
          'most_liked': 'Most Liked',
          'guest_msg': 'You must sign up to perform this action',
          'login': 'Sign In',
          'error': 'Error: Permission denied or connection issue',
          'empty_fields': 'Please fill both title and content',
        };
    }
  }

  bool _isGuest() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  void _showGuestDialog(BuildContext context, Map<String, dynamic> strings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings['guest_msg']),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(strings['cancel'])),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage()));
            },
            child: Text(strings['login']),
          ),
        ],
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context, {Map<String, dynamic>? existingPost}) {
    final strings = _getLocalizedStrings(context);
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }
    
    final titleController = TextEditingController(text: existingPost?['title']);
    final contentController = TextEditingController(text: existingPost?['content']);
    String selectedCategory = existingPost?['category'] ?? (strings['categories'] as List)[0];
    File? selectedImage;
    String? existingImageUrl = existingPost?['imageUrl'];
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(existingPost == null ? strings['create_post'] : strings['edit_post'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: strings['post_category'],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: (strings['categories'] as List).map((cat) => DropdownMenuItem(value: cat.toString(), child: Text(cat.toString()))).toList(),
                  onChanged: (val) => setSheetState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: strings['post_title'],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: strings['post_content'],
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedImage != null || existingImageUrl != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: selectedImage != null 
                          ? Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover)
                          : Image.network(existingImageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => setSheetState(() {
                            selectedImage = null;
                            existingImageUrl = null;
                          }),
                          child: const CircleAvatar(backgroundColor: Colors.black54, radius: 14, child: Icon(Icons.close, size: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                      if (pickedFile != null) setSheetState(() => selectedImage = File(pickedFile.path));
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(strings['upload_photo']),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings['empty_fields'])));
                      return;
                    }
                    
                    setSheetState(() => isUploading = true);
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) throw Exception("User not signed in");

                      String authorName = user.displayName ?? "User";
                      if (user.displayName == null || user.displayName!.isEmpty) {
                        try {
                          final userDoc = await _firestore.collection('users').doc(user.uid).get();
                          if (userDoc.exists) authorName = userDoc.data()?['name'] ?? "User";
                        } catch (_) {}
                      }

                      String? imageUrl = existingImageUrl;
                      if (selectedImage != null) {
                        final storageRef = FirebaseStorage.instance.ref().child('blog_images/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await storageRef.putFile(selectedImage!);
                        imageUrl = await storageRef.getDownloadURL();
                      }

                      final postData = {
                        'title': titleController.text.trim(),
                        'content': contentController.text.trim(),
                        'category': selectedCategory,
                        'imageUrl': imageUrl,
                        'authorUid': user.uid,
                        'authorName': authorName,
                        'timestamp': existingPost?['timestamp'] ?? FieldValue.serverTimestamp(),
                        'likes': existingPost?['likes'] ?? 0,
                        'likedBy': existingPost?['likedBy'] ?? {},
                      };

                      if (existingPost == null) {
                        await _firestore.collection('blog_posts').add(postData);
                      } else {
                        await _firestore.collection('blog_posts').doc(existingPost['id']).update(postData);
                      }
                      
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint("BLOG PUBLISH ERROR: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("${strings['error']}. Make sure your rules allow writes."),
                          duration: const Duration(seconds: 5),
                        ));
                      }
                    } finally {
                      if (mounted) setSheetState(() => isUploading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isUploading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(existingPost == null ? strings['publish'] : strings['update'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deletePost(String postId) async {
    try {
      await _firestore.collection('blog_posts').doc(postId).delete();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting post")));
    }
  }

  void _toggleLike(Map<String, dynamic> post) async {
    final strings = _getLocalizedStrings(context);
    if (_isGuest()) {
      _showGuestDialog(context, strings);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postId = post['id'];
    Map<String, dynamic> likedBy = Map<String, dynamic>.from(post['likedBy'] ?? {});
    int likes = post['likes'] ?? 0;

    if (likedBy.containsKey(user.uid)) {
      likedBy.remove(user.uid);
      likes = likes > 0 ? likes - 1 : 0;
    } else {
      likedBy[user.uid] = true;
      likes++;
    }

    try {
      await _firestore.collection('blog_posts').doc(postId).update({
        'likes': likes,
        'likedBy': likedBy,
      });
    } catch (e) {
      debugPrint("LIKE ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';
    final visiblePosts = _posts.where((p) => !_hiddenPostIds.contains(p['id'])).toList();

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(strings['title'], style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1976D2)),
              onPressed: _onRefresh,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Color(0xFF1976D2)),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                  _sortPosts();
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'newest', child: Text(strings['newest'])),
                PopupMenuItem(value: 'likes', child: Text(strings['most_liked'])),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreatePostSheet(context),
          backgroundColor: const Color(0xFF1976D2),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : visiblePosts.isEmpty 
              ? Center(child: ListView(children: [SizedBox(height: 200), Center(child: Text(strings['no_posts']))]))
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: visiblePosts.length + (_isMoreLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < visiblePosts.length) {
                      return _BlogCard(
                        post: visiblePosts[index],
                        onLike: () => _toggleLike(visiblePosts[index]),
                        onDelete: () => _deletePost(visiblePosts[index]['id']),
                        onEdit: () => _showCreatePostSheet(context, existingPost: visiblePosts[index]),
                        onHide: () => setState(() => _hiddenPostIds.add(visiblePosts[index]['id'])),
                        localizedStrings: strings,
                        onGuestDialog: () => _showGuestDialog(context, strings),
                      );
                    } else {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                  },
                ),
        ),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onHide;
  final Map<String, dynamic> localizedStrings;
  final VoidCallback onGuestDialog;

  const _BlogCard({
    super.key, 
    required this.post, 
    required this.onLike,
    required this.onDelete,
    required this.onEdit,
    required this.onHide,
    required this.localizedStrings,
    required this.onGuestDialog,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAuthor = user != null && post['authorUid'] == user.uid;
    final isLiked = user != null && (post['likedBy'] ?? {}).containsKey(user.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(post: post, onLike: onLike, onEdit: onEdit, onDelete: onDelete, localizedStrings: localizedStrings, onGuestDialog: onGuestDialog))),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['imageUrl'] != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(post['imageUrl'], height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                        child: Text(post['category'] ?? '', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
                        onSelected: (value) {
                          if (value == 'delete') onDelete();
                          if (value == 'edit') onEdit();
                          if (value == 'share') Share.share('${post['title']}\n${post['content']}');
                          if (value == 'hide') onHide();
                          if (value == 'report') {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported successfully')));
                          }
                        },
                        itemBuilder: (context) => isAuthor ? [
                          PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit), const SizedBox(width: 8), Text(localizedStrings['edit'])])),
                          PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), Text(localizedStrings['delete'], style: const TextStyle(color: Colors.red))])),
                          PopupMenuItem(value: 'share', child: Row(children: [const Icon(Icons.share), const SizedBox(width: 8), Text(localizedStrings['share'])])),
                        ] : [
                          PopupMenuItem(value: 'hide', child: Row(children: [const Icon(Icons.visibility_off), const SizedBox(width: 8), Text(localizedStrings['hide'])])),
                          PopupMenuItem(value: 'share', child: Row(children: [const Icon(Icons.share), const SizedBox(width: 8), Text(localizedStrings['share'])])),
                          PopupMenuItem(value: 'report', child: Row(children: [const Icon(Icons.report, color: Colors.orange), const SizedBox(width: 8), Text(localizedStrings['report'], style: const TextStyle(color: Colors.orange))])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(post['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Text(
                    post['content'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(post['authorName'] ?? 'Anonymous', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 18, color: const Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            Text((post['likes'] ?? 0).toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Map<String, dynamic> localizedStrings;
  final VoidCallback onGuestDialog;

  const PostDetailPage({
    super.key, 
    required this.post, 
    required this.onLike,
    required this.onEdit,
    required this.onDelete,
    required this.localizedStrings,
    required this.onGuestDialog,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _comments = [];
  StreamSubscription? _commentsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToComments();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    super.dispose();
  }

  void _listenToComments() {
    _commentsSubscription = _firestore.collection('blog_posts')
        .doc(widget.post['id'])
        .collection('blog_comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> loadedComments = [];
      for (var doc in snapshot.docs) {
        final comment = doc.data();
        comment['id'] = doc.id;
        loadedComments.add(comment);
      }
      if (mounted) setState(() => _comments = loadedComments);
    });
  }

  void _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      widget.onGuestDialog();
      return;
    }

    if (_commentController.text.trim().isEmpty) return;
    
    final commentData = {
      'text': _commentController.text.trim(),
      'authorName': user.displayName ?? 'Anonymous',
      'authorUid': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    };
    try {
      await _firestore.collection('blog_posts')
          .doc(widget.post['id'])
          .collection('blog_comments')
          .add(commentData);
      _commentController.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission denied: Update your rules.")));
    }
  }

  void _deleteComment(String commentId) async {
    try {
      await _firestore.collection('blog_posts')
          .doc(widget.post['id'])
          .collection('blog_comments')
          .doc(commentId)
          .delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAuthor = user != null && widget.post['authorUid'] == user.uid;
    final isLiked = user != null && (widget.post['likedBy'] ?? {}).containsKey(user.uid);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                widget.onDelete();
                Navigator.pop(context);
              }
              if (value == 'edit') {
                widget.onEdit();
                Navigator.pop(context);
              }
              if (value == 'report') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported successfully')));
              }
            },
            itemBuilder: (context) => isAuthor ? [
              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit), const SizedBox(width: 8), Text(widget.localizedStrings['edit'])])),
              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), Text(widget.localizedStrings['delete'], style: const TextStyle(color: Colors.red))])),
            ] : [
              PopupMenuItem(value: 'report', child: Row(children: [const Icon(Icons.report, color: Colors.orange), const SizedBox(width: 8), Text(widget.localizedStrings['report'], style: const TextStyle(color: Colors.orange))])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.post['imageUrl'] != null)
                    Image.network(widget.post['imageUrl'], width: double.infinity, fit: BoxFit.cover),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                              child: Text(widget.post['category'] ?? '', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: widget.onLike,
                              child: Row(
                                children: [
                                  Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Text(widget.post['likes'].toString()),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(widget.post['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(widget.post['authorName'] ?? 'Anonymous', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                        Text(
                          widget.post['content'] ?? '',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.7),
                        ),
                        const SizedBox(height: 32),
                        Text(widget.localizedStrings['comments'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ..._comments.map((comment) {
                          final isCommentAuthor = user != null && comment['authorUid'] == user.uid;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(comment['authorName'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    if (isCommentAuthor || isAuthor)
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.more_horiz, size: 18),
                                        onSelected: (val) {
                                          if (val == 'delete') _deleteComment(comment['id']);
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(value: 'delete', child: Text(widget.localizedStrings['delete'], style: const TextStyle(color: Colors.red, fontSize: 13))),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(comment['text'] ?? ''),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send, color: Color(0xFF1976D2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
