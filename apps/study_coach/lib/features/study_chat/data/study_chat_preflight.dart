/// Client-side guardrails before calling the study chat model (Layer 3).
/// Does not replace server-side classification; blocks obvious abuse cheaply.
bool studyChatMessageLooksBlocked(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return false;

  const en = <String>[
    'ignore previous',
    'ignore the above',
    'ignore all previous',
    'ignore your instructions',
    'disregard previous',
    'system prompt',
    'developer message',
    'jailbreak',
    'dan mode',
    'roleplay as',
    'pretend you are',
    'you are now',
    'tell me a joke',
    'write a poem',
    'write me a song',
    'who won the',
    'latest news',
    'weather today',
    'recipe for',
    'dating advice',
    'medical diagnosis',
    'legal advice',
    'investment advice',
    'crypto tip',
    'how to hack',
    'bypass paywall',
  ];

  const ar = <String>[
    'تجاهل التعليمات',
    'تجاهل ما سبق',
    'تجاهل كل ما',
    'اكتب نكتة',
    'قصيدة',
    'اغنية',
    'أخبار اليوم',
    'الطقس',
    'نصائح طبية',
    'نصائح قانونية',
  ];

  for (final p in en) {
    if (s.contains(p)) return true;
  }
  for (final p in ar) {
    if (raw.contains(p)) return true;
  }
  return false;
}
