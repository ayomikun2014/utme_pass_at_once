import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../constants/app_colors.dart';

class CustomLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const CustomLoader({super.key, this.size = 40.0, this.color});

  @override
  Widget build(BuildContext context) {
    // Determine the color to use. Fallback to AppColors.primary if none provided.
    final loaderColor = color ?? AppColors.primary;

    return Center(
      child: LoadingAnimationWidget.staggeredDotsWave(
        color: loaderColor,
        size: size,
      ),
    );
  }
}
