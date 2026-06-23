import 'package:flutter/material.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final int unreadNotifCount;

  const CustomBottomNavbar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.unreadNotifCount,
  }) : super(key: key);

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, {bool showBadge = false}) {
    bool isSelected = selectedIndex == index;
    Color activeColor = const Color(0xffF9A826);

    return Expanded(
      child: GestureDetector(
        onTap: () => onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
              color: isSelected ? activeColor.withOpacity(0.08) : Colors.transparent,
              border: Border(
                  top: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 3.5)
              )
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? activeIcon : inactiveIcon, color: isSelected ? activeColor : Colors.grey.shade500, size: 28),
                  if (showBadge)
                    Positioned(
                      right: -3, top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, -5))
          ]
      ),
      child: SafeArea(
        bottom: true,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.apartment_rounded, Icons.apartment_outlined, 'Units'),
              _buildNavItem(2, Icons.mail_rounded, Icons.mail_outline_rounded, 'Inbox', showBadge: unreadNotifCount > 0),
              _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}