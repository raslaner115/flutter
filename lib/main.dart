import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/home.dart';
import 'package:untitled1/search.dart';
import 'package:untitled1/formu.dart';
import 'package:untitled1/ptofile.dart';
import 'package:untitled1/pages/admin_profile.dart';
import 'package:untitled1/widgets/splash_screen.dart';
import 'package:untitled1/pages/inbox_page.dart';
import 'package:untitled1/pages/chat_page.dart';
import 'package:untitled1/services/notification_service.dart';
import 'services/firebase_options.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Only hide the navigation bar and status bar on mobile for a full-screen experience
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  bool firebaseInitialized = false;
  Object? initializationError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable Firestore persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    // Initialize notifications
    await NotificationService.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint("Notification initialization timed out"),
    );
    firebaseInitialized = true;
  } catch (e, stack) {
    initializationError = e;
    debugPrint("FATAL: Firebase initialization failed: $e");
    debugPrint(stack.toString());
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: MyApp(
        isFirebaseInitialized: firebaseInitialized,
        initializationError: initializationError,
      ),
    ),
  );
  
  // Remove the native splash screen
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  final bool isFirebaseInitialized;
  final Object? initializationError;

  const MyApp({
    super.key, 
    required this.isFirebaseInitialized,
    this.initializationError,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.isFirebaseInitialized) {
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
  }

  void _handleDeepLink(Map<String, dynamic> data) {
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
      _navigateToBlogPost(data['postId']);
    }
  }

  void _navigateToBlogPost(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('blog_posts').doc(postId).get();
      if (doc.exists && mounted) {
        // Post details are handled in BlogPage
      }
    } catch (e) {
      debugPrint("Error navigating to blog post: $e");
    }
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
      home: widget.isFirebaseInitialized 
          ? const AuthWrapper() 
          : _ErrorScreen(error: widget.initializationError),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object? error;
  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text(
                "Firebase Initialization Failed",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? "An unknown error occurred during setup.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text("Exit App"),
              ),
            ],
          ),
        ),
      ),
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
          return const SplashScreen(navigateToSignIn: true);
        }

        final user = snapshot.data;
        if (user != null) {
          NotificationService.startListening();
          return const MyHomePage();
        }

        NotificationService.stopListening();
        return const SplashScreen(navigateToSignIn: true);
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
  bool _isAdmin = false;

  final List<Widget> _pages = [
    const HomePage(),
    const SearchPage(),
    const BlogPage(),
    const InboxPage(),
    const Profile(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
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

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _isAdmin = true;
            _pages[4] = const AdminProfile();
          });
        }
      } catch (e) {
        debugPrint("Admin check error: $e");
      }
    }
  }

  void _handleDeepLink(Map<String, dynamic> data) {
    if (data['type'] == 'chat' && data['senderId'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            receiverId: data['senderId'],
            receiverName: data['senderName'] ?? "User",
          ),
        ),
      );
    }
  }

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
    final isWide = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: isWide ? AppBar(
          title: const Text("HireHub"),
          centerTitle: false,
          actions: [
            _navButton(0, Icons.home, labels['home']!),
            _navButton(1, Icons.search, labels['search']!),
            _navButton(2, Icons.article, labels['blog']!),
            _navButton(3, Icons.chat, labels['messages']!),
            _navButton(4, Icons.person, labels['profile']!),
            const SizedBox(width: 20),
          ],
        ) : null,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 1000 : double.infinity),
            child: IndexedStack(
              index: pagenumber,
              children: _pages,
            ),
          ),
        ),
        bottomNavigationBar: isWide ? null : BottomNavigationBar(
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

  Widget _navButton(int index, IconData icon, String label) {
    final isSelected = pagenumber == index;
    return TextButton.icon(
      onPressed: () => setState(() => pagenumber = index),
      icon: Icon(icon, color: isSelected ? const Color(0xFF1976D2) : Colors.grey),
      label: Text(
        label,
        style: TextStyle(color: isSelected ? const Color(0xFF1976D2) : Colors.grey),
      ),
    );
  }
}
