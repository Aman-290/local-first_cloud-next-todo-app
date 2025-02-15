import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> logout() async {
    try {
      await _auth.signOut();
      await Hive.deleteBoxFromDisk(_user!.uid);
      if (Hive.isBoxOpen('pending_ops_${_user!.uid}')) {
        await Hive.box('pending_ops_${_user!.uid}').close();
        await Hive.deleteBoxFromDisk('pending_ops_${_user!.uid}');
      }
      return null;
    } catch (e) {
      return 'Error logging out: ${e.toString()}';
    }
  }
}
