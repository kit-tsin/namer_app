import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show Platform;

import 'firebase_options.dart';

/// Enumeration for different sorting options available in the favorites page.
/// Used to control how favorite word pairs are displayed and sorted.
enum SortOption {
  latestToOldest,      // Newest items first
  oldestToLatest,      // Oldest items first (default)
  alphabetical,        // A-Z alphabetical order
  reverseAlphabetical, // Z-A reverse alphabetical order
}

/// Main entry point of the application.
/// Initializes Firebase and starts the Flutter app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

/// Root widget of the application.
/// Sets up the MaterialApp with dynamic color support, theme configuration,
/// and provides the MyAppState through Provider for state management.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // State is already saved on every getNext() call and other operations
    // No need to save here as we don't have access to the Provider context
    // from the lifecycle observer
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          // Use dynamic color on Android 12+ if available, otherwise fall back to seed color
          ColorScheme lightColorScheme;
          ColorScheme darkColorScheme;
          
          if (lightDynamic != null && darkDynamic != null) {
            // Android 12+ with dynamic color support
            lightColorScheme = lightDynamic;
            darkColorScheme = darkDynamic;
          } else {
            // Fallback for older Android versions or when dynamic color is not available
            lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.deepOrange);
            darkColorScheme = ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.dark,
            );
          }
          
          return MaterialApp(
            title: 'Namer App',
            theme: ThemeData(
              colorScheme: lightColorScheme,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: darkColorScheme,
              useMaterial3: true,
            ),
            themeMode: ThemeMode.system, // Follow system theme
            home: ChangeNotifierProvider(
              create: (context) => MyAppState(),
              child: MyHomePage(),
            ),
          );
        },
    );
  }
}

/// User profile page widget.
/// Displays user information, profile picture, and provides options to
/// logout or delete the account. Handles authentication state and
/// caches profile pictures for better performance.
class UserProfilePage extends StatefulWidget {
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _cachedPhotoURL;

