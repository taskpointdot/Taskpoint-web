import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/admin_auth_service.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A build/layout error inside a widget used to leave the whole page blank
  // (release web builds don't paint the debug "red screen"), which is exactly
  // what "shows nothing after login" was. Render a readable error card
  // instead of a dead white canvas so a failure is at least visible and
  // reportable rather than silent.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFDECEA),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong rendering this screen.\n\n${details.exceptionAsString()}',
            style: const TextStyle(color: Color(0xFF93000A), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Fixes "Failed to get document because the client is offline" on web.
  //
  // Firestore's web SDK talks over a WebChannel streaming connection. Plenty
  // of ordinary setups break that stream while leaving normal HTTPS working
  // — antivirus TLS inspection, corporate proxies, VPNs, some extensions.
  // When the stream can't be established the SDK doesn't report a network
  // error: it declares itself offline, serves reads from cache, and a `get()`
  // with an empty cache throws that confusing "client is offline" message
  // even though the network is fine.
  //
  // Auto-detect probes the stream and transparently falls back to long
  // polling when it's blocked. Persistence is off because this is a
  // moderation console: an admin must see the live queue, never a stale
  // cached copy of it, and the empty-cache path is what produced the
  // misleading error above.
  FirebaseFirestore.instance.settings = const Settings(
    webExperimentalAutoDetectLongPolling: true,
    persistenceEnabled: false,
  );

  runApp(const TaskPointAdminApp());
}

class TaskPointAdminApp extends StatelessWidget {
  const TaskPointAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskPoint Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

/// Switches between the login screen and the dashboard based on Firebase
/// Auth state, re-checking the `admins` allow-list on every app load (e.g.
/// a refresh) so a revoked admin gets bounced back to login automatically.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _authService = AdminAuthService();

  // Cache the profile lookup per signed-in UID. The previous version called
  // _authService.loadProfileForCurrentUser() directly inside `future:`,
  // which creates a BRAND NEW Future on every rebuild — FutureBuilder never
  // gets a chance to settle, and any error it hits gets silently discarded
  // on the next rebuild instead of ever reaching the screen.
  String? _profileFutureForUid;
  Future<AdminProfile?>? _profileFuture;

  void _ensureProfileFuture(User? user) {
    if (user == null) {
      _profileFutureForUid = null;
      _profileFuture = null;
      return;
    }
    if (_profileFutureForUid != user.uid) {
      _profileFutureForUid = user.uid;
      _profileFuture = _authService.loadProfileForCurrentUser();
    }
  }

  void _retryProfileLookup() {
    setState(() {
      _profileFuture = _authService.loadProfileForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        _ensureProfileFuture(user);

        if (user == null || _profileFuture == null) {
          return AdminLoginScreen(authService: _authService);
        }

        return FutureBuilder<AdminProfile?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.hasError) {
              // Previously this branch didn't exist — an error here (e.g.
              // Firestore permission-denied because rules aren't published
              // yet) fell through to `profile == null` below with zero
              // explanation, which looked exactly like "login just doesn't
              // go anywhere." Now it's shown directly.
              return _AdminAccessErrorScreen(
                message: profileSnapshot.error.toString(),
                uid: _authService.currentUser?.uid,
                email: _authService.currentUser?.email,
                onRetry: _retryProfileLookup,
                onSignOut: () => _authService.signOut(),
              );
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              // Not an admin — loadProfileForCurrentUser already signed
              // them out, so the stream above will fire again with
              // user == null and land back on the login screen.
              return AdminLoginScreen(authService: _authService);
            }
            return AdminHomeScreen(profile: profile, authService: _authService);
          },
        );
      },
    );
  }
}

class _AdminAccessErrorScreen extends StatelessWidget {
  final String message;
  final String? uid;
  final String? email;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;
  const _AdminAccessErrorScreen({
    required this.message,
    this.uid,
    this.email,
    required this.onRetry,
    required this.onSignOut,
  });

  /// The "client is offline" case is worth calling out separately: it reads
  /// like a dead network, but it almost always means Firestore's WebChannel
  /// stream was blocked while ordinary HTTPS still works, so telling the
  /// operator to "check your internet" sends them the wrong way entirely.
  bool get _isOfflineError => message.toLowerCase().contains('offline');

  bool get _isPermissionError =>
      message.contains('permission-denied') || message.contains('PERMISSION_DENIED');

  String get _guidance {
    if (_isOfflineError) {
      return 'Firestore could not open its live connection. This is usually antivirus TLS '
          'inspection, a VPN/proxy, or a browser extension blocking the streaming channel '
          '— not a dead internet connection.\n\n'
          'Try: reload the page; disable ad-block/antivirus web shields for localhost; '
          'or open the app in a normal Chrome window.';
    }
    if (_isPermissionError) {
      return 'Firestore denied the read, which means one of these two one-time '
          'setup steps is still missing in your Firebase project '
          '(taskpoint-8aba0):\n\n'
          '1.  Publish the security rules. In the Firebase console open '
          'Firestore Database → Rules, paste the contents of '
          'taskpoint/firestore.rules over what is there, and press Publish. '
          '(Or, if you have the CLI: firebase deploy --only firestore:rules '
          'from the taskpoint/ folder.)\n\n'
          '2.  Add this account to the admins allow-list. In Firestore Database '
          '→ Data, create a document at  admins / <your UID below>  with two '
          'fields:  name (string)  and  role (string, e.g. "super_admin").\n\n'
          'Then press Retry.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Was an unscrollable Column, so on a short window the rows painted
      // over one another instead of scrolling.
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  'Could not load admin access',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(_guidance, textAlign: TextAlign.left, style: const TextStyle(fontSize: 13, height: 1.6)),
                // The signed-in account's UID, needed verbatim to create the
                // admins/{uid} document in step 2. Shown selectable so it can
                // be copied straight into the Firebase console.
                if (_isPermissionError && uid != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (email != null)
                          Text('Signed in as: $email',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 4),
                        const Text('Your UID (copy this):',
                            style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 2),
                        SelectableText(
                          uid!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isOfflineError || _isPermissionError) ...[
                  const SizedBox(height: 12),
                  // Keep the raw text available — the underlying message is
                  // what someone debugging actually needs.
                  SelectableText(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
