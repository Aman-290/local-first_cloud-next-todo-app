import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/providers/auth_provider.dart';
import 'package:todo/providers/todo_provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    todoProvider.loadTodos(authProvider.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Todo List'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              if (todoProvider.hasPendingOperations) {
                final connectivityResult =
                    await Connectivity().checkConnectivity();
                if (connectivityResult == ConnectivityResult.none) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Warning'),
                      content: Text(
                          'You have unsynced data. Syncing requires an active internet connection.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
              }

              await todoProvider.syncPendingOperations();
              await todoProvider.closeBoxes(); // Close boxes before logout
              final error = await authProvider.logout();
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: todoProvider.todos.length,
        itemBuilder: (context, index) {
          final todo = todoProvider.todos[index];
          return ListTile(
            title: Text(
              todo.title,
              style: TextStyle(
                decoration:
                    todo.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            trailing: Checkbox(
              value: todo.isCompleted,
              onChanged: (_) => todoProvider.toggleTodo(todo.id),
            ),
            onLongPress: () => todoProvider.deleteTodo(todo.id),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              final TextEditingController _controller = TextEditingController();
              return AlertDialog(
                title: Text('Add New Task'),
                content: TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: 'Enter task title'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        todoProvider.addTodo(_controller.text);
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Add'),
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
