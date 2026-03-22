import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/language_provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:untitled1/pages/request_details.dart';
import 'package:untitled1/pages/ptofile.dart';
import 'package:untitled1/pages/invoice_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  bool _isRecording = false;
  late Stream<QuerySnapshot> _messageStream;
  
  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  bool _isWorker = false;
  String? _currentUserName;
  String? _currentUserPhone;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _checkUserType();
    _messageStream = _firestore
        .collection('chat_rooms')
        .doc(_getChatRoomId(_auth.currentUser!.uid, widget.receiverId))
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _checkUserType() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _isWorker = data?['userType'] == 'worker';
            _currentUserName = data?['name'] ?? user.displayName;
            _currentUserPhone = data?['phone'];
            _currentUserEmail = data?['email'] ?? user.email;
          });
        }
      } catch (e) {
        debugPrint("Error checking user type: $e");
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }

  void _sendMessage({String? text, String type = 'text', String? url, String? fileName}) async {
    if (type == 'text' && (text == null || text.trim().isEmpty)) return;

    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = _getChatRoomId(currentUserId, widget.receiverId);
    
    final messageData = {
      'senderId': currentUserId,
      'receiverId': widget.receiverId,
      'message': text ?? '',
      'type': type,
      'url': url,
      'fileName': fileName,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      String lastMsgDisplay = "";
      switch (type) {
        case 'image': lastMsgDisplay = "📷 Photo"; break;
        case 'video': lastMsgDisplay = "🎥 Video"; break;
        case 'file': lastMsgDisplay = "📄 File: $fileName"; break;
        case 'audio': lastMsgDisplay = "🎤 Voice message"; break;
        default: lastMsgDisplay = text ?? "";
      }

      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'lastMessage': lastMsgDisplay,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'users': [currentUserId, widget.receiverId],
        'userNames': {
          currentUserId: _auth.currentUser!.displayName ?? "User",
          widget.receiverId: widget.receiverName,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  Future<Map<String, String>?> _uploadFile(File file, String folder) async {
    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}";
      final ref = _storage.ref().child('chat_media/$folder/$fileName');
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      return {'url': url, 'fileName': fileName};
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  Future<void> _showPreviewDialog({
    required File file,
    required String type,
    String? fileName,
  }) async {
    final isRtl = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he' || 
                 Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'ar';

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isRtl ? "שלח מדיה?" : "Send Media?", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(file, height: 200, width: double.infinity, fit: BoxFit.cover),
              )
            else if (type == 'video')
              const Icon(Icons.videocam, size: 80, color: Color(0xFF1976D2))
            else if (type == 'audio')
              const Icon(Icons.mic, size: 80, color: Colors.red)
            else
              const Icon(Icons.insert_drive_file, size: 80, color: Color(0xFF1976D2)),
            const SizedBox(height: 16),
            if (fileName != null)
              Text(fileName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isRtl ? "ביטול" : "Cancel", style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isRtl ? "שלח" : "Send"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRtl ? "מעלה..." : "Uploading..."),
          duration: const Duration(seconds: 1),
        ),
      );

      String folder = 'files';
      if (type == 'image') folder = 'images';
      else if (type == 'video') folder = 'videos';
      else if (type == 'audio') folder = 'audio';

      final result = await _uploadFile(file, folder);
      if (result != null) {
        final url = result['url']!;
        _sendMessage(type: type, url: url, fileName: result['fileName']);
        
        // Save own sent media to gallery automatically
        if (type == 'image' || type == 'video') {
           try {
             await Gal.putImageBytes(await file.readAsBytes(), album: 'HireHub');
           } catch (e) {
             debugPrint("Gal error: $e");
           }
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      _showPreviewDialog(file: File(pickedFile.path), type: 'image');
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      _showPreviewDialog(file: File(pickedFile.path), type: 'video', fileName: "Video File");
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      _showPreviewDialog(
        file: File(result.files.single.path!),
        type: 'file',
        fileName: result.files.single.name,
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final isRtl = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he' || 
                     Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'ar';
        _showPreviewDialog(file: File(path), type: 'audio', fileName: isRtl ? "הודעה קולית" : "Voice message");
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
        _isSelectionMode = true;
      }
    });
  }

  void _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    
    final chatRoomId = _getChatRoomId(_auth.currentUser!.uid, widget.receiverId);
    final batch = _firestore.batch();
    
    for (var messageId in _selectedMessageIds) {
      batch.delete(_firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId));
    }
    
    await batch.commit();
    setState(() {
      _selectedMessageIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' || 
                 Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), 
        appBar: _isSelectionMode ? _buildSelectionAppBar(isRtl) : _buildNormalAppBar(isRtl),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/icon/app_icon.png'),
              opacity: 0.03,
              repeat: ImageRepeat.repeat,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(isRtl ? 'שגיאה בטעינת הודעות' : 'Error loading messages'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final bool isMe = data['senderId'] == _auth.currentUser!.uid;
                        final bool isSystem = data['isSystem'] ?? false;
                        final timestamp = data['timestamp'] as Timestamp?;
                        final String messageId = doc.id;
                        final bool isSelected = _selectedMessageIds.contains(messageId);

                        if (isSystem) {
                          return _buildSystemMessage(data, timestamp);
                        }

                        return _buildMessageBubble(data, isMe, timestamp, messageId, isSelected, isRtl);
                      },
                    );
                  },
                ),
              ),
              if (!_isSelectionMode) _buildMessageInput(isRtl),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(bool isRtl) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1976D2),
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: () async {
          final userDoc = await _firestore.collection('users').doc(widget.receiverId).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            if (data != null && data['userType'] == 'worker') {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Profile(userId: widget.receiverId)),
              );
            }
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    isRtl ? "מחובר" : "Online",
                    style: TextStyle(fontSize: 12, color: Colors.green[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isWorker)
          IconButton(
            tooltip: isRtl ? "הפק חשבונית" : "Create Invoice",
            icon: const Icon(Icons.receipt_long_rounded, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceBuilderPage(
                    workerName: _currentUserName ?? "Worker",
                    workerPhone: _currentUserPhone,
                    workerEmail: _currentUserEmail,
                    receiverId: widget.receiverId,
                    receiverName: widget.receiverName,
                  ),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.call_rounded, size: 22),
          onPressed: () async {
            final userDoc = await _firestore.collection('users').doc(widget.receiverId).get();
            if (userDoc.exists) {
              final phone = userDoc.data()?['phone']?.toString();
              if (phone != null && phone.isNotEmpty) {
                final Uri url = Uri.parse('tel:$phone');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isRtl ? "לא נמצא מספר טלפון" : "No phone number found"), behavior: SnackBarBehavior.floating),
                );
              }
            }
          },
        ),
        IconButton(icon: const Icon(Icons.more_vert_rounded, size: 22), onPressed: () {}),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(bool isRtl) {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2),
      foregroundColor: Colors.white,
      elevation: 4,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => setState(() {
          _selectedMessageIds.clear();
          _isSelectionMode = false;
        }),
      ),
      title: Text(_selectedMessageIds.length.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_rounded),
          onPressed: _deleteSelectedMessages,
        ),
      ],
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> data, Timestamp? timestamp) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text(
          data['message'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, Timestamp? timestamp, String messageId, bool isSelected, bool isRtl) {
    final timeStr = timestamp != null ? intl.DateFormat.Hm().format(timestamp.toDate()) : "";
    final type = data['type'] ?? 'text';
    final message = data['message'] ?? '';
    final url = data['url'];

    return GestureDetector(
      onLongPress: () => _toggleSelection(messageId),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(messageId);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isSelected ? const Color(0xFF1976D2).withOpacity(0.15) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) _buildTail(false, isRtl),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  padding: type == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF1976D2) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: isMe ? const Radius.circular(20) : Radius.zero,
                      topRight: isMe ? Radius.zero : const Radius.circular(20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMessageContent(type, message, url, data, isMe),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withOpacity(0.8) : const Color(0xFF94A3B8)),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.done_all_rounded, size: 14, color: isMe ? Colors.white.withOpacity(0.9) : const Color(0xFF1976D2)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isMe) _buildTail(true, isRtl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTail(bool isMe, bool isRtl) {
    bool onRight = (isMe && !isRtl) || (!isMe && isRtl);
    return CustomPaint(
      size: const Size(10, 10),
      painter: TailPainter(isMe: isMe, onRight: onRight),
    );
  }

  Widget _buildMessageContent(String type, String message, String? url, Map<String, dynamic> data, bool isMe) {
    switch (type) {
      case 'image':
        return _MediaWrapper(
          url: url!,
          type: 'image',
          child: (localFile) => _ImagePreview(file: localFile, url: url),
        );
      case 'video':
        return _MediaWrapper(
          url: url!,
          type: 'video',
          child: (localFile) => _VideoPreview(file: localFile, url: url),
        );
      case 'audio':
        return _MediaWrapper(
          url: url!,
          type: 'audio',
          child: (localFile) => _AudioPreview(file: localFile, url: url, isMe: isMe, audioPlayer: _audioPlayer),
        );
      case 'file':
        return _MediaWrapper(
          url: url!,
          type: 'file',
          fileName: data['fileName'],
          child: (localFile) => _FilePreview(file: localFile, url: url, fileName: data['fileName'] ?? 'File', isMe: isMe),
        );
      default:
        return Text(
          message,
          style: TextStyle(fontSize: 15, color: isMe ? Colors.white : const Color(0xFF1E293B), height: 1.4),
        );
    }
  }

  Widget _buildMessageInput(bool isRtl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Color(0xFF64748B)),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: isRtl ? "הודעה..." : "Message...",
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B)),
                    onPressed: _showAttachmentOptions,
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF64748B)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final bool isTextEmpty = value.text.trim().isEmpty;
              return GestureDetector(
                onTap: () {
                  if (_isRecording) {
                    _stopRecording();
                  } else if (!isTextEmpty) {
                    _sendMessage(text: _messageController.text);
                    _messageController.clear();
                  } else {
                    _startRecording();
                  }
                },
                onLongPress: isTextEmpty ? _startRecording : null,
                onLongPressUp: isTextEmpty ? _stopRecording : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : (isTextEmpty ? Icons.mic_rounded : Icons.send_rounded),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    final isRtl = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'he' || 
                 Provider.of<LanguageProvider>(context, listen: false).locale.languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              children: [
                _buildAttachmentItem(Icons.description_rounded, "Document", const Color(0xFF7C3AED), _pickFile),
                _buildAttachmentItem(Icons.camera_alt_rounded, "Camera", const Color(0xFFEC4899), () => _pickImage(ImageSource.camera)),
                _buildAttachmentItem(Icons.image_rounded, "Gallery", const Color(0xFF8B5CF6), () => _pickImage(ImageSource.gallery)),
                _buildAttachmentItem(Icons.headphones_rounded, "Audio", const Color(0xFFF59E0B), () {}),
                _buildAttachmentItem(Icons.location_on_rounded, "Location", const Color(0xFF10B981), () {}),
                _buildAttachmentItem(Icons.person_rounded, "Contact", const Color(0xFF3B82F6), () {}),
                if (_isWorker)
                  _buildAttachmentItem(
                    Icons.receipt_long_rounded, 
                    isRtl ? "חשבונית" : "Invoice", 
                    const Color(0xFF1976D2), 
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceBuilderPage(
                            workerName: _currentUserName ?? "Worker",
                            workerPhone: _currentUserPhone,
                            workerEmail: _currentUserEmail,
                            receiverId: widget.receiverId,
                            receiverName: widget.receiverName,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ],
    );
  }
}

