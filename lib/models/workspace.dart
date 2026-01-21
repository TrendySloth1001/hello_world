class Workspace {
  final int id;
  final String name;
  final String? description;
  final String publicId;
  final String? avatarUrl;
  final int ownerId;
  final WorkspaceOwner owner;
  final int memberCount;
  final List<WorkspaceMember> members;

  Workspace({
    required this.id,
    required this.name,
    this.description,
    required this.publicId,
    this.avatarUrl,
    required this.ownerId,
    required this.owner,
    this.memberCount = 0,
    this.members = const [],
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      publicId: json['publicId'],
      avatarUrl: json['avatarUrl'],
      ownerId: json['ownerId'],
      owner: WorkspaceOwner.fromJson(
        json['owner'] ?? {'id': json['ownerId'], 'email': ''},
      ),
      memberCount: json['_count']?['members'] ?? 0,
      members: json['members'] != null
          ? (json['members'] as List)
                .map((m) => WorkspaceMember.fromJson(m))
                .toList()
          : [],
    );
  }
}

class WorkspaceOwner {
  final int id;
  final String email;
  final String? avatarUrl;

  WorkspaceOwner({required this.id, required this.email, this.avatarUrl});

  factory WorkspaceOwner.fromJson(Map<String, dynamic> json) {
    return WorkspaceOwner(
      id: json['id'],
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }
}

class WorkspaceMember {
  final int id;
  final int userId;
  final int workspaceId;
  final String position;
  final MemberUser user;
  final DateTime joinedAt;

  WorkspaceMember({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.position,
    required this.user,
    required this.joinedAt,
  });

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(
      id: json['id'],
      userId: json['userId'],
      workspaceId: json['workspaceId'],
      position: json['position'],
      user: MemberUser.fromJson(json['user']),
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }
}

class MemberUser {
  final int id;
  final String email;
  final String? avatarUrl;

  MemberUser({required this.id, required this.email, this.avatarUrl});

  factory MemberUser.fromJson(Map<String, dynamic> json) {
    return MemberUser(
      id: json['id'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class JoinRequest {
  final int id;
  final int userId;
  final int workspaceId;
  final String status;
  final MemberUser user;
  final DateTime createdAt;

  JoinRequest({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.status,
    required this.user,
    required this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'],
      userId: json['userId'],
      workspaceId: json['workspaceId'],
      status: json['status'],
      user: MemberUser.fromJson(json['user']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class UserWorkspaces {
  final List<Workspace> owned;
  final List<Workspace> memberOf;

  UserWorkspaces({required this.owned, required this.memberOf});

  factory UserWorkspaces.fromJson(Map<String, dynamic> json) {
    return UserWorkspaces(
      owned: (json['owned'] as List).map((e) => Workspace.fromJson(e)).toList(),
      memberOf: (json['memberOf'] as List)
          .map((e) => Workspace.fromJson(e))
          .toList(),
    );
  }
}

class InviteUser {
  final int id;
  final String email;
  final String? avatarUrl;

  InviteUser({required this.id, required this.email, this.avatarUrl});

  factory InviteUser.fromJson(Map<String, dynamic> json) {
    return InviteUser(
      id: json['id'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class WorkspaceInvite {
  final int id;
  final int workspaceId;
  final String workspaceName;
  final String? workspaceAvatarUrl;

  WorkspaceInvite({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    this.workspaceAvatarUrl,
  });

  factory WorkspaceInvite.fromJson(Map<String, dynamic> json) {
    return WorkspaceInvite(
      id: json['id'],
      workspaceId: json['workspace']['id'] ?? json['workspaceId'],
      workspaceName: json['workspace']['name'] ?? '',
      workspaceAvatarUrl: json['workspace']['avatarUrl'],
    );
  }
}
