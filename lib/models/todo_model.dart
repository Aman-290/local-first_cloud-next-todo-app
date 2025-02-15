import 'package:hive/hive.dart';

part 'todo_model.g.dart';

@HiveType(typeId: 0)
class Todo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime lastUpdated;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      title: map['title'],
      isCompleted: map['isCompleted'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }
}
