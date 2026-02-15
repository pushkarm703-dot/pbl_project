import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

// Import our image validator
part 'image_validator.dart';

// ─────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// FIREBASE SINGLETONS
// ─────────────────────────────────────────────
final _auth      = FirebaseAuth.instance;
final _firestore = FirebaseFirestore.instance;

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
enum ReportStatus { pending, inProgress, completed }

ReportStatus statusFromString(String s) {
  switch (s) {
    case 'inProgress': return ReportStatus.inProgress;
    case 'completed':  return ReportStatus.completed;
    default:           return ReportStatus.pending;
  }
}

// Safely show an image: try network URL first, fall back to local file
Widget _reportImage({
  required String url,
  required String localPath,
  double height = 160,
}) {
  if (url.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        height: height, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _localOrPlaceholder(localPath, height),
      ),
    );
  }
  return _localOrPlaceholder(localPath, height);
}

Widget _localOrPlaceholder(String localPath, double height) {
  if (localPath.isNotEmpty) {
    try {
      final f = File(localPath);
      if (f.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(f,
              height: height, width: double.infinity, fit: BoxFit.cover),
        );
      }
    } catch (_) {}
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: height,
      color: Colors.grey[200],
      child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40)),
    ),
  );
}

// Small thumbnail version for list tiles
Widget _thumbImage({required String url, required String localPath}) {
  if (url.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url, width: 50, height: 50, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _localThumb(localPath)),
    );
  }
  return _localThumb(localPath);
}

Widget _localThumb(String path) {
  if (path.isNotEmpty) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(f, width: 50, height: 50, fit: BoxFit.cover),
        );
      }
    } catch (_) {}
  }
  return const Icon(Icons.image_not_supported, color: Colors.grey, size: 36);
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
Widget _logoHeader({String subtitle = 'your guide to safer streets'}) {
  return Column(children: [
    const SizedBox(height: 60),
    const Icon(Icons.traffic, size: 100, color: Colors.orangeAccent),
    const SizedBox(height: 10),
    const Text('राहनुमा',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
            color: Colors.orangeAccent)),
    const SizedBox(height: 8),
    Text(subtitle,
        style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic,
            color: Colors.white70)),
    const SizedBox(height: 32),
  ]);
}

