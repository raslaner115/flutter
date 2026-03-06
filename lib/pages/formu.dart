import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/ptofile.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({Key? key}) : super(key: key);

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://profis-60aaa-default-rtdb.europe-west1.firebasedatabase.app'
  ).ref();

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

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
        
        // Sort by timestamp descending
        loadedPosts.sort((a, b) {
          final tA = a['timestamp'] ?? 0;
          final tB = b['timestamp'] ?? 0;
          return (tB as num).compareTo(tA as num);
        });
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

  Map<String, dynamic> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'קהילה וטיפים',
          'featured': 'פוסטים אחרונים',
          'create_post': 'שתף עם הקהילה',
          'post_title': 'כותרת',
          'post_category': 'סוג הפוסט',
          'post_content': 'מה תרצה לשתף?',
          'publish': 'פרסם',
          'cancel': 'ביטול',
          'categories': ['שאלה', 'טיפ', 'מדריך', 'המלצה', 'אחר'],
          'upload_photo': 'הוסף תמונה',
          'no_posts': 'אין פוסטים עדיין',
        };
      case 'ar':
        return {
          'title': 'المنتدى والنصائح',
          'featured': 'آخر المنشورات',
          'create_post': 'شارك مع المجتمع',
          'post_title': 'العنوان',
          'post_category': 'نوع المنشور',
          'post_content': 'ماذا تريد أن تشارك؟',
          'publish': 'نشر',
          'cancel': 'إلغاء',
          'categories': ['سؤال', 'نصيحة', 'دليل', 'توصية', 'آخر'],
          'upload_photo': 'أضف صورة',
          'no_posts': 'لا توجد منشورات بعد',
        };
      default:
        return {
          'title': 'Community & Tips',
          'featured': 'Recent Posts',
          'create_post': 'Share with Community',
          'post_title': 'Title',
          'post_category': 'Category',
          'post_content': 'What\'s on your mind?',
          'publish': 'Publish',
          'cancel': 'Cancel',
          'categories': ['Question', 'Tip', 'Guide', 'Recommendation', 'Other'],
          'upload_photo': 'Add Photo',
          'no_posts': 'No posts yet',
        };
    }
  }

  void _showCreatePostSheet(BuildContext context, Map<String, dynamic> strings) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = (strings['categories'] as List)[0];
    File? selectedImage;
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
                    Text(strings['create_post'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
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
                if (selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedImage = null),
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
                      String? imageUrl;
                      
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
                        'timestamp': ServerValue.timestamp,
                        'likes': 0,
                      };

                      await _dbRef.child('blog_posts').push().set(postData);
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
                    : Text(strings['publish'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(strings['title'], style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreatePostSheet(context, strings),
          backgroundColor: const Color(0xFF1976D2),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty 
            ? Center(child: Text(strings['no_posts']))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (context, index) => _BlogCard(post: _posts[index]),
              ),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _BlogCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailPage(post: post))),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  post['imageUrl'], 
                  height: 180, 
                  width: double.infinity, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
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
                      Text(
                        post['timestamp'] != null 
                          ? _formatTimestamp(post['timestamp'])
                          : '',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                      const Icon(Icons.favorite_border, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      Text((post['likes'] ?? 0).toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      return "${date.day}/${date.month}/${date.year}";
    }
    return '';
  }
}

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostDetailPage({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty)
              Image.network(post['imageUrl'], width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                    child: Text(post['category'] ?? '', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  Text(post['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(post['authorName'] ?? 'Anonymous', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (post['timestamp'] != null)
                        Text(
                          _formatTimestamp(post['timestamp']),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                  Text(
                    post['content'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.7),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      return "${date.day}/${date.month}/${date.year}";
    }
    return '';
  }
}
