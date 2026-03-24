import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ensure user exists in Firestore (Only for non-anonymous users)
  Future<void> ensureUserInDatabase(User? user) async {
    if (user == null || user.isAnonymous) return; // Don't save if guest

    // Check all collections to see if user exists
    final collections = ['normal_users', 'workers', 'admins'];
    bool exists = false;
    for (var collection in collections) {
      final doc = await _firestore.collection(collection).doc(user.uid).get();
      if (doc.exists) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      // Default new users to normal_users collection
      await _firestore.collection('normal_users').doc(user.uid).set({
        'uid': user.uid,
        'name': "User",
        'phone': user.phoneNumber ?? "",
        'email': user.email ?? "",
        'isNormal': true,
        'isWorker': false,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'profileImageUrl': user.photoURL ?? "",
      });
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