class TailPainter extends CustomPainter {
  final bool isMe;
  final bool onRight;

  TailPainter({required this.isMe, required this.onRight});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = isMe ? const Color(0xFF1976D2) : Colors.white;
    var path = Path();
    if (onRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _MediaWrapper extends StatefulWidget {
  final String url;
  final String type;
  final String? fileName;
  final Widget Function(File localFile) child;

  const _MediaWrapper({
    required this.url,
    required this.type,
    required this.child,
    this.fileName,
  });

  @override
  State<_MediaWrapper> createState() => _MediaWrapperState();
}

class _MediaWrapperState extends State<_MediaWrapper> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _checkLocal();
  }

  Future<void> _checkLocal() async {
    final dir = await getApplicationDocumentsDirectory();
    final name = widget.fileName ?? widget.url.split('/').last.split('?').first;
    final file = File('${dir.path}/chat_media/${widget.type}/$name');
    if (await file.exists()) {
      if (mounted) setState(() {
        _isDownloaded = true;
        _localFile = file;
      });
    }
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = widget.fileName ?? widget.url.split('/').last.split('?').first;
      final file = File('${dir.path}/chat_media/${widget.type}/$name');
      
      final response = await http.get(Uri.parse(widget.url));
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      
      if (widget.type == 'image') await Gal.putImage(file.path, album: 'HireHub');
      if (widget.type == 'video') await Gal.putVideo(file.path, album: 'HireHub');

      if (mounted) setState(() {
        _isDownloaded = true;
        _isDownloading = false;
        _localFile = file;
      });
    } catch (e) {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloaded && _localFile != null) {
      return widget.child(_localFile!);
    }

