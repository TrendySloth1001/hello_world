import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ConversationShimmerLoader extends StatelessWidget {
  final int itemCount;

  const ConversationShimmerLoader({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 80, color: Colors.white10),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Container(width: 150, height: 16, color: Colors.white),
                      const SizedBox(height: 6),
                      // Message preview
                      Container(
                        width: double.infinity,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Time & Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(width: 40, height: 12, color: Colors.white),
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