  @override
  void initState() {
    super.initState();
    _loadCachedPhotoURL();
    // Listen for auth state changes to reload cache when user changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _loadCachedPhotoURL();
      }
    });
  }

  Future<void> _loadCachedPhotoURL() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final cachedURL = prefs.getString('user_photo_url_${user.uid}');
      if (mounted) {
        setState(() {
          _cachedPhotoURL = cachedURL;
        });
      }
      // Check if current photo URL is different and update cache in background
      _updatePhotoURLCache(user);
    }
  }

  Future<void> _updatePhotoURLCache(User user) async {
    final currentPhotoURL = user.photoURL;
    if (currentPhotoURL != null && currentPhotoURL != _cachedPhotoURL) {
      // Photo URL has changed, update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_photo_url_${user.uid}', currentPhotoURL);
      if (mounted) {
        setState(() {
          _cachedPhotoURL = currentPhotoURL;
        });
      }
    } else if (currentPhotoURL == null && _cachedPhotoURL != null) {
      // Photo was removed, clear cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_photo_url_${user.uid}');
      if (mounted) {
        setState(() {
          _cachedPhotoURL = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MyAppState>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('You are not logged in.'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (_, __, ___) => AuthOverlay(startWithLogin: true),
                ));
              },
              child: Text('Log in'),
            ),
          ],
        ),
      );
    }

    // Use current photo URL if available, otherwise fall back to cached
    final photoURL = user.photoURL ?? _cachedPhotoURL;
    
    // Update cache in background if needed
    if (user.photoURL != null && user.photoURL != _cachedPhotoURL) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updatePhotoURLCache(user);
      });
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display user's profile picture with caching
          ClipOval(
            child: Container(
              width: 80,
              height: 80,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: photoURL != null
                  ? CachedNetworkImage(
                      imageUrl: photoURL,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.account_circle,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      Icons.account_circle,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Logged in as:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            user.displayName ?? user.email ?? 'User',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (user.email != null && user.displayName != null)
            Text(
              user.email!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          SizedBox(height: 40),
          ElevatedButton.icon(
            icon: Icon(Icons.logout),
            label: Text('Logout'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // The auth listener in MyAppState will handle state updates
            },
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.delete_forever),
            label: Text('Delete Account'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _showDeleteAccountDialog(context, user),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text(
            'Are you sure you want to delete your account? This action cannot be undone. '
            'All your data will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteAccount(context, user);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context, User user) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );

      // Delete user's Firestore data
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (e) {
        print("Error deleting Firestore data: $e");
        // Continue even if Firestore deletion fails
      }

      // Delete the Firebase Auth account
      await user.delete();

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Sign out (should already be done by user.delete(), but just in case)
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        String errorMessage = 'Failed to delete account';
        if (e.code == 'requires-recent-login') {
          errorMessage = 'Please log out and log back in, then try deleting your account again.';
        } else {
          errorMessage = 'Error: ${e.message ?? e.code}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

/// Authentication overlay widget.
/// Provides a modal overlay for user authentication with support for:
/// - Email/Password authentication
/// - Google Sign-In
/// - Facebook Sign-In
/// - Apple Sign-In (iOS)
/// Features a blurred background and card-based UI design.
class AuthOverlay extends StatefulWidget {
  final bool startWithLogin;

  const AuthOverlay({super.key, required this.startWithLogin});

  @override
  State<AuthOverlay> createState() => _AuthOverlayState();
}

class _AuthOverlayState extends State<AuthOverlay> {
  late bool _isLogin;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = widget.startWithLogin;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(); // Close overlay on success
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = e.message ?? "Authentication Error";
        if (e.code == 'operation-not-allowed') {
          errorMessage = "Email/Password authentication is not enabled. Please enable it in Firebase Console > Authentication > Sign-in method > Email/Password";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

    Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      // Initialize GoogleSignIn with explicit Web Client ID
      // This is the Web Client ID from Firebase Console > Authentication > Sign-in method > Google
      await googleSignIn.initialize(
        serverClientId: '718875273858-u9je75l2slav7mob1u9qos3ocj3duldq.apps.googleusercontent.com',
      );
      
      GoogleSignInAccount? googleUser;
      
      // Use authenticate() which returns the account directly
      if (googleSignIn.supportsAuthenticate()) {
        googleUser = await googleSignIn.authenticate(scopeHint: ['email']);
      } else {
        // Fallback: try lightweight authentication
        googleUser = await googleSignIn.attemptLightweightAuthentication();
      }

      if (googleUser != null) {
        // Get authentication token (idToken)
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        // Get authorization token (accessToken) for the email scope
        final GoogleSignInClientAuthorization clientAuth = 
            await googleUser.authorizationClient.authorizeScopes(['email']);
        
        // Create Firebase credential
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: clientAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // Log detailed error for debugging
        print("FirebaseAuthException: ${e.code} - ${e.message}");
        print("Error details: ${e.toString()}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${e.code}: ${e.message ?? "Google Sign-In Error"}")),
        );
      }
    } on GoogleSignInException catch (e) {
      if (mounted) {
        String errorMessage = "Google Sign-In Error";
        if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
          errorMessage = "Google Sign-In not configured. Please add web client ID to AndroidManifest.xml";
        } else {
          errorMessage = "Google Sign-In Error: ${e.code}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }


  Future<void> _signInWithFacebook() async {
    try {
      // Trigger the Facebook login flow with email permission
      // Note: flutter_facebook_auth automatically tries native login first (if Facebook app is installed),
      // then falls back to webview. This provides the best user experience.
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        // The package automatically prefers native login when available
      );
      
      if (loginResult.status == LoginStatus.success) {
        // Create a credential from the access token
        final OAuthCredential facebookAuthCredential = 
            FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);
        
        // Check if user is already signed in - if so, link accounts
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Link Facebook credential to existing account
          await currentUser.linkWithCredential(facebookAuthCredential);
          if (mounted) Navigator.of(context).pop();
        } else {
          // Sign in to Firebase with the Facebook credential
          await FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Facebook login cancelled or failed: ${loginResult.message}")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        // Log detailed error for debugging
        print("FirebaseAuthException: ${e.code} - ${e.message}");
        print("Error details: ${e.toString()}");
        String errorMessage = e.message ?? "Facebook Sign-In Error";
        if (e.code == 'operation-not-allowed') {
          errorMessage = "Facebook Sign-In is not enabled. Please enable it in Firebase Console > Authentication > Sign-in method > Facebook";
        } else if (e.code == 'account-exists-with-different-credential') {
          // Account exists with different credential - try to link if user is signed in
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && e.credential != null) {
            try {
              // User is signed in, link the Facebook credential
              await currentUser.linkWithCredential(e.credential!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Facebook account linked successfully!")),
                );
                Navigator.of(context).pop();
              }
              return; // Successfully linked, exit early
            } catch (linkError) {
              if (linkError is FirebaseAuthException) {
                errorMessage = "Could not link Facebook account: ${linkError.message}";
              } else {
                errorMessage = "Could not link Facebook account. Please try signing in with your existing method first.";
              }
            }
          } else {
            // User not signed in - prompt to sign in with existing method first
            final email = e.email;
            String provider = 'your existing sign-in method';
            if (e.credential != null) {
              final providerId = e.credential!.providerId;
              if (providerId.contains('google')) {
                provider = 'Google';
              } else if (providerId.contains('password')) {
                provider = 'Email/Password';
              }
            }
            errorMessage = "An account with email ${email ?? 'this email'} already exists. Please sign in with $provider first, then you can link Facebook.";
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print("Facebook Sign-In Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Facebook Sign-In Error: $e")),
        );
      }
    }
  }

  Future<void> _signInWithApple() async {
    try {
      // Use native Apple Sign-In on iOS, fallback to Firebase webview on other platforms
      if (Platform.isIOS) {
        // Native Apple Sign-In on iOS
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        // Create Firebase credential from Apple credential
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        // Check if user is already signed in - if so, link accounts
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Link Apple credential to existing account
          await currentUser.linkWithCredential(oauthCredential);
          if (mounted) Navigator.of(context).pop();
        } else {
          // Sign in to Firebase with the Apple credential
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        // Fallback to Firebase webview for Android/Web
        await FirebaseAuth.instance.signInWithProvider(OAuthProvider('apple.com'));
        if (mounted) Navigator.of(context).pop();
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (mounted) {
        String errorMessage = "Apple Sign-In Error";
        switch (e.code) {
          case AuthorizationErrorCode.canceled:
            errorMessage = "Apple Sign-In was cancelled";
            break;
          case AuthorizationErrorCode.failed:
            errorMessage = "Apple Sign-In failed: ${e.message}";
            break;
          case AuthorizationErrorCode.invalidResponse:
            errorMessage = "Invalid response from Apple Sign-In";
            break;
          case AuthorizationErrorCode.notHandled:
            errorMessage = "Apple Sign-In not handled";
            break;
          case AuthorizationErrorCode.notInteractive:
            errorMessage = "Apple Sign-In requires user interaction";
            break;
          case AuthorizationErrorCode.unknown:
            errorMessage = "Unknown Apple Sign-In error";
            break;
          default:
            errorMessage = "Apple Sign-In error: ${e.code}";
            break;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Apple Sign-In Error")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Apple Sign-In Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isLogin ? 'Logon' : 'Register';
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final double padding = isLandscape ? 16.0 : 32.0;
    final double spacing = isLandscape ? 10.0 : 30.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
            ),
          ),
          // Close Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Main Content
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 400,
                    ),
                    child: Card(
                      color: theme.colorScheme.surface,
                      elevation: 8,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Large Social Icons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialIcon(
                                  icon: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Image.asset(
                                      'assets/google_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  onPressed: _signInWithGoogle,
                                ),
                                SizedBox(width: 20),
                                _SocialIcon(
                                  icon: Icon(Icons.facebook, color: Theme.of(context).colorScheme.primary, size: 45),
                                  onPressed: _signInWithFacebook,
                                ),
                                SizedBox(width: 20),
                                _SocialIcon(
                                  icon: Icon(Icons.apple, color: Theme.of(context).colorScheme.onSurface, size: 45),
                                  onPressed: _signInWithApple,
                                ),
                              ],
                            ),
                            SizedBox(height: spacing),
                            // Email/Password Entry
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock),
                              ),
                              obscureText: true,
                            ),
                            SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _authenticate,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: Text(title),
                              ),
                            ),
                            SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                });
                              },
                              child: Text(_isLogin
                                  ? 'Need an account? Register'
                                  : 'Have an account? Logon'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable widget for social authentication icons.
/// Displays a clickable icon button for social login providers.
class _SocialIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;

  const _SocialIcon({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      iconSize: 45,
    );
  }
}

