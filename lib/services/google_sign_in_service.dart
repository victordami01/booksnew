import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '949555798833-mt60rdjg14p94360mcf2efda0dcmrp61.apps.googleusercontent.com'
        : null, // Use null for non-web platforms (Android/iOS)
    scopes: ['email', 'profile'], // Default scopes for Google Sign-In
  );

  static GoogleSignIn get instance => _googleSignIn;
}