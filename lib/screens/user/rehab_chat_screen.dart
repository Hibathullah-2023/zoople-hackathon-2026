import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class RehabChatScreen extends StatefulWidget {
  const RehabChatScreen({super.key});

  @override
  State<RehabChatScreen> createState() => _RehabChatScreenState();
}

class _RehabChatScreenState extends State<RehabChatScreen> {
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'ai',
      'text': 'Hello! I am your Nizhal Rehabilitation Assistant. I am here to listen, support, and share information on substance abuse recovery. How can I help you today?',
      'time': 'Just now'
    }
  ];
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _cannedResponses = {
    'help': 'I can provide information on nearby rehabilitation centres, recovery advice, warning signs of addiction, or just offer a safe, anonymous space to chat. What is on your mind?',
    'hello': 'Hello! Please know that you are not alone in this journey. I am here to help you find resources and motivation.',
    'hi': 'Hello! Please know that you are not alone in this journey. I am here to help you find resources and motivation.',
    'rehab': 'Rehabilitation centres provide structured therapy, detox support, and medical counseling. You can view a list of nearby centres in Kerala by selecting "Nearby Centres" on the Home Screen.',
    'support': 'Seeking support is a very courageous first step. You can talk to family, contact professional counselors, or visit a registered de-addiction centre. We have listed verified Kerala centres in the app.',
    'addiction': 'Addiction is a complex condition, but recovery is absolutely possible. Professional treatment programs, behavioral therapy, and support groups like Narcotics Anonymous are highly effective.',
    'depressed': 'I am sorry you are feeling this way. Recovery can be emotionally challenging. Please consider talking to a mental health professional or counselor. You can also reach out to Kerala de-addiction helplines.',
    'sad': 'I hear you. It is okay to have difficult days. Remember to take things one step at a time. Professional guidance can help make this transition easier.',
    'thank': 'You are very welcome! Nizhal is committed to supporting our community. Stay strong, and take care of yourself.',
    'thanks': 'You are very welcome! Nizhal is committed to supporting our community. Stay strong, and take care of yourself.',
  };

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'time': 'Just now',
      });
      _messageController.clear();
    });

    _scrollToBottom();

    // Generate AI response
    Future.delayed(const Duration(milliseconds: 1000), () {
      final responseText = _getAIResponse(text);
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': responseText,
            'time': 'Just now',
          });
        });
        _scrollToBottom();
      }
    });
  }

  String _getAIResponse(String userInput) {
    final cleanInput = userInput.toLowerCase();
    for (final key in _cannedResponses.keys) {
      if (cleanInput.contains(key)) {
        return _cannedResponses[key]!;
      }
    }
    return 'Thank you for sharing. Recovering from substance abuse requires patience and professional support. I highly recommend reaching out to a local health professional or a rehabilitation center for personalized guidance. You are always welcome to check our "Nearby Centres" tab for contacts.';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryContainer,
              ),
              child: const Icon(Icons.psychology, size: 20, color: AppColors.onSecondaryContainer),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rehab Assistant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Anonymous Chatbot', style: TextStyle(fontSize: 10, color: AppColors.secondary)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Disclaimer banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceContainerLow,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This assistant provides supportive info, not medical diagnosis or professional therapy.',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return _ChatBubble(isUser: isUser, text: msg['text'], time: msg['time']);
              },
            ),
          ),
          
          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      style: const TextStyle(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Ask about recovery, rehab, coping...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        fillColor: AppColors.surfaceContainer,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onFieldSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary,
                      ),
                      child: const Icon(Icons.send, color: AppColors.onSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final String time;

  const _ChatBubble({required this.isUser, required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.secondary.withValues(alpha: 0.15) : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser ? AppColors.secondary.withValues(alpha: 0.3) : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
