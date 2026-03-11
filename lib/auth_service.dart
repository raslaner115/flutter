import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://hire-hub-fe6c4-default-rtdb.firebaseio.com'
  ).ref();

  // Ensure user exists in Realtime Database (Only for non-anonymous users)
  Future<void> ensureUserInDatabase(User? user) async {
    if (user == null || user.isAnonymous) return; // Don't save if guest
    
    final snapshot = await _dbRef.child('users').child(user.uid).get();
    if (!snapshot.exists) {
      await _dbRef.child('users').child(user.uid).set({
        'uid': user.uid,
        'name': "User",
        'phone': user.phoneNumber ?? "",
        'email': user.email ?? "",
        'userType': 'normal',
        'createdAt': ServerValue.timestamp,
        'profileImageUrl': user.photoURL ?? "",
      });
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
