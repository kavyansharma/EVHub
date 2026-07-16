import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_message.dart';
import 'dart:ui';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      context.read<AssistantProvider>().loadHistory(authProvider.user?.id ?? 'default_user');
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({String? predefinedText}) async {
    final text = predefinedText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (predefinedText == null) {
      _messageController.clear();
    }
    
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<AssistantProvider>();
    await provider.sendMessage(authProvider.user?.id ?? 'default_user', text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;
    final provider = context.watch<AssistantProvider>();
    final messages = provider.messages.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: brandColor.withOpacity(0.3)),
              ),
              child: HugeIcon(icon: HugeIcons.strokeRoundedBot, color: brandColor, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('EVHub Intelligence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          // Dynamic Background ambient glows
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(color: AppColors.background),
                  Positioned(
                    top: -100 + (_bgAnimationController.value * 50),
                    left: -50 - (_bgAnimationController.value * 50),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: brandColor.withOpacity(0.08),
                        boxShadow: [BoxShadow(color: brandColor.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 100 - (_bgAnimationController.value * 30),
                    right: -100 + (_bgAnimationController.value * 30),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withOpacity(0.05),
                        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.08), blurRadius: 100, spreadRadius: 50)],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(messages[index], brandColor);
                    },
                  ),
                ),
                
                if (provider.isTyping) _buildTypingIndicator(brandColor),

                // Quick Prompts list when chat is empty
                if (messages.isEmpty) _buildQuickPromptChips(),
                
                _buildInputArea(brandColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Color brandColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: brandColor),
                ),
                const SizedBox(width: 12),
                const Text('Formulating response...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, Color brandColor) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: brandColor.withOpacity(0.3)),
              ),
              child: HugeIcon(icon: HugeIcons.strokeRoundedBot, color: brandColor, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: isUser 
                    ? LinearGradient(colors: [AppColors.accent, brandColor])
                    : null,
                color: isUser ? null : AppColors.card.withOpacity(0.5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: isUser ? const Radius.circular(24) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(24),
                ),
                border: Border.all(
                  color: isUser ? brandColor.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: isUser ? AppColors.neonShadow(color: brandColor, blurRadius: 10) : null,
              ),
              child: Text(
                message.message,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildQuickPromptChips() {
    final prompts = [
      'Find 120kW Fast Chargers',
      'Calculate SOH Diagnostics',
      'Optimize NEXON real-range',
      'Compare AC/DC plug rates',
    ];

    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: AppColors.card.withOpacity(0.5),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              label: Text(
                prompts[index],
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              onPressed: () => _sendMessage(predefinedText: prompts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(Color brandColor) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.6),
            border: const Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ask AI assistant...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _sendMessage(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: brandColor,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.neonShadow(color: brandColor, blurRadius: 10),
                  ),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedArrowUp01, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