/// Core application state management class.
/// Manages the application's business logic including:
/// - Current word pair generation
/// - History of generated word pairs
/// - Favorite word pairs with cloud sync
/// - Sorting options for favorites
/// - Audio playback for user interactions
/// Uses ChangeNotifier for reactive state updates throughout the app.
class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var history = <WordPair>[];  // list of word pairs that have been generated
  bool _hasLoggedInBefore = false;
  SortOption _sortOption = SortOption.oldestToLatest;

  SortOption get sortOption => _sortOption;

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  /// Toggles alphabetical sorting between A-Z and Z-A.
  /// If currently using date-based sorting, switches to A-Z alphabetical.
  void toggleAlphabeticalSort() {
    if (_sortOption == SortOption.alphabetical) {
      _sortOption = SortOption.reverseAlphabetical;
    } else if (_sortOption == SortOption.reverseAlphabetical) {
      _sortOption = SortOption.alphabetical;
    } else {
      // Switch to alphabetical from date-based sorting
      _sortOption = SortOption.alphabetical;
    }
    notifyListeners();
  }

  /// Toggles date-based sorting between Oldest to Newest and Newest to Oldest.
  /// If currently using alphabetical sorting, switches to Oldest to Newest.
  void toggleDateSort() {
    if (_sortOption == SortOption.oldestToLatest) {
      _sortOption = SortOption.latestToOldest;
    } else if (_sortOption == SortOption.latestToOldest) {
      _sortOption = SortOption.oldestToLatest;
    } else {
      // Switch to date-based sorting from alphabetical
      _sortOption = SortOption.oldestToLatest;
    }
    notifyListeners();
  }

  /// Returns true if currently using alphabetical sorting (A-Z or Z-A).
  bool get isAlphabeticalSort => 
      _sortOption == SortOption.alphabetical || 
      _sortOption == SortOption.reverseAlphabetical;

  /// Returns true if currently using date-based sorting (Oldest to Newest or Newest to Oldest).
  bool get isDateSort => 
      _sortOption == SortOption.oldestToLatest || 
      _sortOption == SortOption.latestToOldest;

  /// Returns favorites list sorted according to the current sort option.
  /// Applies alphabetical or date-based sorting based on user selection.
  List<WordPair> get sortedFavorites {
    List<WordPair> sorted = List.from(favorites);
    switch (_sortOption) {
      case SortOption.latestToOldest:
        return sorted.reversed.toList();
      case SortOption.oldestToLatest:
        return sorted;
      case SortOption.alphabetical:
        sorted.sort((a, b) => a.asLowerCase.compareTo(b.asLowerCase));
        return sorted;
      case SortOption.reverseAlphabetical:
        sorted.sort((a, b) => b.asLowerCase.compareTo(a.asLowerCase));
        return sorted;
    }
  }

  bool get hasLoggedInBefore => _hasLoggedInBefore;
  
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  Future<void> _playSound() async {
    try {
      // Stop any ongoing playback before starting a new one
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/button_click.mp3'));
    } catch (e) {
      // Fallback to system sound if custom sound fails
      SystemSound.play(SystemSoundType.click);
    }
  }
  
  Future<void> _playDeleteSound() async {
    try {
      // Stop any ongoing playback before starting a new one
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/delete.mp3'));
    } catch (e) {
      // Fallback to system sound if custom sound fails
      SystemSound.play(SystemSoundType.click);
    }
  }

  MyAppState() {
    _init();
  }

  Future<void> _init() async {
    await _loadFavorites();
    await _loadLoginHistory();
    await _loadCurrentAndHistory();
    
    // Check if user is already logged in and refresh token if needed
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User is already logged in - refresh token to ensure it's valid
      try {
        await currentUser.getIdToken(true); // Force refresh
        _mergeFavorites(currentUser);
        _setLoggedInBefore();
      } catch (e) {
        // Token refresh failed, user might need to re-login
        // Firebase Auth will handle this automatically
      }
    }
    
    // Listen for auth state changes (login/logout)
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _mergeFavorites(user);
        _setLoggedInBefore();
      }
      notifyListeners();
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? items = prefs.getStringList('favorites');
    if (items != null) {
      favorites = items.map((item) {
        final parts = item.split('|');
        return WordPair(parts[0], parts[1]);
      }).toSet();
      notifyListeners();
    }
  }

  Future<void> _loadLoginHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _hasLoggedInBefore = prefs.getBool('hasLoggedInBefore') ?? false;
    notifyListeners();
  }

  Future<void> _loadCurrentAndHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load current word pair
      final currentString = prefs.getString('currentWordPair');
      if (currentString != null && currentString.isNotEmpty) {
        final parts = currentString.split('|');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          current = WordPair(parts[0], parts[1]);
        }
      }
      
      // Load history
      final historyList = prefs.getStringList('wordHistory');
      if (historyList != null && historyList.isNotEmpty) {
        history = historyList.map((item) {
          final parts = item.split('|');
          if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
            return WordPair(parts[0], parts[1]);
          }
          return null;
        }).whereType<WordPair>().toList();
      }
      
      notifyListeners();
    } catch (e) {
      print("Error loading current and history: $e");
      // Continue with default values if loading fails
    }
  }

  Future<void> saveCurrentAndHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save current word pair
      await prefs.setString('currentWordPair', '${current.first}|${current.second}');
      
      // Save history
      final historyList = history.map((pair) => '${pair.first}|${pair.second}').toList();
      await prefs.setStringList('wordHistory', historyList);
      
      print("Saved current: ${current.asLowerCase}, history count: ${history.length}");
    } catch (e) {
      print("Error saving current and history: $e");
    }
  }

  Future<void> _setLoggedInBefore() async {
    if (!_hasLoggedInBefore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasLoggedInBefore', true);
      _hasLoggedInBefore = true;
      notifyListeners();
    }
  }

  Future<void> _mergeFavorites(User user) async {
    final db = FirebaseFirestore.instance;
    try {
      final doc = await db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('favorites')) {
          final List<dynamic> cloudList = data['favorites'];
          for (var item in cloudList) {
            final parts = (item as String).split('|');
            favorites.add(WordPair(parts[0], parts[1]));
          }
        }
      }
      notifyListeners();
      _saveFavorites();
    } catch (e) {
      print("Error syncing: $e");
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final items = favorites.map((p) => "${p.first}|${p.second}").toList();
    await prefs.setStringList('favorites', items);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'favorites': items});
    }
  }

  /// Generates a new random word pair.
  /// Called when user interacts with the big card to generate a new word pair.
  /// Adds current word pair to history and plays sound effect.
  void getNext() {
    _playSound();
    history.add(current);
    current = WordPair.random();
    notifyListeners();
    saveCurrentAndHistory(); // Save state after change
  }

  /// Set of favorite word pairs.
  /// Synced with local storage and Firebase Firestore for cloud backup.
  var favorites = <WordPair>{};

  /// Toggles the favorite status of the current word pair.
  /// Adds to favorites if not present, removes if already favorited.
  /// No sound effect is played for this action.
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
    _saveFavorites();
  }

  /// Plays the delete sound effect.
  /// Used when a favorite word pair is deleted via swipe gesture.
  void playDeleteSound() {
    _playDeleteSound();
  }

  /// Removes a word pair from favorites.
  /// Called when user confirms deletion via swipe-to-delete gesture.
  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    notifyListeners();
    _saveFavorites();
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
    saveCurrentAndHistory(); // Save state after clearing
  }

  void clearFavorites() {
    favorites.clear();
    notifyListeners();
    _saveFavorites(); // Save state after clearing
  }
}