InputDecoration _field(String hint, IconData icon, {Widget? suffix}) =>
    InputDecoration(
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

// ─────────────────────────────────────────────
// APP
// ─────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Global theme mode state
  static final ValueNotifier<ThemeMode> themeNotifier =
  ValueNotifier(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'राहनुमा',
          themeMode: mode,

          // Light Theme
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[100],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
          ),

          // Dark Theme
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[900],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[850],
              foregroundColor: Colors.white,
            ),
            cardTheme: CardThemeData(
              color: Colors.grey[850],
              elevation: 2,
            ),
          ),

          home: const UserTypePage(),
          routes: {
            '/user_type':   (_) => const UserTypePage(),
            '/login':       (_) => const LoginPage(),
            '/signup':      (_) => const SignupPage(),
            '/admin_login': (_) => const AdminLoginPage(),
            '/user':        (_) => const UserPage(),
            '/alerts':      (_) => const AlertsPage(),
            '/report':      (_) => const ReportProblemPage(),
            '/settings':    (_) => const SettingsPage(),
            '/contact':     (_) => const ContactUsPage(),
            '/faqs':        (_) => const FAQsPage(),
            '/admin':       (_) => const AdminDashboard(),
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// USER TYPE PAGE
// ─────────────────────────────────────────────
class UserTypePage extends StatelessWidget {
  const UserTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Stack(children: [
        Positioned(
          top: 60, left: 20, right: 20,
          child: Column(children: const [
            Icon(Icons.traffic, size: 100, color: Colors.orangeAccent),
            SizedBox(height: 10),
            Text('राहनुमा',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent, letterSpacing: 2)),
            SizedBox(height: 8),
            Text('"your guide to safer streets"',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic,
                    color: Colors.white70)),
            SizedBox(height: 50),
            Text('Who are you?',
                style: TextStyle(fontSize: 20, color: Colors.white)),
          ]),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                icon: const Icon(Icons.person, color: Colors.white),
                label: const Text('User Sign In',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/admin_login'),
                icon: const Icon(Icons.admin_panel_settings,
                    color: Colors.white),
                label: const Text('Administrator Sign In',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN PAGE
// ─────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  String _error = '';
  bool _hide = true, _loading = false;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pw    = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Both fields are required.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pw);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/user');
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email.'; break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect password. Please try again.'; break;
        case 'invalid-email':
          msg = 'Please enter a valid email address.'; break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait and try again.'; break;
        default:
          msg = e.message ?? 'Login failed.';
      }
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _emailCtrl.dispose(); _pwCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: SingleChildScrollView(
        child: Column(children: [
          _logoHeader(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orangeAccent, width: 3),
              borderRadius: BorderRadius.circular(20),
              color: Colors.blueGrey[800],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('User Sign In',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _field('Enter Email', Icons.email),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pwCtrl,
                obscureText: _hide,
                decoration: _field('Enter Password', Icons.lock,
                    suffix: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    )),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account?",
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/signup'),
                  child: const Text('Sign Up',
                      style: TextStyle(color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ]),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/user_type'),
                child: const Text('← Back',
                    style: TextStyle(color: Colors.white54)),
              ),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SIGN UP PAGE
// ─────────────────────────────────────────────
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _cpwCtrl   = TextEditingController();
  String _error = '';
  bool _hide = true, _hideCon = true, _loading = false;

  Future<void> _signup() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw    = _pwCtrl.text;
    final cpw   = _cpwCtrl.text;

    if (name.isEmpty || email.isEmpty || pw.isEmpty || cpw.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (pw != cpw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      // 1. Create Firebase Auth account
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: pw);
      await cred.user!.updateDisplayName(name);

      // 2. Save profile to Firestore (non-blocking if it fails)
      try {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'uid':       cred.user!.uid,
          'name':      name,
          'email':     email,
          'role':      'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Firestore save failed — Auth account still created, user can log in
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/user');

    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered. Please sign in.'; break;
        case 'invalid-email':
          msg = 'Please enter a valid email address.'; break;
        case 'weak-password':
          msg = 'Password is too weak. Use at least 6 characters.'; break;
        default:
          msg = e.message ?? 'Sign up failed.';
      }
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _pwCtrl.dispose();   _cpwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: SingleChildScrollView(
        child: Column(children: [
          _logoHeader(subtitle: 'Create your account'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orangeAccent, width: 3),
              borderRadius: BorderRadius.circular(20),
              color: Colors.blueGrey[800],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Create Account',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _field('Full Name', Icons.badge),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _field('Email Address', Icons.email),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: _hide,
                decoration: _field('Password (min 6 chars)', Icons.lock,
                    suffix: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cpwCtrl,
                obscureText: _hideCon,
                decoration: _field('Confirm Password', Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_hideCon
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _hideCon = !_hideCon),
                    )),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Already have an account?',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Sign In',
                      style: TextStyle(color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ]),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/user_type'),
                child: const Text('← Back',
                    style: TextStyle(color: Colors.white54)),
              ),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADMIN LOGIN PAGE
// ─────────────────────────────────────────────
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  String _error = '';
  bool _hide = true;
  bool _loading = false;

  Future<void> _login() async {
    if (_idCtrl.text.trim().isEmpty || _pwCtrl.text.isEmpty) {
      setState(() => _error = 'Both fields are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Map admin ID to Firebase email
      // When admin enters "admin", we sign in with admin@raahnuma.app
      String email;
      if (_idCtrl.text.trim() == 'admin') {
        email = 'admin@raahnuma.app';
      } else {
        // Allow other admin IDs if needed (e.g., "admin2" -> "admin2@raahnuma.app")
        email = '${_idCtrl.text.trim()}@raahnuma.app';
      }

      // Sign in with Firebase Authentication
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: _pwCtrl.text,
      );

      // Check if user is actually an admin
      final adminDoc = await _firestore
          .collection('admins')
          .doc(_auth.currentUser!.uid)
          .get();

      if (adminDoc.exists && adminDoc.data()?['isAdmin'] == true) {
        // Success! Navigate to admin dashboard
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        // User exists but is not an admin
        await _auth.signOut();
        setState(() {
          _error = 'This account is not authorized as admin.';
          _loading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid Admin ID or Password.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      setState(() {
        _error = message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An error occurred. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() { _idCtrl.dispose(); _pwCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: SingleChildScrollView(
        child: Column(children: [
          _logoHeader(subtitle: 'Administrator Sign In'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 3),
              borderRadius: BorderRadius.circular(20),
              color: Colors.blueGrey[800],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Admin Access',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('ID: admin   Password: admin123',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 16),
              TextField(controller: _idCtrl,
                  decoration: _field('Enter Admin ID', Icons.admin_panel_settings)),
              const SizedBox(height: 14),
              TextField(
                controller: _pwCtrl,
                obscureText: _hide,
                decoration: _field('Enter Password', Icons.lock,
                    suffix: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    )),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Sign In',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/user_type'),
                child: const Text('← Back',
                    style: TextStyle(color: Colors.white54)),
              ),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// USER PAGE
// ─────────────────────────────────────────────
class UserPage extends StatefulWidget {
  const UserPage({super.key});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  LatLng? _userLocation;
  bool _loadingMap = true;
  final MapController _mapController = MapController();

  User? get _me => _auth.currentUser;
  String get _name =>
      _me?.displayName ?? _me?.email?.split('@').first ?? 'User';

  @override
  void initState() { super.initState(); _fetchLocation(); }

  Future<void> _fetchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _loadingMap = false); return;
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        setState(() => _loadingMap = false); return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _loadingMap = false;
      });
    } catch (_) { setState(() => _loadingMap = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('User Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Greeting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.waving_hand, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Hello, $_name!',
                    style: const TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Map
          const Text('Your Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            clipBehavior: Clip.hardEdge,
            child: _loadingMap
                ? const Center(child: CircularProgressIndicator(
                color: Colors.orangeAccent))
                : _userLocation == null
                ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('Location unavailable',
                    style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    setState(() => _loadingMap = true);
                    _fetchLocation();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ))
                : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('reports').snapshots(),
              builder: (ctx, snap) {
                final markers = <Marker>[
                  Marker(point: _userLocation!, width: 50, height: 50,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40)),
                ];
                if (snap.hasData) {
                  for (final doc in snap.data!.docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    final lat = (d['latitude'] as num?)?.toDouble();
                    final lng = (d['longitude'] as num?)?.toDouble();
                    if (lat != null && lng != null) {
                      markers.add(Marker(
                        point: LatLng(lat, lng),
                        width: 36, height: 36,
                        child: const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 30),
                      ));
                    }
                  }
                }
                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: _userLocation!, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.raahnuma',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                );
              },
            ),
          ),
          if (_userLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                'Lat: ${_userLocation!.latitude.toStringAsFixed(5)},  '
                    'Lng: ${_userLocation!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 20),

          // Quick actions
          const Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _qa(context, Icons.report,
                'Report\nProblem', Colors.orange, '/report')),
            const SizedBox(width: 10),
            Expanded(child: _qa(context, Icons.notifications,
                'View\nAlerts', Colors.blue, '/alerts')),
            const SizedBox(width: 10),
            Expanded(child: _qa(context, Icons.settings,
                'Settings', Colors.grey, '/settings')),
          ]),
          const SizedBox(height: 20),

          // My Reports
          const Text('My Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildMyReports(),
        ]),
      ),
    );
  }

  Widget _qa(BuildContext ctx, IconData icon, String label,
      Color color, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(ctx, route)
          .then((_) => setState(() {})),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }

  Widget _buildMyReports() {
    final uid = _me?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('reports')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12)),
            child: const Text('You have not submitted any reports yet.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(children: docs.map((doc) {
          final d      = doc.data() as Map<String, dynamic>;
          final status = statusFromString(d['status'] ?? 'pending');
          final imgUrl  = d['imageUrl']  as String? ?? '';
          final imgPath = d['localPath'] as String? ?? '';

          Color sc; IconData si; String sl;
          switch (status) {
            case ReportStatus.inProgress:
              sc = Colors.blue; si = Icons.autorenew; sl = 'In Progress'; break;
            case ReportStatus.completed:
              sc = Colors.green; si = Icons.check_circle; sl = 'Completed'; break;
            default:
              sc = Colors.orange; si = Icons.pending; sl = 'Pending';
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: _thumbImage(url: imgUrl, localPath: imgPath),
              title: Text(
                (d['description'] ?? '').length > 45
                    ? '${(d['description'] as String).substring(0, 45)}...'
                    : (d['description'] ?? ''),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(d['location'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1),
                  border: Border.all(color: sc),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(si, color: sc, size: 13),
                  const SizedBox(width: 3),
                  Text(sl, style: TextStyle(color: sc, fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
        }).toList());
      },
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: Colors.orangeAccent),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 28, backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 32, color: Colors.orangeAccent)),
            const SizedBox(height: 10),
            Text('Hello, $_name!',
                style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(_me?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        _di(context, Icons.warning, 'Alerts', '/alerts'),
        _di(context, Icons.report, 'Report a Problem', '/report'),
        _di(context, Icons.settings, 'Settings', '/settings'),
        const Divider(),
        _di(context, Icons.contact_support, 'Contact Us', '/contact'),
        _di(context, Icons.help_outline, 'FAQs', '/faqs'),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            await _auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/user_type');
          },
        ),
      ]),
    );
  }

  ListTile _di(BuildContext ctx, IconData icon, String title, String route) =>
      ListTile(
        leading: Icon(icon, color: Colors.orangeAccent),
        title: Text(title),
        onTap: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, route).then((_) => setState(() {}));
        },
      );
}

