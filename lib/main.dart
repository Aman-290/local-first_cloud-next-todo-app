import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:todo/models/todo_model.dart';
import 'package:todo/providers/auth_provider.dart';
import 'package:todo/providers/todo_provider.dart';
import 'package:todo/screens/auth_screen.dart';
import 'package:todo/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  Hive.registerAdapter(TodoAdapter());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Todo App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return authProvider.user == null ? AuthScreen() : HomeScreen();
          },
        ),
      ),
    );
  }
}
