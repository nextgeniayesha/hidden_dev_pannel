import 'package:flutter/foundation.dart';

import 'models/captured_http_request.dart';

/// Stores captured HTTP traffic for the developer panel (replaces third-party
/// inspector singletons).
final class DevPanelInspector extends ChangeNotifier {
  DevPanelInspector._();

  static final DevPanelInspector _instance = DevPanelInspector._();

  /// Singleton compatible with `DevPanelInspector()` call sites.
  factory DevPanelInspector() => _instance;

  static const int maxRecords = 800;

  final List<CapturedHttpRequest> _requests = <CapturedHttpRequest>[];

  List<CapturedHttpRequest> get requestsList =>
      List<CapturedHttpRequest>.unmodifiable(_requests);

  void addNewRequest(CapturedHttpRequest request) {
    _requests.insert(0, request);
    if (_requests.length > maxRecords) {
      _requests.removeRange(maxRecords, _requests.length);
    }
    notifyListeners();
  }

  void clearAllRequests() {
    _requests.clear();
    notifyListeners();
  }
}