// ─────────────────────────────────────────────
// ALERTS PAGE — Shows user's own reports only
// ─────────────────────────────────────────────
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Filter to show only current user's reports
        stream: _firestore.collection('reports')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors
          if (snap.hasError) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)),
              ],
            ));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No reports yet.', style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 8),
                const Text('Submit your first report!',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d      = docs[i].data() as Map<String, dynamic>;
              final status = statusFromString(d['status'] ?? 'pending');
              final ts     = (d['timestamp'] as Timestamp?)?.toDate();
              final imgUrl  = d['imageUrl']  as String? ?? '';
              final imgPath = d['localPath'] as String? ?? '';

              Color c; String label;
              switch (status) {
                case ReportStatus.inProgress:
                  c = Colors.blue; label = 'In Progress'; break;
                case ReportStatus.completed:
                  c = Colors.green; label = 'Resolved'; break;
                default:
                  c = Colors.orange; label = 'Pending';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image thumbnail
                      if (imgPath.isNotEmpty || imgUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _reportImage(
                            url: imgUrl,
                            localPath: imgPath,
                            height: 120,
                          ),
                        ),
                      if (imgPath.isNotEmpty || imgUrl.isNotEmpty)
                        const SizedBox(height: 10),

                      // Description
                      Text(d['description'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),

                      // Location
                      Row(children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(d['location'] ?? '',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 8),

                      // Status and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: c.withOpacity(0.15),
                                border: Border.all(color: c),
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == ReportStatus.completed
                                      ? Icons.check_circle
                                      : status == ReportStatus.inProgress
                                      ? Icons.autorenew
                                      : Icons.pending,
                                  size: 14,
                                  color: c,
                                ),
                                const SizedBox(width: 4),
                                Text(label, style: TextStyle(color: c,
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (ts != null)
                            Text(
                              '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REPORT PROBLEM PAGE — NO Firebase Storage
// Images saved locally; local path stored in Firestore
// ─────────────────────────────────────────────
class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});
  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  String _locationText = 'Fetching location...';
  double? _lat, _lng;
  XFile? _imageFile;
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  // ML Image Validation
  final ImageValidator _validator = ImageValidator();
  ValidationResult? _validationResult;
  bool _validating = false;

  @override
  void initState() { super.initState(); _getLocation(); }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationText = 'Location services disabled.'); return;
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        setState(() => _locationText = 'Location permission denied.'); return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _lat = pos.latitude; _lng = pos.longitude;
        _locationText =
        'Lat: ${pos.latitude.toStringAsFixed(5)},  '
            'Lng: ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (_) {
      setState(() => _locationText = 'Error fetching location.');
    }
  }

  Future<void> _pickImage() async {
    try {
      final f = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 75);
      if (f != null) {
        setState(() {
          _imageFile = f;
          _validationResult = null;
        });

        // Validate the image with ML
        await _validateImage(f.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  Future<void> _validateImage(String imagePath) async {
    setState(() => _validating = true);

    // Show loading message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('🤖 Validating image with AI...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      // Run ML validation
      final result = await _validator.validateImage(imagePath);

      setState(() {
        _validationResult = result;
        _validating = false;
      });

      // Show result to user
      if (mounted) {
        if (!result.isValid) {
          _showInvalidImageDialog(result);
        } else if (result.isHighConfidence) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✅ Valid hazard detected: ${result.category}\n'
                          'Confidence: ${result.confidence.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (result.needsReview) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('⚠️ Image will be reviewed by admin'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _validating = false);
      print('Validation error: $e');
    }
  }

  void _showInvalidImageDialog(ValidationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Invalid Image Detected')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detected:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.detectedObject,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please capture an image of a road hazard:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '✓ Potholes\n'
                  '✓ Cracked or damaged roads\n'
                  '✓ Debris on road\n'
                  '✓ Missing road signs\n'
                  '✓ Flooded areas',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Allow submission anyway
            },
            child: const Text('Submit Anyway',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _imageFile = null;
                _validationResult = null;
              });
              _pickImage(); // Retake photo
            },
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Retake Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture an image first.')));
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a description.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = _auth.currentUser!;
      final id   = DateTime.now().millisecondsSinceEpoch.toString();

      // Get user's display name from Firestore or Auth
      String userName = user.displayName ?? 'Unknown';
      try {
        final uDoc = await _firestore
            .collection('users').doc(user.uid).get();
        userName = uDoc.data()?['name'] ?? userName;
      } catch (_) {}

      // Save report to Firestore — image stored as LOCAL PATH only
      // (No Firebase Storage required)
      await _firestore.collection('reports').doc(id).set({
        'id':          id,
        'userId':      user.uid,
        'userName':    userName,
        'userEmail':   user.email ?? '',
        'location':    _locationText,
        'latitude':    _lat ?? 0.0,
        'longitude':   _lng ?? 0.0,
        'imageUrl':    '',            // no cloud storage
        'localPath':   _imageFile!.path,  // local device path
        'description': _descCtrl.text.trim(),
        'status':      'pending',
        'timestamp':   FieldValue.serverTimestamp(),

        // ML Validation Data (for admin review)
        'mlValidated': _validationResult?.isValid ?? false,
        'mlConfidence': _validationResult?.confidence ?? 0.0,
        'mlCategory': _validationResult?.category ?? 'Unknown',
        'mlDetectedObject': _validationResult?.detectedObject ?? 'Not validated',
        'needsReview': _validationResult?.needsReview ?? true,
      });

      if (!mounted) return;
      setState(() => _submitting = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Report Submitted!'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_imageFile!.path),
                    height: 120, width: double.infinity,
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Text('Location: $_locationText',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('Description: ${_descCtrl.text.trim()}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text('Admin has been notified 🙏',
                  style: TextStyle(color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() { _imageFile = null; _descCtrl.clear(); });
              },
              child: const Text('OK',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Submit failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Problem',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Location card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.location_on, color: Colors.orangeAccent),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Location',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_locationText,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                )),
                IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    onPressed: _getLocation),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Mini map
          if (_lat != null && _lng != null) ...[
            const Text('Location on Map',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              clipBehavior: Clip.hardEdge,
              child: FlutterMap(
                options: MapOptions(
                    initialCenter: LatLng(_lat!, _lng!), initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.raahnuma',
                  ),
                  MarkerLayer(markers: [
                    Marker(point: LatLng(_lat!, _lng!), width: 40, height: 40,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 36)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Image capture
          const Text('Capture Image',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_imageFile == null)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.orangeAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.orangeAccent),
                    SizedBox(height: 8),
                    Text('Tap to take a photo',
                        style: TextStyle(color: Colors.black45)),
                  ],
                ),
              ),
            )
          else
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_imageFile!.path),
                    height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _imageFile = null),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Positioned(bottom: 8, right: 8,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Retake',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 16),

          // Description
          const Text('Describe the Problem',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl, maxLines: 4,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'Describe the pothole or road hazard...',
              filled: true, fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(_submitting ? 'Submitting...' : 'Submit Report',
                  style: const TextStyle(fontSize: 17, color: Colors.white,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS PAGE
// ─────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notif = true, _loc = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    // Initialize dark mode state from the app's current theme
    _darkMode = _MyAppState.themeNotifier.value == ThemeMode.dark;
  }

  void _toggleDarkMode(bool value) {
    setState(() => _darkMode = value);
    _MyAppState.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? Colors.orange.shade900 : const Color(0xFFFFE0B2),
                child: const Icon(Icons.person, color: Colors.orange, size: 30),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.displayName ?? 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(user?.email ?? '',
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey,
                        fontSize: 13)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        _hdr('APPEARANCE'),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Enable dark theme'),
          value: _darkMode,
          activeColor: Colors.orangeAccent,
          secondary: Icon(
            _darkMode ? Icons.dark_mode : Icons.light_mode,
            color: Colors.orangeAccent,
          ),
          onChanged: _toggleDarkMode,
        ),
        const Divider(),

        _hdr('NOTIFICATIONS'),
        SwitchListTile(
          title: const Text('Enable Notifications'),
          subtitle: const Text('Receive nearby hazard alerts'),
          value: _notif,
          activeColor: Colors.orangeAccent,
          onChanged: (v) => setState(() => _notif = v),
        ),
        const Divider(),

        _hdr('LOCATION'),
        SwitchListTile(
          title: const Text('Enable Location'),
          subtitle: const Text('Required for accurate alerts'),
          value: _loc,
          activeColor: Colors.orangeAccent,
          onChanged: (v) => setState(() => _loc = v),
        ),
        const Divider(),

        _hdr('ABOUT'),
        const ListTile(
          leading: Icon(Icons.info_outline, color: Colors.orangeAccent),
          title: Text('App Version'),
          trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
        ),
        ListTile(
          leading: const Icon(Icons.code, color: Colors.orangeAccent),
          title: const Text('Build Number'),
          trailing: Text('1', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            await _auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/user_type');
          },
        ),
      ]),
    );
  }

  Widget _hdr(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
    child: Text(t, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.bold, color: Colors.orangeAccent,
        letterSpacing: 1.2)),
  );
}

