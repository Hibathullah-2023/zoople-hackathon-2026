import 'package:flutter/material.dart';

/// Provides global text scaling controls for accessibility
class AccessibilityService extends ChangeNotifier {
  double _textScale = 1.0;

  double get textScale => _textScale;

  void increaseTextSize() {
    if (_textScale < 1.4) {
      _textScale += 0.1;
      notifyListeners();
    }
  }

  void decreaseTextSize() {
    if (_textScale > 0.8) {
      _textScale -= 0.1;
      notifyListeners();
    }
  }

  void resetTextScale() {
    _textScale = 1.0;
    notifyListeners();
  }
}
