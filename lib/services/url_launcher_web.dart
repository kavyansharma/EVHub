// ignore_for_file: avoid_print
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Directly redirects the current browser tab to [url] using html.window.location.href.
/// Bypasses all browser popup blockers.
bool openWebWindow(String url) {
  try {
    print("[EVHUB_NAV_RUNTIME] Redirecting current browser tab to: $url");
    html.window.location.href = url;
    print("WINDOW OPEN RESULT: SAME TAB REDIRECT SUCCESS");
    return true;
  } catch (e) {
    print("WINDOW OPEN RESULT: EXCEPTION ($e)");
    return false;
  }
}