// ─────────────────────────────────────────────
// CONTACT US PAGE
// ─────────────────────────────────────────────
class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contact_support,
                      size: 60,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We\'re here to help you make roads safer',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contact Cards
            _contactCard(
              icon: Icons.phone,
              title: 'Phone Number',
              content: '8294424241',
              color: Colors.green,
              onTap: () {
                // In a real app, this would open the phone dialer
                // You can use url_launcher package: launch('tel:8294424241')
              },
            ),
            const SizedBox(height: 16),

            _contactCard(
              icon: Icons.email,
              title: 'Email Address',
              content: 'admin@raahnuma.app',
              color: Colors.blue,
              onTap: () {
                // In a real app, this would open email client
                // You can use url_launcher package: launch('mailto:admin@raahnuma.app')
              },
            ),
            const SizedBox(height: 16),

            _contactCard(
              icon: Icons.location_on,
              title: 'Office Address',
              content: 'Room No. 220 B7\nGHS Hostel',
              color: Colors.red,
              onTap: () {
                // In a real app, this could open maps
              },
            ),
            const SizedBox(height: 32),

            // Working Hours
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      Text(
                        'Support Hours',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Monday - Friday: 9:00 AM - 6:00 PM\nSaturday: 10:00 AM - 4:00 PM\nSunday: Closed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Message Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.message, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Need immediate assistance?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For urgent road hazards, please submit a report through the app for fastest response.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/report');
                    },
                    icon: const Icon(Icons.report, color: Colors.orange),
                    label: const Text(
                      'Report Problem',
                      style: TextStyle(color: Colors.orange),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FAQs PAGE
// ─────────────────────────────────────────────
class FAQsPage extends StatelessWidget {
  const FAQsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.help_outline, size: 50, color: Colors.orangeAccent),
                SizedBox(height: 12),
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Find answers to common questions about राहनुमा',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // FAQ Items
          _faqItem(
            question: 'What is राहनुमा?',
            answer:
            'राहनुमा (Raahnuma) is your guide to safer streets. It\'s a community-driven app that allows users to report road hazards like potholes, damaged roads, and other infrastructure issues to help authorities address them quickly.',
            icon: Icons.info_outline,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),

          _faqItem(
            question: 'How do I report a road problem?',
            answer:
            'Simply tap on "Report a Problem" from the menu, capture a photo of the hazard, add a description, and submit. Your location will be automatically captured to help authorities locate the issue precisely.',
            icon: Icons.report_problem,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),

          _faqItem(
            question: 'Can I track the status of my reports?',
            answer:
            'Yes! Go to "My Reports" from the menu to see all your submitted reports. Each report shows its current status: Pending (under review), In Progress (being fixed), or Resolved (completed).',
            icon: Icons.track_changes,
            color: Colors.green,
          ),
          const SizedBox(height: 12),

          _faqItem(
            question: 'Why do I need to enable location services?',
            answer:
            'Location services help us pinpoint the exact location of road hazards you report. This ensures that authorities can quickly find and fix the problem. Your location is only used when you submit a report and is not tracked continuously.',
            icon: Icons.location_on,
            color: Colors.red,
          ),
          const SizedBox(height: 12),

          _faqItem(
            question: 'How long does it take to fix reported issues?',
            answer:
            'The response time depends on the severity of the issue and availability of resources. Once you submit a report, it goes to the admin dashboard where it\'s prioritized. You\'ll receive status updates as your report progresses from Pending to In Progress to Resolved.',
            icon: Icons.access_time,
            color: Colors.purple,
          ),
          const SizedBox(height: 24),

          // Contact Support Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent,
                    color: Colors.white, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Still have questions?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Our support team is here to help',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/contact');
                  },
                  icon: const Icon(Icons.contact_support, color: Colors.orange),
                  label: const Text(
                    'Contact Us',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqItem({
    required String question,
    required String answer,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _filter = 'All';

  Stream<QuerySnapshot> get _stream {
    final col = _firestore.collection('reports')
        .orderBy('timestamp', descending: true);
    switch (_filter) {
      case 'Pending':     return col.where('status', isEqualTo: 'pending').snapshots();
      case 'In Progress': return col.where('status', isEqualTo: 'inProgress').snapshots();
      case 'Completed':   return col.where('status', isEqualTo: 'completed').snapshots();
      default:            return col.snapshots();
    }
  }

  Future<void> _setStatus(String docId, String status) async =>
      _firestore.collection('reports').doc(docId).update({'status': status});

  Future<void> _delete(String docId) async =>
      _firestore.collection('reports').doc(docId).delete();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/user_type'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Summary counts always from ALL reports
        stream: _firestore.collection('reports').snapshots(),
        builder: (ctx, allSnap) {
          final all     = allSnap.data?.docs ?? [];
          final pending = all.where((d) =>
          (d.data() as Map)['status'] == 'pending').length;
          final inProg  = all.where((d) =>
          (d.data() as Map)['status'] == 'inProgress').length;
          final done    = all.where((d) =>
          (d.data() as Map)['status'] == 'completed').length;

          return Column(children: [
            // Summary
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                _sum('Total', all.length.toString(), Colors.blueGrey),
                const SizedBox(width: 6),
                _sum('Pending', pending.toString(), Colors.orange),
                const SizedBox(width: 6),
                _sum('In Progress', inProg.toString(), Colors.blue),
                const SizedBox(width: 6),
                _sum('Done', done.toString(), Colors.green),
              ]),
            ),

            // Filter chips
            Container(
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: ['All','Pending','In Progress','Completed'].map((f) {
                    final sel = _filter == f;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? Colors.grey[700] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel
                              ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        child: Text(f, style: TextStyle(
                            color: sel ? Colors.white : Colors.black54,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Report list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No reports found.',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                      ],
                    ));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _card(docs[i]),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _sum(String label, String count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(count, style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ]),
    ),
  );

  Widget _card(DocumentSnapshot doc) {
    final d      = doc.data() as Map<String, dynamic>;
    final docId  = doc.id;
    final status = statusFromString(d['status'] ?? 'pending');
    final imgUrl  = d['imageUrl']  as String? ?? '';
    final imgPath = d['localPath'] as String? ?? '';
    final ts      = (d['timestamp'] as Timestamp?)?.toDate();

    // ML Validation data
    final mlValidated = d['mlValidated'] as bool? ?? false;
    final mlConfidence = d['mlConfidence'] as double? ?? 0.0;
    final mlCategory = d['mlCategory'] as String? ?? '';
    final needsReview = d['needsReview'] as bool? ?? false;

    Color sc; IconData si; String sl;
    switch (status) {
      case ReportStatus.inProgress:
        sc = Colors.blue; si = Icons.autorenew; sl = 'In Progress'; break;
      case ReportStatus.completed:
        sc = Colors.green; si = Icons.check_circle; sl = 'Completed'; break;
      default:
        sc = Colors.orange; si = Icons.pending; sl = 'Pending';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // User + status
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.person, color: Colors.orange, size: 18)),
            const SizedBox(width: 8),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['userName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(d['userEmail'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.12),
                border: Border.all(color: sc),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(si, color: sc, size: 14),
                const SizedBox(width: 4),
                Text(sl, style: TextStyle(color: sc, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),

          // ML Validation Badges
          if (mlValidated && mlConfidence >= 70)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '🤖 AI Verified: $mlCategory (${mlConfidence.toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (needsReview && !mlValidated)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '⚠️ Needs Manual Review (${mlConfidence.toStringAsFixed(0)}% confidence)',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (!mlValidated && !needsReview && mlConfidence > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '❌ Invalid Image - Requires Review (${mlConfidence.toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Image — local file (no cloud storage needed)
          _reportImage(url: imgUrl, localPath: imgPath, height: 160),
          const SizedBox(height: 10),

          Text(d['description'] ?? '',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),

          Row(children: [
            const Icon(Icons.location_on, color: Colors.orangeAccent, size: 16),
            const SizedBox(width: 4),
            Expanded(child: Text(d['location'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.black54))),
          ]),
          if (ts != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${ts.day}/${ts.month}/${ts.year}  '
                    '${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ]),
          ],
          const SizedBox(height: 12),

          // Action buttons
          Row(children: [
            if (status == ReportStatus.pending)
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.autorenew, size: 15, color: Colors.blue),
                label: const Text('In Progress',
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue)),
                onPressed: () => _setStatus(docId, 'inProgress'),
              )),
            if (status == ReportStatus.inProgress)
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.check_circle, size: 15, color: Colors.green),
                label: const Text('Completed',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green)),
                onPressed: () => _setStatus(docId, 'completed'),
              )),
            if (status == ReportStatus.completed)
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.undo, size: 15, color: Colors.orange),
                label: const Text('Reopen',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange)),
                onPressed: () => _setStatus(docId, 'pending'),
              )),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete, size: 15, color: Colors.red),
              label: const Text('Delete',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red)),
              onPressed: () => _delete(docId),
            ),
          ]),
        ]),
      ),
    );
  }
}