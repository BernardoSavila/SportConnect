import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label, this.showBadge = false});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showBadge;
}

/// Barra de navegação inferior com um indicador em forma de "pílula" que
/// desliza suavemente para o item selecionado — mais distintivo do que a
/// [NavigationBar] genérica do Material.
class AnimatedBottomNav extends StatelessWidget {
  const AnimatedBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: itemWidth * selectedIndex + itemWidth * 0.15,
                    top: 8,
                    child: Container(
                      width: itemWidth * 0.7,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: AppColors.cardAccentGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(items.length, (i) {
                      final selected = i == selectedIndex;
                      return Expanded(
                        child: InkWell(
                          onTap: () => onSelected(i),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  scale: selected ? 1.15 : 1.0,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        selected ? items[i].selectedIcon : items[i].icon,
                                        color: selected ? AppColors.primaryBlue : AppColors.textMuted,
                                        size: 24,
                                      ),
                                      if (items[i].showBadge)
                                        Positioned(
                                          right: -3,
                                          top: -2,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: AppColors.coral,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  items[i].label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? AppColors.primaryBlue : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
