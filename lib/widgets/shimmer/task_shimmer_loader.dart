import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TaskShimmerLoader extends StatelessWidget {
  final int itemCount;

  const TaskShimmerLoader({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Avatar Row
                Row(
                  children: [
                    Expanded(child: Container(height: 16, color: Colors.white)),
                    const SizedBox(width: 32),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Description lines
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Container(width: 250, height: 12, color: Colors.white),
                const SizedBox(height: 12),
                // Progress Bar
                Container(
                  width: double.infinity,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Footer (Date, Comments)
                Row(
                  children: [
                    Container(width: 14, height: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Container(width: 60, height: 10, color: Colors.white),
                    const SizedBox(width: 16),
                    Container(width: 14, height: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Container(width: 20, height: 10, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
