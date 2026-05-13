import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'screens/task_list_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarefas',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const TaskListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
