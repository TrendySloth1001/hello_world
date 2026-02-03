import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LogShimmerLoader extends StatelessWidget {
  final int itemCount;

  const LogShimmerLoader({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: ListView.builder(
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                // Status Code Placeholder
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Method & Path Placeholder
                      Row(
                        children: [
                          Container(width: 40, height: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(height: 14, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Time Placeholder
                      Container(width: 120, height: 12, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          );
        },
      ),
    );
  }
}
