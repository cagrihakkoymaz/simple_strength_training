import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database.dart';
import 'db/repository.dart';
import 'state/app_state.dart';
import 'state/rest_alerts.dart';
import 'state/settings.dart';
import 'ui/history_screen.dart';
import 'ui/home_screen.dart';
import 'ui/progress_screen.dart';
import 'ui/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings(await SharedPreferences.getInstance());
  final appState = AppState(Repository(await openAppDatabase()));
  await appState.load();
  final alerts = NotificationRestAlerts(settings);
  await alerts.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: appState),
        Provider<RestAlerts>.value(value: alerts),
      ],
      child: const StrengthApp(),
    ),
  );
}

class StrengthApp extends StatelessWidget {
  const StrengthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strength Training',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6CCB3E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _pages = [HomeScreen(), HistoryScreen(), ProgressScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