    return GestureDetector(
      onTap: _download,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.type == 'image' || widget.type == 'video' ? 200 : 150,
            height: widget.type == 'image' || widget.type == 'video' ? 150 : 60,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: widget.type == 'image' 
              ? Opacity(opacity: 0.3, child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.cover))
              : null,
          ),
          if (_isDownloading)
            const CircularProgressIndicator(color: Color(0xFF1976D2))
          else
            const CircleAvatar(
              backgroundColor: Colors.black45,
              radius: 20,
              child: Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 24),
            ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File file;
  final String url;
  const _ImagePreview({required this.file, required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => _showFullImage(context, url),
        child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: 200),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: CachedNetworkImage(imageUrl: url)),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final File file;
  final String url;
  const _VideoPreview({required this.file, required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_isInitialized)
            IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.9),
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
            ),
        ],
      ),
    );
  }
}

class _AudioPreview extends StatefulWidget {
  final File file;
  final String url;
  final bool isMe;
  final ap.AudioPlayer audioPlayer;
  const _AudioPreview({required this.file, required this.url, required this.isMe, required this.audioPlayer});

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final isHe = Provider.of<LanguageProvider>(context).locale.languageCode == 'he';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.isMe ? Colors.white : const Color(0xFF1976D2)),
          onPressed: () async {
            if (_isPlaying) {
              await widget.audioPlayer.pause();
              setState(() => _isPlaying = false);
            } else {
              await widget.audioPlayer.play(ap.DeviceFileSource(widget.file.path));
              setState(() => _isPlaying = true);
              widget.audioPlayer.onPlayerComplete.listen((event) {
                if (mounted) setState(() => _isPlaying = false);
              });
            }
          },
        ),
        Text(
          isHe ? "הודעה קולית" : "Voice Message",
          style: TextStyle(color: widget.isMe ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _FilePreview extends StatelessWidget {
  final File file;
  final String url;
  final String fileName;
  final bool isMe;
  const _FilePreview({required this.file, required this.url, required this.fileName, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => OpenFilex.open(file.path),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : const Color(0xFF1976D2), size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
