import 'package:flutter/material.dart';
import '../../views/workspace_detail_screen.dart';

class WorkspaceAttachment extends StatelessWidget {
  final int workspaceId;
  final Map<String, dynamic> workspace;
  final int currentUserId;

  const WorkspaceAttachment({
    super.key,
    required this.workspaceId,
    required this.workspace,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final owner = workspace['owner'];
    final ownerEmail = owner != null ? owner['email'] : 'Unknown';
    final ownerAvatarUrl = owner != null ? owner['avatarUrl'] : null;
    final isOwner =
        owner != null &&
        (owner['id'] == currentUserId || workspace['ownerId'] == currentUserId);

    // Parse workspace name
    final workspaceName = workspace['name'] ?? 'Unnamed Workspace';
    final workspaceAvatarUrl = workspace['avatarUrl'];

    return Container(
      width: 260,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkspaceDetailScreen(
                  workspaceId: workspaceId,
                  workspaceName: workspaceName,
                  isOwner: isOwner,
                  ownerEmail: ownerEmail,
                  ownerAvatarUrl: ownerAvatarUrl,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Workspace Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade800,
                      backgroundImage: workspaceAvatarUrl != null
                          ? NetworkImage(workspaceAvatarUrl)
                          : null,
                      child: workspaceAvatarUrl == null
                          ? Text(
                              workspaceName.isNotEmpty
                                  ? workspaceName[0].toUpperCase()
                                  : 'W',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workspaceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Owner: $ownerEmail',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login, size: 14, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        'View Workspace',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
