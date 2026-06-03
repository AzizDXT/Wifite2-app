import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() => runApp(const OneShotApp());

class OneShotApp extends StatelessWidget {
  const OneShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneShot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
