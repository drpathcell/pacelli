import 'package:flutter/material.dart';

import '../../core/utils/extensions.dart';

/// Main shell with bottom navigation bar.
///
/// Wraps the Home, Tasks, Calendar and Settings tabs using GoRouter's
/// ShellRoute. Applies a directional slide transition that matches the
/// tab position — sliding in from right for higher-index tabs and from
/// left for lower-index tabs. Only one page is ever in the widget tree
/// at a time, avoiding GlobalKey conflicts.
class MainShell extends StatefulWidget {
  final int currentIndex;
  final Widget child;
  final ValueChanged<int> onTabChanged;

  const MainShell({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = _buildSlideAnimation(forward: true);
    // Start fully visible (no animation on first load).
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<Offset> _buildSlideAnimation({required bool forward}) {
    return Tween<Offset>(
      begin: Offset(forward ? 1.0 : -1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final goingForward = widget.currentIndex > oldWidget.currentIndex;
      _previousIndex = oldWidget.currentIndex;
      _slideAnimation = _buildSlideAnimation(forward: goingForward);
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: widget.onTabChanged,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: context.l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.check_circle_outline),
            selectedIcon: const Icon(Icons.check_circle_rounded),
            label: context.l10n.navTasks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: context.l10n.navCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
