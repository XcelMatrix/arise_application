import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// true = a network is available.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit() : super(true) {
    Connectivity().checkConnectivity().then(_set);
    _sub = Connectivity().onConnectivityChanged.listen(_set);
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void _set(List<ConnectivityResult> r) {
    final online = r.any((e) => e != ConnectivityResult.none);
    if (!isClosed && online != state) emit(online);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
