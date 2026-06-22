class ChatMessage {
  final String text;
  final bool isMe;

  ChatMessage({required this.text, required this.isMe});

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isMe': isMe,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] as String? ?? '',
      isMe: map['isMe'] as bool? ?? false,
    );
  }
}
