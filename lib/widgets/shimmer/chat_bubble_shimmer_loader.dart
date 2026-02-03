import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ChatBubbleShimmerLoader extends StatelessWidget {
  const ChatBubbleShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      reverse: true,
      itemCount: 15,
      itemBuilder: (context, index) {
        final isMe = index % 2 == 0;
        return Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 200,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
