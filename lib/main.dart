import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/group/create_group_screen.dart';
import 'screens/group/group_info_screen.dart';
import 'screens/group/message_search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeDo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
      routes: {
        '/home': (context) => const HomePage(),
        '/create-group': (context) => const CreateGroupScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/group-info') {
          final groupId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => GroupInfoScreen(groupId: groupId),
          );
        }
        if (settings.name == '/search-messages') {
          final groupId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => MessageSearchScreen(groupId: groupId),
          );
        }
        return null;
      },
    );
  }
}
