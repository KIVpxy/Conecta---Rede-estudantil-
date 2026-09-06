import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Estado de autenticação simplificado.
/// A feature de auth (repositórios) alimenta este estado.
class AuthState extends ChangeNotifier {
  AuthState({bool loggedIn = false}) : _loggedIn = loggedIn;

  bool _loggedIn;

  bool get loggedIn => _loggedIn;

  void signIn() {
    _loggedIn = true;
    notifyListeners();
  }

  void signOut() {
    _loggedIn = false;
    notifyListeners();
  }
}

final authStateProvider =
    ChangeNotifierProvider<AuthState>((ref) => AuthState());
