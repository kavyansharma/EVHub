// ignore_for_file: avoid_print
import 'package:url_launcher/url_launcher.dart';

/// Native launcher for non-web platforms.
bool openWebWindow(String url) {
  try {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    print("WINDOW OPEN RESULT: MOBILE LAUNCH SUCCESS");
    return true;
  } catch (e) {
    print("WINDOW OPEN RESULT: EXCEPTION ($e)");
    return false;
  }
}


