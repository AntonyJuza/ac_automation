import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';

class ACButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCircular;
  final Color? activeColor;

  const ACButton({
    super.key,
    required this.icon,
    this.label,
    this.isActive = false,
    required this.onTap,
    this.isCircular = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCircular ? 64 : 80,
            height: 64,
            decoration: BoxDecoration(
              color: isActive 
                  ? (activeColor ?? AppColors.primaryBrand) 
                  : AppColors.primaryBackground,
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular ? null : BorderRadius.circular(AppStyles.borderRadius),
              boxShadow: [AppStyles.softShadow],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.textSecondary,
              size: 28,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: TextStyle(
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }
}
