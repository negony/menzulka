import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionType { none, wifi, mobile, ethernet, other }

class ConnectionInfo {
  final ConnectionType type;
  final bool isMetered;
  const ConnectionInfo({required this.type, this.isMetered = false});
  bool get isConnected => type != ConnectionType.none;
  bool get isWifi => type == ConnectionType.wifi;
  bool get isMobile => type == ConnectionType.mobile;
}

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  Future<ConnectionInfo> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    final type = _mapResult(result);
    return ConnectionInfo(type: type, isMetered: type == ConnectionType.mobile);
  }

  Stream<ConnectionInfo> get onConnectionChanged {
    return _connectivity.onConnectivityChanged.map((result) {
      final type = _mapResult(result);
      return ConnectionInfo(
          type: type, isMetered: type == ConnectionType.mobile);
    });
  }

  ConnectionType _mapResult(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectionType.none;
    }
    if (results.contains(ConnectivityResult.wifi)) return ConnectionType.wifi;
    if (results.contains(ConnectivityResult.mobile)) {
      return ConnectionType.mobile;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return ConnectionType.ethernet;
    }
    return ConnectionType.other;
  }
}
