// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Native JavaScript web window launcher using dart:html for Flutter Web.
bool openWebWindow(String url) {
  try {
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
