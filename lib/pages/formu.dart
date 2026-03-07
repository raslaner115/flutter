import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/language_provider.dart';
import 'package:share_plus/share_plus.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({Key? key}) : super(key: key);

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
  ).ref();

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  final Set<String> _hiddenPostIds = {};
  String _sortBy = 'newest'; // 'newest' or 'likes'

  @override
  void initState() {
    super.initState();
    _listenToPosts();
  }

  void _listenToPosts() {
    _dbRef.child('blog_posts').onValue.listen((event) {
      final dynamic data = event.snapshot.value;
      List<Map<String, dynamic>> loadedPosts = [];
      
      if (data != null) {
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              final post = Map<String, dynamic>.from(value);
              post['id'] = key.toString();
              loadedPosts.add(post);
            }
          });
        } else if (data is List) {
          for (int i = 0; i < data.length; i++) {
            if (data[i] != null && data[i] is Map) {
              final post = Map<String, dynamic>.from(data[i]);
              post['id'] = i.toString();
              loadedPosts.add(post);
            }
          }
        }
        _sortPosts(loadedPosts);
      }

      if (mounted) {
        setState(() {
          _posts = loadedPosts;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("FETCH ERROR: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _sortPosts(List<Map<String, dynamic>> posts) {
    if (_sortBy == 'newest') {
      posts.sort((a, b) {
        final tA = a['timestamp'] ?? 0;
        final tB = b['timestamp'] ?? 0;
        return (tB as num).compareTo(tA as num);
      });
    } else if (_sortBy == 'likes') {
      posts.sort((a, b) {
        final lA = a['likes'] ?? 0;
        final lB = b['likes'] ?? 0;
        return (lB as num).compareTo(lA as num);
      });
    }
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
        };
      case 'ar':
        return {
          'title': 'المنتدى والنصائح',
          'create_post': 'شارك مع المجتمع',
          'edit_post': 'تعديل المنشور',
          'post_title': 'العنوان',
          'post_category': 'نوع المنشور',
          'post_content': 'ماذا تريد أن تشارك؟',
          'publish': 'نشر',
          'update': 'تحديث',
          'cancel': 'إلغاء',
          'categories': ['سؤال', 'نصيحة', 'دليل', 'توصية', 'آخر'],
          'upload_photo': 'أضف صورة',
          'no_posts': 'لا توجد منشورات بعد',
          'delete': 'حذف',
          'share': 'مشاركة',
          'report': 'إبلاغ',
          'hide': 'إخفاء',
          'edit': 'تعديل',
          'comments': 'تعليقات',
          'add_comment': 'أضف تعليقاً...',
          'sort': 'ترتيب حسب',
          'newest': 'الأحدث',
          'most_liked': 'الأكثر إعجاباً',
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
        };
    }
  }

  void _showCreatePostSheet(BuildContext context, {Map<String, dynamic>? existingPost}) {
    final strings = _getLocalizedStrings(context);
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
                    if (titleController.text.isEmpty || contentController.text.isEmpty) return;
                    
                    setSheetState(() => isUploading = true);
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      String? imageUrl = existingImageUrl;
                      
                      if (selectedImage != null) {
                        final storageRef = FirebaseStorage.instance.ref().child('blog_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await storageRef.putFile(selectedImage!);
                        imageUrl = await storageRef.getDownloadURL();
                      }

                      final postData = {
                        'title': titleController.text.trim(),
                        'content': contentController.text.trim(),
                        'category': selectedCategory,
                        'imageUrl': imageUrl,
                        'authorUid': user?.uid,
                        'authorName': user?.displayName ?? 'Anonymous',
                        'timestamp': existingPost?['timestamp'] ?? ServerValue.timestamp,
                        'likes': existingPost?['likes'] ?? 0,
                        'likedBy': existingPost?['likedBy'] ?? {},
                      };

                      if (existingPost == null) {
                        await _dbRef.child('blog_posts').push().set(postData);
                      } else {
                        await _dbRef.child('blog_posts').child(existingPost['id']).update(postData);
                      }
                      
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      debugPrint("POST ERROR: $e");
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
    await _dbRef.child('blog_posts').child(postId).remove();
  }

  void _toggleLike(Map<String, dynamic> post) async {
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

    await _dbRef.child('blog_posts').child(postId).update({
      'likes': likes,
      'likedBy': likedBy,
    });
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Color(0xFF1976D2)),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                  _sortPosts(_posts);
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
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : visiblePosts.isEmpty 
            ? Center(child: Text(strings['no_posts']))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: visiblePosts.length,
                itemBuilder: (context, index) => _BlogCard(
                  post: visiblePosts[index],
                  onLike: () => _toggleLike(visiblePosts[index]),
                  onDelete: () => _deletePost(visiblePosts[index]['id']),
                  onEdit: () => _showCreatePostSheet(context, existingPost: visiblePosts[index]),
                  onHide: () => setState(() => _hiddenPostIds.add(visiblePosts[index]['id'])),
                  localizedStrings: strings,
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

  const _BlogCard({
    Key? key, 
    required this.post, 
    required this.onLike,
    required this.onDelete,
    required this.onEdit,
    required this.onHide,
    required this.localizedStrings,
  }) : super(key: key);

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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(post: post, onLike: onLike, onEdit: onEdit, onDelete: onDelete, localizedStrings: localizedStrings))),
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

  const PostDetailPage({
    Key? key, 
    required this.post, 
    required this.onLike,
    required this.onEdit,
    required this.onDelete,
    required this.localizedStrings,
  }) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
  ).ref();

  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _listenToComments();
  }

  void _listenToComments() {
    _dbRef.child('blog_posts').child(widget.post['id']).child('blog_comments').onValue.listen((event) {
      final dynamic data = event.snapshot.value;
      List<Map<String, dynamic>> loadedComments = [];
      if (data != null) {
        if (data is Map) {
          data.forEach((key, value) {
            final comment = Map<String, dynamic>.from(value as Map);
            comment['id'] = key;
            loadedComments.add(comment);
          });
        } else if (data is List) {
          for (int i = 0; i < data.length; i++) {
            if (data[i] != null) {
              final comment = Map<String, dynamic>.from(data[i] as Map);
              comment['id'] = i.toString();
              loadedComments.add(comment);
            }
          }
        }
        loadedComments.sort((a, b) {
          final tA = a['timestamp'] ?? 0;
          final tB = b['timestamp'] ?? 0;
          return (tB as num).compareTo(tA as num);
        });
      }
      if (mounted) setState(() => _comments = loadedComments);
    });
  }

  void _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    final commentData = {
      'text': _commentController.text.trim(),
      'authorName': user?.displayName ?? 'Anonymous',
      'authorUid': user?.uid,
      'timestamp': ServerValue.timestamp,
    };
    await _dbRef.child('blog_posts').child(widget.post['id']).child('blog_comments').push().set(commentData);
    _commentController.clear();
  }

  void _deleteComment(String commentId) async {
    await _dbRef.child('blog_posts').child(widget.post['id']).child('blog_comments').child(commentId).remove();
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
                        }).toList(),
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
