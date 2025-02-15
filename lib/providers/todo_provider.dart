import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:todo/models/todo_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class TodoProvider with ChangeNotifier {
  Box<Todo>? _todoBox;
  Box<Map<String, dynamic>>? _pendingOpsBox;
  String? _uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
  StreamSubscription? _firestoreSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  List<Todo> get todos => _todoBox?.values.toList() ?? [];
  bool get hasPendingOperations => _pendingOpsBox?.isNotEmpty ?? false;

  Future<void> loadTodos(String uid) async {
    _uid = uid;
    if (!Hive.isBoxOpen(uid)) {
      _todoBox = await Hive.openBox<Todo>(uid);
    } else {
      _todoBox = Hive.box<Todo>(uid);
    }
    await _initPendingOpsBox();
    _startMonitoringConnectivity();
    _startFirestoreSync(uid);
    notifyListeners();
  }

  Future<void> _initPendingOpsBox() async {
    if (!Hive.isBoxOpen('pending_ops_$_uid')) {
      _pendingOpsBox = await Hive.openBox('pending_ops_$_uid');
    } else {
      _pendingOpsBox = Hive.box('pending_ops_$_uid');
    }
  }

  void _startMonitoringConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _retryPendingOperations();
      }
    });
  }

  Future<void> _startFirestoreSync(String uid) async {
    await _initialSyncWithFirestore(uid);
    _firestoreSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('todos')
        .snapshots()
        .listen(_handleFirestoreChanges);
  }

  Future<void> _initialSyncWithFirestore(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('todos')
          .get();
      final localTodos = _todoBox!.values.toList();

      // Merge Firestore todos to Hive
      for (final doc in snapshot.docs) {
        final remoteTodo = Todo.fromMap(doc.data());
        final localTodo = _todoBox!.get(remoteTodo.id);
        if (localTodo == null ||
            remoteTodo.lastUpdated.isAfter(localTodo.lastUpdated)) {
          _todoBox!.put(remoteTodo.id, remoteTodo);
        }
      }

      // Push local todos to Firestore if newer
      for (final localTodo in localTodos) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('todos')
            .doc(localTodo.id);
        final doc = await docRef.get();
        if (!doc.exists ||
            localTodo.lastUpdated
                .isAfter((doc.data()!['lastUpdated'] as Timestamp).toDate())) {
          await docRef.set(localTodo.toMap());
        }
      }
    } catch (e) {
      // Handle initial sync error
    }
  }

  void _handleFirestoreChanges(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      final remoteTodo =
          Todo.fromMap(change.doc.data() as Map<String, dynamic>);
      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          final localTodo = _todoBox!.get(remoteTodo.id);
          if (localTodo == null ||
              remoteTodo.lastUpdated.isAfter(localTodo.lastUpdated)) {
            _todoBox!.put(remoteTodo.id, remoteTodo);
          }
          break;
        case DocumentChangeType.removed:
          _todoBox!.delete(remoteTodo.id);
          break;
      }
    }
    notifyListeners();
  }

  void addTodo(String title) {
    final newTodo = Todo(
      id: _uuid.v4(),
      title: title,
      isCompleted: false,
      lastUpdated: DateTime.now(),
    );
    _todoBox!.put(newTodo.id, newTodo);
    _pushTodoToFirestore(newTodo);
    notifyListeners();
  }

  void toggleTodo(String id) {
    final todo = _todoBox!.get(id);
    if (todo != null) {
      todo.isCompleted = !todo.isCompleted;
      todo.lastUpdated = DateTime.now();
      _todoBox!.put(id, todo);
      _pushTodoToFirestore(todo);
      notifyListeners();
    }
  }

  void deleteTodo(String id) {
    _todoBox!.delete(id);
    _deleteTodoFromFirestore(id);
    notifyListeners();
  }

  Future<void> _pushTodoToFirestore(Todo todo) async {
    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('todos')
          .doc(todo.id)
          .set(todo.toMap());
    } catch (e) {
      _addToPendingOps('update', todo: todo);
    }
  }

  Future<void> _deleteTodoFromFirestore(String id) async {
    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('todos')
          .doc(id)
          .delete();
    } catch (e) {
      _addToPendingOps('delete', id: id);
    }
  }

  void _addToPendingOps(String action, {Todo? todo, String? id}) {
    final op = {
      'action': action,
      'timestamp': DateTime.now(),
      if (todo != null) 'todo': todo.toMap(),
      if (id != null) 'id': id,
    };
    _pendingOpsBox!.add(op);
  }

  Future<void> _retryPendingOperations() async {
    final ops = _pendingOpsBox!.toMap();
    for (final entry in ops.entries) {
      final op = entry.value;
      final key = entry.key;
      try {
        switch (op['action']) {
          case 'update':
            final todo = Todo.fromMap(op['todo']);
            await _pushTodoToFirestore(todo);
            await _pendingOpsBox!.delete(key);
            break;
          case 'delete':
            await _deleteTodoFromFirestore(op['id']);
            await _pendingOpsBox!.delete(key);
            break;
        }
      } catch (e) {
        // Retry failed, keep in queue
      }
    }
  }

  Future<void> syncPendingOperations() async {
    await _retryPendingOperations();
  }

  Future<void> closeBoxes() async {
    await _todoBox?.close();
    await _pendingOpsBox?.close();
    _todoBox = null;
    _pendingOpsBox = null;
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
