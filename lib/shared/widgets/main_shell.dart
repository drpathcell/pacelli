import 'package:flutter/material.dart';

import '../../core/utils/extensions.dart';
import 'pacelli_ai_icon.dart';

/// Main shell with bottom navigation bar and a central AI chat FAB.
///
/// Wraps the Home, Tasks, Calendar and Settings tabs using GoRouter's
/// ShellRoute. Applies a directional slide transition that matches the
/// tab position — sliding in from right for higher-index tabs and from
/// left for lower-index tabs. Only one page is ever in the widget tree
/// at a time, avoiding GlobalKey conflicts.
///
/// The AI FAB is a semicircle button that floats above the center of the
/// bottom nav bar, providing instant access to the in-app AI chat from
/// any tab.
class MainShell extends StatefulWidget {
  final int currentIndex;
  final Widget child;
  final ValueChanged<int> onTabChanged;
  final VoidCallback? onAiChatPressed;

  const MainShell({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabChanged,
    this.onAiChatPressed,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  int _previousIndex = 0; // ignore: unused_field

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
      // Disable Scaffold's default FAB behaviour — we position it manually.
      extendBody: true,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // ── Navigation Bar ──
          NavigationBar(
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
              // Spacer destination for the center FAB
              const NavigationDestination(
                icon: SizedBox.shrink(),
                label: '',
                enabled: false,
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

          // ── AI Chat FAB ──
          Positioned(
            top: -22,
            child: _AiChatFab(onPressed: widget.onAiChatPressed),
          ),
        ],
      ),
    );
  }
}

/// The semicircle floating button for AI chat.
///
/// A raised, circular Material button with a gradient background and
/// a subtle glow shadow, positioned to protrude above the navigation
/// bar by half its height.
class _AiChatFab extends StatelessWidget {
  final VoidCallback? onPressed;
  const _AiChatFab({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary,
              Color.lerp(primary, Colors.white, 0.15) ?? primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: primary.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const PacelliAiIcon(
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }
}
