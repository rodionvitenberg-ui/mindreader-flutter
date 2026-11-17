/// One turn of the Oracle AI Chat conversation (Pane 1 of the Table
/// workspace). Pure Dart — no Flutter imports.
class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.slotIndex});

  /// 'user' | 'oracle' | 'system'.
  final String role;

  final String text;

  /// Set on clarifier-related turns: the dealt slot this message belongs to.
  final int? slotIndex;

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        if (slotIndex != null) 'slotIndex': slotIndex,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        text: json['text'] as String,
        slotIndex: json['slotIndex'] as int?,
      );
}
