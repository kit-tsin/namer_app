import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  print('Initializing Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;

  if (user == null) {
    print('ERROR: No user is currently logged in.');
    print('Please log in to your app first, then run this script.');
    return;
  }

  print('Current user: ${user.email}');
  print('User UID: ${user.uid}');
  print('');
  print('Deleting account...');

  try {
    // Delete Firestore data
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      print('✓ Deleted Firestore user data');
    } catch (e) {
      print('⚠ Could not delete Firestore data (may not exist): $e');
    }

    // Delete Firebase Auth account
    await user.delete();
    print('✓ Deleted Firebase Auth account');
    print('');
    print('SUCCESS: Account deleted successfully!');
    print('You can now test Facebook login.');
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      print('');
      print('ERROR: Requires recent login.');
      print('Please log out and log back in to your app, then run this script again.');
    } else {
      print('');
      print('ERROR: ${e.code} - ${e.message}');
    }
  } catch (e) {
    print('');
    print('ERROR: $e');
  }
}
