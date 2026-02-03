import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProfileShimmerLoader extends StatelessWidget {
  const ProfileShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 24),
            // Name/Email
            Container(width: 200, height: 24, color: Colors.white),
            const SizedBox(height: 8),
            // Badge
            Container(
              width: 100,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            Container(width: 180, height: 14, color: Colors.white),
            const SizedBox(height: 48),
            // Settings Tiles
            for (int i = 0; i < 4; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
