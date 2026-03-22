import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/home.dart';
import 'package:untitled1/pages/search.dart';
import 'package:untitled1/pages/formu.dart';
import 'package:untitled1/pages/ptofile.dart';
import 'package:untitled1/pages/splash_screen.dart';
import 'package:untitled1/pages/inbox_page.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hide the navigation bar and status bar for a full-screen experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  try {
    await Firebase.initializeApp();
    // Enable Firestore persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    // Initialize notifications
    NotificationService.init();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Listen for notification taps
    NotificationService.selectNotificationStream.stream.listen((String? payload) {
      if (payload != null && payload.isNotEmpty) {
        try {
          final data = jsonDecode(payload);
          _handleDeepLink(data);
        } catch (e) {
          debugPrint("Error parsing notification payload: $e");
        }
      }
    });
  }

  void _handleDeepLink(Map<String, dynamic> data) {
    // Determine where to navigate based on payload data
    if (data['type'] == 'chat' && data['senderId'] != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatPage(
            receiverId: data['senderId'],
            receiverName: data['senderName'] ?? "User",
          ),
        ),
      );
    } else if (data['type'] == 'blog' && data['postId'] != null) {
      // Logic for blog post deep link
      // Since BlogPage uses a Stream of posts, we might need to fetch the post first
      // or pass the ID to a detail page.
      _navigateToBlogPost(data['postId']);
    }
  }

  void _navigateToBlogPost(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('blog_posts').doc(postId).get();
      if (doc.exists && mounted) {
        final postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id;
        
        // Use a dummy callback for onLike/onEdit etc for now as they are required by the detail page
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              post: postData,
              onLike: () {},
              onEdit: () {},
              onDelete: () {},
              localizedStrings: _getBlogLocalizedStrings(context),
              onGuestDialog: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error navigating to blog post: $e");
    }
  }

  Map<String, dynamic> _getBlogLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    // Minimal strings needed for detail page
    if (locale == 'he') {
      return {'comments': 'תגובות', 'add_comment': 'הוסף תגובה...', 'delete': 'מחק', 'edit': 'ערוך', 'report': 'דווח'};
    }
    return {'comments': 'Comments', 'add_comment': 'Add a comment...', 'delete': 'Delete', 'edit': 'Edit', 'report': 'Report'};
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: Provider.of<LanguageProvider>(context).locale,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1976D2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(navigateToSignIn: false);
        }

        final user = snapshot.data;
        if (user != null) {
          NotificationService.startListening();
          return const MyHomePage();
        }

        NotificationService.stopListening();
        return const SplashScreen();
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int pagenumber = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SearchPage(),
    const BlogPage(),
    const InboxPage(),
    const Profile(),
  ];

  Map<String, String> _getLocalizedLabels(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {'home': 'בית', 'search': 'חיפוש', 'blog': 'בלוג', 'messages': 'הודעות', 'profile': 'פרופיל'};
      case 'ar':
        return {'home': 'الرئيسية', 'search': 'بحث', 'blog': 'مدونة', 'messages': 'رسائل', 'profile': 'الملف الشخصي'};
      case 'ru':
        return {'home': 'Главная', 'search': 'Поиск', 'blog': 'Блог', 'messages': 'Сообщения', 'profile': 'Профиль'};
      case 'am':
        return {'home': 'ዋና ገጽ', 'search': 'ፍለጋ', 'blog': 'ብሎግ', 'messages': 'መልእክቶች', 'profile': 'ፕሮፋይል'};
      default:
        return {'home': 'Home', 'search': 'Search', 'blog': 'Blog', 'messages': 'Messages', 'profile': 'Profile'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = _getLocalizedLabels(context);
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    final isRtl = locale == 'he' || locale == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(
          index: pagenumber,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1976D2),
          unselectedItemColor: Colors.grey,
          currentIndex: pagenumber,
          onTap: (int index) {
            setState(() {
              pagenumber = index;
            });
          },
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: labels['home']),
            BottomNavigationBarItem(icon: const Icon(Icons.search), label: labels['search']),
            BottomNavigationBarItem(icon: const Icon(Icons.article_outlined), label: labels['blog']),
            BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline), label: labels['messages']),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: labels['profile']),
          ],
        ),
      ),
    );
  }
}
