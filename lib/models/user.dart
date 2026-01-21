class User {
  final int id;
  final String email;
  final String? avatarUrl;

  User({required this.id, required this.email, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }
}