/// Main home page widget that serves as the root navigation container.
/// Manages the navigation rail (sidebar) and displays different pages
/// (Generator, Favorites, Profile) based on user selection.
/// Handles navigation rail expansion/collapse animations and gesture controls.
class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  bool isExtended = false;
  bool _isOpenByGesture = false;
  Timer? _hoverTimer;
  var selectedIndex = 0;
  Orientation? _previousOrientation;
  double _dragStartX = 0.0;
  bool _isRailDrag = false; // Track if this drag is meant for the navigation rail
  late AnimationController _railController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't access MediaQuery here - it will be set in didChangeDependencies
    _railController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hoverTimer?.cancel();
    _railController.dispose();
    super.dispose();
  }

  void _animateRail(bool open) {
    if (open) {
      _railController.animateTo(1.0, duration: Duration(milliseconds: 800), curve: Curves.elasticOut);
    } else {
      _railController.animateTo(0.0, duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    
    // Initialize on first call
    if (_previousOrientation == null) {
      _previousOrientation = currentOrientation;
      // Set initial state for landscape mode
      if (currentOrientation == Orientation.landscape && !isExtended) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              isExtended = true;
            });
            _railController.value = 1.0;
          }
        });
      }
      return;
    }
    
    // Detect orientation change
    if (_previousOrientation != currentOrientation) {
      final isLandscape = currentOrientation == Orientation.landscape;
      
      if (isLandscape) {
        // Switching to landscape - extend navigation rail
        if (!isExtended) {
          setState(() {
            isExtended = true;
          });
          _railController.value = 1.0;
        }
      } else {
        // Switching to portrait - contract navigation rail and restore behaviors
        if (isExtended) {
          _hoverTimer?.cancel();
          setState(() {
            isExtended = false;
          });
          _railController.value = 0.0;
        }
      }
    }
    
    _previousOrientation = currentOrientation;
  }

  void _onMouseEnter(PointerEnterEvent event, bool isLandscape) {
    if (isLandscape) return; // Disable in landscape
    
    _hoverTimer?.cancel();
    setState(() {
      isExtended = true;
    });
    _animateRail(true);
  }

  void _onMouseExit(PointerExitEvent event, bool isLandscape) {
    if (isLandscape || _isOpenByGesture) return; // Disable in landscape or if manually opened
    
    _hoverTimer?.cancel();
    _hoverTimer = Timer(Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          isExtended = false;
        });
        _animateRail(false);
      }
    });
  }

  Widget _buildPage() {
    switch (selectedIndex) {
      case 0:
        return GeneratorPage();
      case 1:
        return FavoritesPage();
      case 2:
        return UserProfilePage();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }
  }

  List<NavigationRailDestination> _buildNavigationDestinations(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;
    return [
      NavigationRailDestination(
        icon: Icon(Icons.home, color: iconColor),
        selectedIcon: Icon(Icons.home, color: iconColor),
        label: Text('Home'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.favorite, color: iconColor),
        selectedIcon: Icon(Icons.favorite, color: iconColor),
        label: Text('Favorites'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.login, color: iconColor),
        selectedIcon: Icon(Icons.login, color: iconColor),
        label: Text('Logon'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.delete, color: iconColor),
        selectedIcon: Icon(Icons.delete, color: iconColor),
        label: Text('Clear Favorites'),
      ),
    ];
  }

  Future<void> _handleProfileNavigation(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Already logged in, show profile page
      setState(() {
        selectedIndex = 2;
      });
    } else {
      // Not logged in, show overlay
      final appState = context.read<MyAppState>();
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => AuthOverlay(
          startWithLogin: appState.hasLoggedInBefore,
        ),
      ));

      if (FirebaseAuth.instance.currentUser != null) {
        setState(() {
          selectedIndex = 2;
        });
      }
    }
  }

  void _showClearFavoritesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 180,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Clear Favorites?', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('This action will delete all favorite word pairs and cannot be undone.', textAlign: TextAlign.center),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      context.read<MyAppState>().clearFavorites();
                      Navigator.pop(context);
                    },
                    child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      _isRailDrag = false;
      return;
    }

    // Only allow drag from left edge if closed, or if rail is already extended
    if (!isExtended && _dragStartX > 100) {
      _isRailDrag = false;
      return;
    }

    // This is a valid navigation rail drag
    _isRailDrag = true;
    _railController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only process if this is a valid navigation rail drag
    if (!_isRailDrag) return;
    
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      _isRailDrag = false;
      return;
    }

    double delta = details.primaryDelta ?? 0;
    _railController.value += delta / 184.0; // 184 is the expansion width (256 - 72)
  }

  void _onHorizontalDragEnd(DragEndDetails details, bool isLandscape) {
    // Only process if this is a valid navigation rail drag
    if (!_isRailDrag) {
      _isRailDrag = false;
      return;
    }
    
    if (isLandscape) {
      _isRailDrag = false;
      return;
    }

    final double velocity = details.primaryVelocity ?? 0;
    
    if (_railController.value > 0.5 || velocity > 500) {
      _railController.animateTo(1.0, duration: Duration(milliseconds: 500), curve: Curves.easeOut);
      setState(() {
        isExtended = true;
        _isOpenByGesture = true;
      });
      _hoverTimer?.cancel();
    } else {
      _railController.animateTo(0.0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
      setState(() {
        isExtended = false;
        _isOpenByGesture = false;
      });
    }
    
    // Reset flag after processing
    _isRailDrag = false;
  }

  void _handleDestinationSelected(BuildContext context, int value) async {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (!isLandscape && !_isOpenByGesture) {
      _hoverTimer?.cancel();
      _hoverTimer = Timer(Duration(milliseconds: 1500), () {
        if (mounted) {
          final isLandscapeNow = MediaQuery.of(context).orientation == Orientation.landscape;
          if (!isLandscapeNow) {
            setState(() {
              isExtended = false;
            });
            _animateRail(false);
          }
        }
      });
    }

    if (value == 2) {
      await _handleProfileNavigation(context);
    } else if (value == 3) {
      _showClearFavoritesDialog(context);
    } else {
      setState(() {
        selectedIndex = value;
      });
    }
  }

  // Get navigation rail background color
  Color _getNavigationRailBackground(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Use surface for navigation rail in both modes
    return colorScheme.surface;
  }

  Widget _buildMainContent(BuildContext context, bool isLandscape) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Use secondaryContainer for both light and dark mode to match selected item background
    final backgroundColor = colorScheme.secondaryContainer;
    
    if (isLandscape) {
      return Row(
        children: [
          SizedBox(width: 256),
          Expanded(
            child: Container(
              color: backgroundColor,
              child: SafeArea(
                left: false,
                child: Center(
                  child: _buildPage(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _railController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(184 * _railController.value, 0),
          child: Row(
            children: [
              SafeArea(
                child: SizedBox(width: 72),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (isExtended && !isLandscape) {
                      _hoverTimer?.cancel();
                      setState(() {
                        isExtended = false;
                        _isOpenByGesture = false;
                      });
                      _animateRail(false);
                    }
                  },
                  child: Container(
                    color: backgroundColor,
                    child: SafeArea(
                      left: false,
                      child: Center(
                        child: _buildPage(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool isLandscape) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isLandscape ? null : () {
          setState(() {
            isExtended = !isExtended;
            if (!isExtended) _isOpenByGesture = false;
          });
          _animateRail(isExtended);
          _hoverTimer?.cancel();
          if (isExtended) {
            _hoverTimer = Timer(Duration(milliseconds: 1500), () {
              if (mounted && !isLandscape) {
                setState(() {
                  isExtended = false;
                });
                _animateRail(false);
              }
            });
          }
        },
        child: MouseRegion(
          onEnter: isLandscape ? null : (event) => _onMouseEnter(event, isLandscape),
          onExit: isLandscape ? null : (event) => _onMouseExit(event, isLandscape),
          child: AnimatedBuilder(
            animation: _railController,
            builder: (context, child) {
              return Container(
                color: _getNavigationRailBackground(context),
                width: 72 + 184 * _railController.value,
                child: SafeArea(
                  right: false,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 72,
                      maxWidth: 256,
                      alignment: Alignment.centerLeft,
                      child: NavigationRail(
                        extended: true,
                        minWidth: 72,
                        minExtendedWidth: 256,
                        backgroundColor: Colors.transparent,
                        destinations: _buildNavigationDestinations(context),
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (value) => _handleDestinationSelected(context, value),
                      ),
                    ),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if in landscape mode
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        
        // Ensure navigation rail is extended in landscape mode
        if (isLandscape && !isExtended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                isExtended = true;
              });
              _railController.value = 1.0;
            }
          });
        }
        
        return Scaffold(
          body: GestureDetector(
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, isLandscape),
            child: Stack(
              children: [
                _buildMainContent(context, isLandscape),
                _buildNavigationRail(context, isLandscape),
              ],
            ),
          ),
        );
      }
    );
  }
}

/// Favorites page widget.
/// Displays all favorite word pairs with:
/// - Sort options (alphabetical or date-based)
/// - Swipe-to-delete functionality (Gmail-like)
/// - Scrollbar with drag handle for quick navigation (when alphabetically sorted)
/// - Letter indicator bubble when dragging scrollbar
/// Supports both portrait and landscape orientations.
class FavoritesPage extends StatefulWidget {
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;
  double _dragPosition = 0.0; // 0.0 to 1.0
  String _currentLetter = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isDragging && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        setState(() {
          _dragPosition = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
        });
      }
    }
  }

  void _handleDrag(double dy, double height, List<WordPair> items) {
    if (items.isEmpty || height <= 0) return;

    // Clamp position between 0 and 1
    double position = (dy / height).clamp(0.0, 1.0);

    // Update scroll position
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(position * maxScroll);
    }

    // Determine letter
    int index = (position * (items.length - 1)).round();
    String letter = '';
    if (index >= 0 && index < items.length) {
      letter = items[index].asLowerCase.substring(0, 1).toUpperCase();
    }

    // Only trigger haptic, sound, and state update if letter changed
    if (letter != _currentLetter) {
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
    }

    setState(() {
      _dragPosition = position;
      _isDragging = true;
      _currentLetter = letter;
    });
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var theme = Theme.of(context);
    final sortedItems = appState.sortedFavorites;
    final bool showScrollbar = appState.isAlphabeticalSort && sortedItems.isNotEmpty;
    final bool isReversed = appState.sortOption == SortOption.reverseAlphabetical;
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return LayoutBuilder(builder: (context, constraints) {
      // Calculate size based on orientation:
      // Portrait: 80% of width
      // Landscape: 90% of height
      double iconSize;
      if (constraints.maxWidth < constraints.maxHeight) {
        iconSize = constraints.maxWidth * 0.8;
      } else {
        iconSize = constraints.maxHeight * 0.9;
      }

      // Calculate max width for list - account for scrollbar in both orientations
      final double scrollbarWidth = 48; // Width of scrollbar including padding
      final double maxListWidth = showScrollbar 
          ? (isLandscape ? constraints.maxWidth - scrollbarWidth - 4 : constraints.maxWidth - scrollbarWidth - 4)
          : (isLandscape ? constraints.maxWidth - 20 : 400);

      return Stack(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.favorite,
                    size: iconSize,
                    color: theme.colorScheme.primary.withOpacity(0.2)),
                Text(
                  '${appState.favorites.length}',
                  style: theme.textTheme.displayLarge!.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                    fontSize: iconSize * 0.3,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              SizedBox(height: 20),
              // Sort Options - Two toggle buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Alphabetical sorting toggle (A-Z) - always shows A-Z icon
                    _AlphabeticalSortButton(),
                    // Date sorting toggle (Oldest to Newest / Newest to Oldest)
                    _DateSortButton(),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxListWidth),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: sortedItems.length,
                          itemBuilder: (context, index) {
                            var pair = sortedItems[index];
                            return FavoriteItem(
                              key: ValueKey(pair),
                              pair: pair,
                              appState: appState,
                            );
                          },
                        ),
                      ),
                    ),
                    if (_isDragging && _currentLetter.isNotEmpty)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                              decoration: BoxDecoration(
                                color: (theme.brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.black).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _currentLetter,
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: theme.brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showScrollbar)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                isReversed ? 'Z' : 'A',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, scrollConstraints) {
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onVerticalDragStart: (details) => _handleDrag(details.localPosition.dy, scrollConstraints.maxHeight, sortedItems),
                                    onVerticalDragUpdate: (details) => _handleDrag(details.localPosition.dy, scrollConstraints.maxHeight, sortedItems),
                                    onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                                    onTapUp: (details) {
                                      _handleDrag(details.localPosition.dy, scrollConstraints.maxHeight, sortedItems);
                                      setState(() => _isDragging = false);
                                    },
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        // Invisible track to capture touches
                                        Container(color: Colors.transparent),
                                        // The Handle
                                        Align(
                                          alignment: Alignment(0, _dragPosition * 2 - 1),
                                          child: Container(
                                            width: 8,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                isReversed ? 'A' : 'Z',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

/// Individual favorite word pair item widget.
/// Implements Gmail-like swipe-to-delete functionality:
/// - Swipe right to reveal delete action
/// - Word pair rectangle shrinks from left as delete rectangle expands
/// - Trash icon with vibration animation on delete confirmation
/// - Smooth animations for swipe and deletion
/// Uses SizeTransition for list item animations.
class FavoriteItem extends StatefulWidget {
  const FavoriteItem({
    super.key,
    required this.pair,
    required this.appState,
  });

  final WordPair pair;
  final MyAppState appState;

  @override
  State<FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<FavoriteItem> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _swipeController;
  late AnimationController _trashAnimationController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _swipeAnimation;
  late Animation<double> _trashVibrationAnimation;
  
  double _dragOffset = 0.0;
  double? _screenWidth;
  
  // Thresholds for swipe behavior
  static const double _trashIconThreshold = 40.0; // Show trash icon threshold
  static const double _deleteThreshold = 120.0; // Auto-delete threshold
  static const double _resistanceFactor = 0.4; // Initial swipe is 40% of finger movement

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0,
    );
    _sizeAnimation = _controller;
    
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOut),
    );
    
    _trashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _trashVibrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _trashAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _swipeController.dispose();
    _trashAnimationController.dispose();
    super.dispose();
  }
  
  void _onPanStart(DragStartDetails details) {
    _screenWidth = MediaQuery.of(context).size.width;
    _swipeController.stop();
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Use primaryDelta for horizontal drag gestures
      double delta = details.primaryDelta ?? 0.0;
      
      // Only process rightward drags (positive delta) or leftward when already dragged
      if (delta > 0) {
        // Apply resistance factor for initial movement
        if (_dragOffset < _trashIconThreshold) {
          _dragOffset += delta * _resistanceFactor;
        } else {
          // Less resistance after passing trash icon threshold
          _dragOffset += delta * 0.8;
        }
        _dragOffset = _dragOffset.clamp(0.0, double.infinity);
      } else if (delta < 0 && _dragOffset > 0) {
        // Allow bounce back when dragging left
        _dragOffset += delta;
        _dragOffset = _dragOffset.clamp(0.0, double.infinity);
      }
    });
  }
  
  void _onPanEnd(DragEndDetails details) {
    // Check if we've passed the delete threshold
    if (_dragOffset >= _deleteThreshold && _screenWidth != null) {
      // Play sound immediately upon confirmation
      widget.appState.playDeleteSound();
      
      // Animate trash icon vibration
      _trashAnimationController.forward();
      
      // Auto-complete swipe: quickly swipe all the way to the right
      final targetOffset = _screenWidth!;
      final startOffset = _dragOffset;
      
      _swipeController.reset();
      _swipeAnimation = Tween<double>(
        begin: startOffset,
        end: targetOffset,
      ).animate(CurvedAnimation(
        parent: _swipeController,
        curve: Curves.easeOut,
      ));
      
      void animationListener() {
        if (mounted) {
          setState(() {
            _dragOffset = _swipeAnimation.value;
          });
        }
      }
      
      _swipeAnimation.addListener(animationListener);
      
      _swipeController.forward().then((_) {
        _swipeAnimation.removeListener(animationListener);
        // After swipe completes, shrink and delete
        if (mounted) {
          _controller.reverse().then((_) {
            if (mounted) {
              widget.appState.removeFavorite(widget.pair);
            }
          });
        }
      });
    } else {
      // Bounce back to center with animation
      final startOffset = _dragOffset;
      _swipeController.reset();
      _swipeAnimation = Tween<double>(
        begin: startOffset,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _swipeController,
        curve: Curves.easeOut,
      ));
      
      void animationListener() {
        if (mounted) {
          setState(() {
            _dragOffset = _swipeAnimation.value;
          });
        }
      }
      
      _swipeAnimation.addListener(animationListener);
      
      _swipeController.forward().then((_) {
        if (mounted) {
          _swipeAnimation.removeListener(animationListener);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _screenWidth ??= MediaQuery.of(context).size.width;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available width (account for horizontal margins: 8px on each side = 16px total)
        final availableWidth = constraints.maxWidth;
        final maxAvailableWidth = availableWidth - 16.0;
        
        // Calculate delete background width
        final deleteBackgroundWidth = _dragOffset.clamp(0.0, maxAvailableWidth);
        final showDeleteBackground = deleteBackgroundWidth > 0;
        
        // Calculate word pair width and position
        // Word pair shrinks from left: its left edge moves right as delete expands
        // Right edge stays fixed at: 8 + maxAvailableWidth
        final wordPairFullWidth = maxAvailableWidth;
        final wordPairWidth = (wordPairFullWidth - deleteBackgroundWidth).clamp(0.0, wordPairFullWidth);
        final wordPairLeft = 8 + deleteBackgroundWidth; // Left edge moves right as delete expands
        
        return SizeTransition(
          sizeFactor: _sizeAnimation,
          axisAlignment: -1.0,
          child: SizedBox(
            height: 60, // Fixed height for spacing
            child: GestureDetector(
              onHorizontalDragStart: _onPanStart,
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Delete background (expands from left as user swipes right)
                  if (showDeleteBackground)
                    Positioned(
                      left: 8,
                      top: 4,
                      bottom: 4,
                      width: deleteBackgroundWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16), // Rounder corners
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withOpacity(0.6), // Semi-transparent red
                            borderRadius: BorderRadius.circular(16), // Rounder corners
                          ),
                          child: deleteBackgroundWidth >= 44
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: AnimatedBuilder(
                                        animation: _trashVibrationAnimation,
                                        builder: (context, child) {
                                          // Create vibration effect with quick shake
                                          final shakeAmount = 3.0;
                                          final shakeX = (math.sin(_trashVibrationAnimation.value * 20) * shakeAmount);
                                          final shakeY = (math.cos(_trashVibrationAnimation.value * 20) * shakeAmount);
                                          return Transform.translate(
                                            offset: Offset(shakeX, shakeY),
                                            child: Icon(
                                              Icons.delete_outline,
                                              color: theme.colorScheme.onError,
                                              size: 28,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox.shrink(),
                        ),
                      ),
                    ),
                  // Word pair rectangle (shrinks from left, right edge stays fixed)
                  // Left edge moves right as delete expands, right edge stays at same position
                  Positioned(
                    left: wordPairLeft, // Left edge moves right as delete expands
                    top: 4,
                    bottom: 4,
                    width: wordPairWidth, // Width shrinks by deleteBackgroundWidth amount
                    child: Container(
                      decoration: BoxDecoration(
                        color: (theme.brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite),
                            SizedBox(width: 10),
                            Text(widget.pair.asLowerCase),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Word pair generator page widget.
/// Main page for generating and displaying word pairs:
/// - Shows current word pair in a large interactive card
/// - Displays history of generated word pairs with fade effect
/// - Supports drag-up gesture to generate new word pairs
/// - Shows tutorial prompt for first-time users
/// - Adapts layout for portrait and landscape orientations
class GeneratorPage extends StatefulWidget {
  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> with SingleTickerProviderStateMixin {
  bool _isInitialDisplay = true;
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _listAnimation = Tween<double>(begin: 0.0, end: -35.0)
        .animate(CurvedAnimation(parent: _listController, curve: Curves.easeOut));

    // Mark as no longer initial after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialDisplay = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  /// Handles the card tap/gesture to generate a new word pair.
  /// Triggers list animation, then generates new word pair after animation completes.
  void _handleCardTap(MyAppState appState) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _listController.forward().then((_) {
          appState.getNext();
          _listController.reset();
        });
      }
    });
  }

  /// Updates the drag offset state when user drags the big card.
  /// Used for scaling effect on the history list during drag gesture.
  void _handleDragOffsetChanged(double value) {
    setState(() {
      _dragOffset = value;
    });
  }

  /// Builds the history list widget with fade effect and scaling animation.
  /// Applies transform based on drag offset and list animation state.
  Widget _buildHistoryList(MyAppState appState) {
    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..translate(0.0, _listAnimation.value, 0.0)
        ..scale(1.0, (1.0 + (_dragOffset * 0.003)).clamp(0.85, 1.0), 1.0),
      child: Builder(
        builder: (context) {
          final surfaceColor = Theme.of(context).colorScheme.surface;
          return ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, surfaceColor],
                stops: [0.0, 0.15],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView(
              reverse: true,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < appState.history.length; i++)
                  _buildHistoryItem(appState, i),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds an individual history item with opacity and font size based on position.
  /// Older items have lower opacity and smaller font size for visual hierarchy.
  Widget _buildHistoryItem(MyAppState appState, int index) {
    final pair = appState.history[appState.history.length - 1 - index];
    final opacity = (1.0 - index * 0.1).clamp(0.1, 1.0);
    final fontSize = (25.0 - index).clamp(14.0, 25.0);

    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          appState.favorites.contains(pair)
              ? Icon(Icons.favorite, size: fontSize * 0.7)
              : SizedBox(width: fontSize * 0.7),
          SizedBox(width: 10),
          Text(
            pair.asLowerCase,
            style: TextStyle(fontSize: fontSize),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the BigCard widget with current word pair and all callbacks configured.
  Widget _buildBigCard(WordPair pair, MyAppState appState) {
    return BigCard(
      pair: pair,
      onTap: () => _handleCardTap(appState),
      showInitialPrompt: _isInitialDisplay,
      isFavorite: appState.favorites.contains(pair),
      onToggleFavorite: () => appState.toggleFavorite(),
      onDragOffsetChanged: _handleDragOffsetChanged,
    );
  }

  /// Builds the portrait mode layout with expanded card section.
  Widget _buildPortraitLayout(WordPair pair, MyAppState appState) {
    return Expanded(
      flex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 20),
          _buildBigCard(pair, appState),
        ],
      ),
    );
  }

  /// Builds the landscape mode layout with compact card section.
  Widget _buildLandscapeLayout(WordPair pair, MyAppState appState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          SizedBox(height: 10),
          _buildBigCard(pair, appState),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: _buildHistoryList(appState),
        ),
        if (!isLandscape)
          _buildPortraitLayout(pair, appState)
        else
          _buildLandscapeLayout(pair, appState),
      ],
    );
  }
}

/// Alphabetical sorting toggle button widget.
/// Displays A-Z or Z-A icon based on current alphabetical sort order.
/// Toggles between alphabetical and reverse alphabetical sorting when pressed.
/// Shows selected state with background color when active.
class _AlphabeticalSortButton extends StatelessWidget {
  const _AlphabeticalSortButton();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final isSelected = appState.isAlphabeticalSort;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Show different icon based on current alphabetical sort order
    final String iconPath = appState.sortOption == SortOption.alphabetical
        ? 'assets/icon/az_sort.png'  // A-Z
        : 'assets/icon/za_sort.png';  // Z-A
    
    final String tooltip = appState.sortOption == SortOption.alphabetical
        ? 'A-Z'
        : 'Z-A';

    return IconButton(
      icon: Image.asset(
        iconPath,
        width: 48,
        height: 48,
        color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
      ),
      tooltip: tooltip,
      isSelected: isSelected,
      style: IconButton.styleFrom(
        foregroundColor: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
        backgroundColor: isSelected ? colorScheme.secondaryContainer : null,
      ),
      onPressed: () => appState.toggleAlphabeticalSort(),
    );
  }
}

/// Date sorting toggle button widget.
/// Displays icon for current date sort order (Oldest to Newest or Newest to Oldest).
/// Toggles between the two date-based sorting options when pressed.
/// Shows selected state with background color when active.
class _DateSortButton extends StatelessWidget {
  const _DateSortButton();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final isSelected = appState.isDateSort;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Show icon based on current date sort order
    final String iconPath = appState.sortOption == SortOption.oldestToLatest
        ? 'assets/icon/oldest_newest.png'  // Oldest to Newest
        : 'assets/icon/newest_oldest.png';  // Newest to Oldest
    
    final String tooltip = appState.sortOption == SortOption.oldestToLatest
        ? 'Oldest to Newest'
        : 'Newest to Oldest';

    return IconButton(
      icon: Image.asset(
        iconPath,
        width: 48,
        height: 48,
        color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
      ),
      tooltip: tooltip,
      isSelected: isSelected,
      style: IconButton.styleFrom(
        foregroundColor: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
        backgroundColor: isSelected ? colorScheme.secondaryContainer : null,
      ),
      onPressed: () => appState.toggleDateSort(),
    );
  }
}

/// Large interactive card widget displaying the current word pair.
/// Features:
/// - Frosty transparent background with blur effect
/// - Drag-up gesture to generate new word pairs
/// - Favorite toggle button (heart icon)
/// - Slide-in animation for word pairs
/// - Tutorial prompt with crossfade animation for first-time users
/// - Rebound animation when drag is released
/// - Responsive to theme (light/dark mode)
class BigCard extends StatefulWidget {
  const BigCard({
    super.key,
    required this.pair,
    required this.onTap,
    this.showInitialPrompt = false,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onDragOffsetChanged,
  });

  final WordPair pair;
  final VoidCallback onTap;
  final bool showInitialPrompt;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final ValueChanged<double>? onDragOffsetChanged;

  @override
  State<BigCard> createState() => _BigCardState();
}

class _BigCardState extends State<BigCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _promptController;
  late AnimationController _pressController;
  late Animation<Offset> _slideAnimationLeft;
  late Animation<Offset> _slideAnimationRight;
  late Animation<double> _promptOpacity;
  late Animation<double> _wordOpacity;
  Animation<double>? _tutorialOffset;
  late AnimationController _reboundController;
  late Animation<double> _reboundAnimation;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Animation for word pair sliding
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _slideAnimationLeft = Tween<Offset>(begin: Offset(-2.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _slideAnimationRight = Tween<Offset>(begin: Offset(2.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Animation for prompt text fade in/out
    _promptController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Prompt fades in (0 -> 1) while word fades out (1 -> 0)
    _promptOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _promptController, curve: Curves.easeInOut));
    
    _wordOpacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _promptController, curve: Curves.easeInOut));
    
    // Animation for tutorial gesture (move up)
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Tutorial effect: move up to simulate push up gesture
    _tutorialOffset = Tween<double>(begin: 0.0, end: -50.0)
        .animate(CurvedAnimation(parent: _pressController, curve: Curves.easeInOut));

    // Animation for rebound (spring back)
    _reboundController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _reboundAnimation = Tween<double>(begin: 0, end: 0).animate(_reboundController);
    _reboundController.addListener(() {
      setState(() {
        _dragOffsetY = _reboundAnimation.value;
      });
      // Defer callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDragOffsetChanged?.call(_dragOffsetY);
      });
    });

    // Always start with word visible, prompt hidden
    _promptController.value = 0.0;

    _controller.forward();

    // Show initial prompt animation only if showInitialPrompt is true
    if (widget.showInitialPrompt) {
      // Wait for word slide animation to complete, then crossfade to prompt
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          // Fade in prompt while fading out word (crossfade)
          _promptController.forward().then((_) {
            // After prompt is fully shown, animate press effect
            if (mounted) {
              _pressController.forward().then((_) {
                // Immediately bounce back
                if (mounted) {
                  _pressController.reverse().then((_) {
                    // After bounce back, wait 3 seconds, then crossfade back to word
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) {
                        // Reverse: prompt fades out, word fades in
                        _promptController.reverse();
                      }
                    });
                  });
                }
              });
            }
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(BigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pair != widget.pair) {
      _controller.forward(from: 0.0);
      // Reset prompt opacity when word changes
      if (!widget.showInitialPrompt) {
        _promptController.reset();
      }
      // Stop any ongoing rebound animation first
      _reboundController.stop();
      _reboundController.reset();
      // Reset drag state after stopping animation to prevent listener interference
      setState(() {
        _dragOffsetY = 0.0;
      });
      // Defer callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDragOffsetChanged?.call(0.0);
      });
      // Reset the rebound animation to ensure listener uses correct values
      _reboundAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(_reboundController);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _promptController.dispose();
    _pressController.dispose();
    _reboundController.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    // Stop any ongoing rebound animation immediately when user starts dragging
    if (_reboundController.isAnimating) {
      _reboundController.stop();
      _reboundController.reset();
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // Stop rebound animation if it's still running
    if (_reboundController.isAnimating) {
      _reboundController.stop();
      _reboundController.reset();
    }
    
    setState(() {
      // Apply resistance: move less than the finger
      _dragOffsetY += details.primaryDelta! * 0.4;
    });
    // Defer callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDragOffsetChanged?.call(_dragOffsetY);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // Save the current drag offset before any modifications
    final currentOffset = _dragOffsetY;
    
    // Stop any ongoing rebound animation before starting a new one
    _reboundController.stop();
    
    // If dragged up far enough (negative offset), trigger action
    if (currentOffset < -50) {
      widget.onTap();
      // Don't return here; let the rebound animation play to smooth the transition
    }

    // Animate back to center only if action wasn't triggered and there's an offset
    if (currentOffset != 0.0) {
      _reboundAnimation = Tween<double>(
        begin: currentOffset,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _reboundController,
        curve: Curves.elasticOut,
      ));

      _reboundController.reset();
      _reboundController.forward().then((_) {
        // Ensure _dragOffsetY is exactly 0.0 when animation completes
        if (mounted) {
          setState(() {
            _dragOffsetY = 0.0;
          });
        }
      });
    } else {
      // If already at 0, ensure it stays at 0
      setState(() {
        _dragOffsetY = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Use frosty semitransparent effect in both themes (70% transparency = 30% opacity)
    final cardColor = isDark 
        ? Colors.white.withOpacity(0.3)  // Frosty white in dark theme
        : Colors.black.withOpacity(0.3);  // Frosty dark in light theme
    
    // Text color should contrast with card background
    final style = theme.textTheme.displayMedium!.copyWith(
      color: isDark ? Colors.white : Colors.black87,
      fontSize: 35,
    );

    final promptStyle = theme.textTheme.displayMedium!.copyWith(
      color: isDark ? Colors.white.withOpacity(0.8) : Colors.black54,
      fontSize: 24,
    );

    return Center(
      child: GestureDetector(
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: AnimatedBuilder(
          animation: _tutorialOffset ?? const AlwaysStoppedAnimation(0.0),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _dragOffsetY + (_tutorialOffset?.value ?? 0.0)),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32.0),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.2) 
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                    BoxShadow(
                      color: isDark 
                          ? Colors.black.withOpacity(0.2) 
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Heart icon on the left
                  GestureDetector(
                    onTap: () {
                      widget.onToggleFavorite();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Icon(
                        widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: widget.isFavorite 
                            ? theme.colorScheme.error 
                            : (isDark ? Colors.white.withOpacity(0.8) : Colors.black54),
                        size: 32,
                      ),
                    ),
                  ),
                  // Word pair and prompt
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Word pair with crossfade
                      FadeTransition(
                        opacity: _wordOpacity,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SlideTransition(
                              position: _slideAnimationLeft,
                              child: Text(widget.pair.first, style: style),
                            ),
                            SlideTransition(
                              position: _slideAnimationRight,
                              child: Text(
                                widget.pair.second,
                                style: style.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Prompt text with crossfade
                      FadeTransition(
                        opacity: _promptOpacity,
                        child: Text(
                          'push up to generate',
                          style: promptStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}