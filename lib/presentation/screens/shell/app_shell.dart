import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import '../../../config/service_locator.dart';
import '../../../stores/app_store.dart';
import '../../../stores/material_store.dart';
import '../home/home_tab.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_history_screen.dart';
import '../materials/materials_tab.dart';
import '../settings/settings_screen.dart';
import '../../widgets/task_queue/task_queue_fab.dart';

/// InheritedWidget to allow children to switch tabs and open chat
class AppShellController extends InheritedWidget {
  final void Function(int index) switchTab;
  final void Function() openChat;

  const AppShellController({
    super.key,
    required this.switchTab,
    required this.openChat,
    required super.child,
  });

  static AppShellController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellController>();
  }

  @override
  bool updateShouldNotify(AppShellController oldWidget) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Track actual page index (0-3, excluding chat which is center button)
  int _currentIndex = 0;
  final _pageController = PageController();
  final appStore = getIt<AppStore>();
  final materialStore = getIt<MaterialStore>();

  // Pages (5 items for fixedCircle, but Chat opens full-screen)
  // Index mapping: 0=Home, 1=History, 2=Chat(full-screen), 3=Library, 4=Settings
  final List<Widget> _pages = const [
    HomeTab(),         // nav index 0
    ChatHistoryScreen(), // nav index 1
    SizedBox(),        // nav index 2 (Chat - placeholder, opens full-screen)
    MaterialsTab(),    // nav index 3
    SettingsScreen(),  // nav index 4
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int navIndex) {
    // Center button (index 2) opens full-screen chat
    if (navIndex == 2) {
      _openChat();
      return;
    }
    
    setState(() => _currentIndex = navIndex);
    _pageController.jumpToPage(navIndex);
  }

  // Public method for children to switch tabs
  void switchTab(int navIndex) {
    _onTabSelected(navIndex);
  }

  void _openChat({int? conversationId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: conversationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return AppShellController(
      switchTab: switchTab,
      openChat: _openChat,
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _pages,
            ),
            // Draggable task queue FAB
            const TaskQueueFAB(),
          ],
        ),
        bottomNavigationBar: ConvexAppBar(
          key: ValueKey(_currentIndex),
          style: TabStyle.fixedCircle,
          backgroundColor: isDark ? colorScheme.surface : colorScheme.primary,
          activeColor: isDark ? colorScheme.primary : Colors.white,
          color: isDark ? colorScheme.onSurface.withOpacity(0.6) : Colors.white70,
          height: 60,
          curveSize: 80,
          top: -28,
          items: const [
            TabItem(icon: Icons.home_rounded, title: 'Home'),
            TabItem(icon: Icons.history_rounded, title: 'History'),
            TabItem(icon: Icons.add_comment_rounded, title: 'New Chat'),  // Center - new chat
            TabItem(icon: Icons.library_books_rounded, title: 'Library'),
            TabItem(icon: Icons.settings_rounded, title: 'Settings'),
          ],
          initialActiveIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}

