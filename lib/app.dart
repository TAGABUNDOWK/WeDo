import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/group/group_info_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeDo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
      routes: {
        '/group-info': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return GroupInfoScreen(groupId: args as String? ?? '');
        },
      },
    );
  }
}