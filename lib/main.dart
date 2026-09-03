import 'package:flutter/material.dart';

import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(builder: () => const JellyfinityApp());
}

class JellyfinityApp extends StatelessWidget {
  const JellyfinityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfinity',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DevelopmentHomePage(),
    );
  }
}

class DevelopmentHomePage extends StatelessWidget {
  const DevelopmentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Jellyfinity'),
      ),
      body: Center(
        child: Text(
          'Development environment ready',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
