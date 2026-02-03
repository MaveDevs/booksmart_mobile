import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'tabs/search_tab.dart';
import 'tabs/appointments_tab.dart';
import 'tabs/profile_tab.dart';

/// Pantalla principal con navegacion flotante
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    SearchTab(),
    AppointmentsTab(),
    ProfileTab(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.search_rounded, label: 'Buscar'),
    _NavItemData(icon: Icons.calendar_today_rounded, label: 'Citas'),
    _NavItemData(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;
              return Stack(
                children: [
                  // Highlight deslizante con padding y bordes redondeados
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: _currentIndex * itemWidth + 8,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Items de navegacion
                  Row(
                    children: List.generate(
                      _navItems.length,
                      (index) => _NavItem(
                        icon: _navItems[index].icon,
                        label: _navItems[index].label,
                        isSelected: _currentIndex == index,
                        onTap: () => setState(() => _currentIndex = index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Datos de un item de navegacion
class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}

/// Item individual del menu de navegacion
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: isSelected
                ? Row(
                    key: const ValueKey('selected'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    key: const ValueKey('unselected'),
                    icon,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
