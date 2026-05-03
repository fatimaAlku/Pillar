enum StudyChatRole { user, assistant }

class StudyChatTurn {
  const StudyChatTurn({required this.role, required this.content});

  final StudyChatRole role;
  final String content;
}
