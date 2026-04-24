class UserAccount {
  UserAccount({
    required this.username,
    required this.password,
    this.prompt = '> ',
    this.longDescription = '',
  });

  final String username;
  final String password;
  String prompt;
  String longDescription;

  factory UserAccount.fromJson(Map<String, Object?> json) {
    return UserAccount(
      username: json['username']! as String,
      password: json['password']! as String,
      prompt: (json['prompt'] as String?) ?? '> ',
      longDescription: (json['longDesc'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'username': username,
        'password': password,
        'prompt': prompt,
        'longDesc': longDescription,
      };
}
