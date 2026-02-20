import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../core/app_preferences.dart';
import '../../services/network/backend_client.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Sign-in aborted');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Platform-aware Google sign-in.
  /// - Android/iOS: native `google_sign_in` flow (unchanged).
  /// - Windows/macOS/Linux: uses Firebase's desktop provider flow which opens
  ///   the system browser and returns to the app.
  static Future<void> signInWithGoogleUniversal() async {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile) {
      await signInWithGoogle();
      return;
    }
    await _desktopGoogleOAuthAndSignIn();
  }

  // Desktop browser-based OAuth (PKCE) for Google, then sign into Firebase.
  static Future<void> _desktopGoogleOAuthAndSignIn() async {
    // Google OAuth Desktop client ID
    const clientId =
        '574158051421-fql2c3m34qlgvock6a6b889k2lrlmveh.apps.googleusercontent.com';

    // Start a local HTTP server to receive the OAuth redirect.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    // Google desktop clients expect a loopback redirect with no fixed path.
    // Use root (/) to avoid client_secret requirements on Web clients.
    // Use loopback redirect (no path) per Google installed-app guidance.
    final redirectUri = 'http://localhost:$port';

    // PKCE code verifier/challenge
    final verifier = _randomUrlSafeString(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');

    final authUri = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth')
        .replace(queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    if (!await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open browser for OAuth');
    }

    // Wait for the OAuth redirect.
    String? authCode;
    await for (final req in server) {
      if (req.uri.path == '/' || req.uri.path == '/callback') {
        authCode = req.uri.queryParameters['code'];
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'text/html; charset=utf-8')
          ..write(
              '<html><body><h2>Sign-in complete. You may close this window.</h2></body></html>');
        await req.response.close();
        await server.close(force: true);
        break;
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    }
    if (authCode == null) {
      throw Exception('No authorization code received');
    }

    // Exchange the code for tokens.
    final tokenReq = await HttpClient()
        .postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
    final body = {
      'code': authCode,
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
      'code_verifier': verifier,
    };
    // Dev-only fallback: if an environment variable GOOGLE_CLIENT_SECRET is set,
    // include it to work around misclassified clients. Do NOT ship secrets.
    final envSecret = Platform.environment['GOOGLE_CLIENT_SECRET'];
    if (envSecret != null && envSecret.isNotEmpty) {
      body['client_secret'] = envSecret;
    }
    tokenReq.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    tokenReq.write(body.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&'));
    final tokenResp = await tokenReq.close();
    final tokenRaw = await utf8.decodeStream(tokenResp);
    final tokenJson = jsonDecode(tokenRaw) as Map;
    final idToken = tokenJson['id_token'] as String?;
    final accessToken = tokenJson['access_token'] as String?;
    if (idToken == null || accessToken == null) {
      throw Exception('Token exchange failed: $tokenJson');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    await _persistToken(userCredential.user);
  }

  static Future<void> _persistToken(User? user) async {
    if (user == null) return;
    // Register device to get long-lived secret (also stores fresh Firebase token)
    await registerDevice(user);
  }

  static Future<void> registerDevice(User user) async {
    try {
      final token = await user.getIdToken();
      if (token == null) return;

      final appPrefs = AppPreferences.instance;
      await appPrefs.ensureInitialized();
      final deviceId = await appPrefs.getOrCreateDeviceId();

      debugPrint('Registering device with backend...');
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/register-device'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': kBackendApiKey,
        },
        body: jsonEncode({
          'device_id': deviceId,
          'firebase_token': token,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final secret = data['device_secret'] as String?;
        if (secret != null) {
          await appPrefs.setDeviceSecret(secret);
          debugPrint('Device registered successfully. Secret saved.');
        }
      } else {
        debugPrint('Failed to register device: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  static String _randomUrlSafeString(int length) {
    final rnd = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }
}
