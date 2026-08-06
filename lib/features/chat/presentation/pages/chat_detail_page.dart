import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/features/chat/domain/entities/chat_entity.dart';
import 'package:agrobravo/features/chat/domain/entities/message_entity.dart';
import 'package:agrobravo/features/chat/presentation/cubit/chat_detail_cubit.dart';
import 'package:agrobravo/features/chat/presentation/cubit/chat_detail_state.dart';
import 'package:agrobravo/features/chat/presentation/pages/group_info_page.dart';
import 'package:agrobravo/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:agrobravo/features/chat/presentation/widgets/chat_input.dart';
import 'package:agrobravo/features/chat/presentation/widgets/image_preview_page.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:intl/intl.dart';

class ChatDetailPage extends StatelessWidget {
  final ChatEntity chat;
  final bool showAppBar;

  const ChatDetailPage({
    super.key,
    required this.chat,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    // Using manual instantiation as fallback since build_runner failed
    return BlocProvider(
      create: (_) =>
          getIt<ChatDetailCubit>()..loadMessages(chat.id, isGroup: true),
      child: _ChatDetailView(chat: chat, showAppBar: showAppBar),
    );
  }
}

class _ChatDetailView extends StatefulWidget {
  final ChatEntity chat;
  final bool showAppBar;

  const _ChatDetailView({
    required this.chat,
    this.showAppBar = true,
  });

  @override
  State<_ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<_ChatDetailView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool _showScrollToBottom = false;
  String? _editingMessageId;
  final Set<String> _selectedMessageIds = {};
  MessageEntity? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    // Com reverse:true, pixels=0 significa que está no fim visual (mensagem mais recente)
    final isAtBottom = _scrollController.position.pixels <= 200;

    if (isAtBottom && _showScrollToBottom) {
      setState(() => _showScrollToBottom = false);
    } else if (!isAtBottom && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _canDeleteMessage(MessageEntity message) {
    return message.type == MessageType.me &&
        !message.isDeleted &&
        DateTime.now().difference(message.timestamp) <= const Duration(hours: 1);
  }

  void _deleteSelectedMessages() {
    context.read<ChatDetailCubit>().state.whenOrNull(
      loaded: (messages) {
        final selectedMessages = messages
            .where((message) => _selectedMessageIds.contains(message.id))
            .toList();
        final canDeleteAll = selectedMessages.isNotEmpty &&
            selectedMessages.every(_canDeleteMessage);

        if (!canDeleteAll) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t(
                  'Só é possível apagar mensagens enviadas há até 1 hora.',
                  'Only messages sent within 1 hour can be deleted.',
                ),
              ),
            ),
          );
          return;
        }

        context.read<ChatDetailCubit>().deleteMessages(
          _selectedMessageIds.toList(),
        );
        setState(() {
          _selectedMessageIds.clear();
        });
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: source, imageQuality: 85);
      if (image != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ImagePreviewPage(
              image: image,
              onSend: (img, caption) {
                context.read<ChatDetailCubit>().sendMessage(
                  caption,
                  image: img,
                  replyToId: _replyingToMessage?.id,
                );
                if (_replyingToMessage != null) {
                  setState(() => _replyingToMessage = null);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('Erro ao selecionar imagem', 'Error selecting image'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.chatBackgroundDark
          : AppColors.chatBackground,
      appBar: widget.showAppBar
          ? AppHeader(
              mode: HeaderMode.back,
              title: widget.chat.title,
              subtitle: widget.chat.subtitle,
              // Using logo param to show group image, similar to home showing app logo
              logo: ClipOval(
                child: widget.chat.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.chat.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildPlaceholderAvatar(),
                        errorWidget: (_, __, ___) => _buildPlaceholderAvatar(),
                      )
                    : _buildPlaceholderAvatar(),
              ),
              onTitleTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => GroupInfoPage(chat: widget.chat),
                  ),
                );
              },
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: Theme.of(context).brightness == Brightness.dark
                  ? 0.05
                  : 0.1,
              child: Image.asset(
                'assets/images/chat_pattern.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : null,
                colorBlendMode: Theme.of(context).brightness == Brightness.dark
                    ? BlendMode.srcIn
                    : null,
              ),
            ),
          ),
          Column(
            children: [
              if (_selectedMessageIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedMessageIds.length} selecionada(s)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedMessageIds.length == 1)
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            context.read<ChatDetailCubit>().state.whenOrNull(
                              loaded: (messages) {
                                final msg = messages.firstWhere(
                                  (m) => m.id == _selectedMessageIds.first,
                                );
                                setState(() {
                                  _editingMessageId = msg.id;
                                  _messageController.text = msg.text;
                                  _selectedMessageIds.clear();
                                });
                              },
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _deleteSelectedMessages,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedMessageIds.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    BlocConsumer<ChatDetailCubit, ChatDetailState>(
                      listener: (context, state) {
                        state.maybeWhen(
                          loaded: (messages) {
                            // Com reverse:true não precisamos rolar para o fim manualmente;
                            // a lista já abre no item mais recente (índice 0).
                          },
                          orElse: () {},
                        );
                      },
                      builder: (context, state) {
                        return state.when(
                          initial: () => const SizedBox.shrink(),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (msg) => Center(
                            child: Text(
                              '${context.t('Erro', 'Error')}: $msg',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          loaded: (messages) {
                            if (messages.isEmpty) {
                              return Center(child: Text(context.t('Sem mensagens', 'No messages')));
                            }
                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                // Com reverse:true, índice 0 = mensagem mais recente
                                final reversedMessages = messages.reversed.toList();
                                final msg = reversedMessages[index];
                                final isSelected = _selectedMessageIds.contains(
                                  msg.id,
                                );

                                bool showDateHeader = false;
                                // Próximo item na ordem cronológica é o de índice maior
                                if (index == messages.length - 1) {
                                  showDateHeader = true;
                                } else {
                                  final nextMsg = reversedMessages[index + 1];
                                  final currentDate = DateTime(
                                    msg.timestamp.year,
                                    msg.timestamp.month,
                                    msg.timestamp.day,
                                  );
                                  final prevDate = DateTime(
                                    nextMsg.timestamp.year,
                                    nextMsg.timestamp.month,
                                    nextMsg.timestamp.day,
                                  );
                                  if (currentDate.isAfter(prevDate)) {
                                    showDateHeader = true;
                                  }
                                }

                                return Column(
                                  children: [
                                    if (showDateHeader)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16.0,
                                        ),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _formatDateHeader(msg.timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ChatBubble(
                                      message: msg.text,
                                      time:
                                          '${msg.timestamp.toLocal().hour}:${msg.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                                      type: _mapMessageType(msg.type),
                                      userName: msg.userName,
                                      userAvatarUrl: msg.userAvatarUrl,
                                      guideRole: msg.guideRole,
                                      attachmentUrl: msg.attachmentUrl,
                                      audioUrl: msg.audioUrl,
                                      audioDurationMs: msg.audioDurationMs,
                                      isEdited: msg.isEdited,
                                      isDeleted: msg.isDeleted,
                                      isPending: msg.isPending,
                                      isSelected: isSelected,
                                      repliedMessage:
                                          msg.repliedToMessage?.text,
                                      repliedUserName:
                                          msg.repliedToMessage?.userName,
                                      onReply: () {
                                        setState(() {
                                          _replyingToMessage = msg;
                                          _editingMessageId = null;
                                        });
                                      },
                                      onLongPress:
                                          msg.type == MessageType.me &&
                                              !msg.isDeleted
                                          ? () {
                                              setState(() {
                                                _selectedMessageIds.add(msg.id);
                                              });
                                            }
                                          : null,
                                      onTap:
                                          _selectedMessageIds.isNotEmpty &&
                                              msg.type == MessageType.me &&
                                              !msg.isDeleted
                                          ? () {
                                              setState(() {
                                                if (isSelected) {
                                                  _selectedMessageIds.remove(
                                                    msg.id,
                                                  );
                                                } else {
                                                  _selectedMessageIds.add(
                                                    msg.id,
                                                  );
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    if (_showScrollToBottom)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_downward,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ChatInput(
                controller: _messageController,
                isEditing: _editingMessageId != null,
                onCancelEdit: () {
                  setState(() {
                    _editingMessageId = null;
                  });
                },
                repliedMessage: _replyingToMessage?.text,
                repliedUserName: _replyingToMessage?.userName,
                onCancelReply: () {
                  setState(() {
                    _replyingToMessage = null;
                  });
                },
                onImagePicked: () => _pickImage(ImageSource.gallery),
                onCameraPicked: () => _pickImage(ImageSource.camera),
                onAudioRecorded: (path, durationMs) {
                  context.read<ChatDetailCubit>().sendAudioMessage(
                    path,
                    audioDurationMs: durationMs,
                    replyToId: _replyingToMessage?.id,
                  );
                  if (_replyingToMessage != null) {
                    setState(() => _replyingToMessage = null);
                  }
                },
                onSendMessage: (text) {
                  if (_editingMessageId != null) {
                    context.read<ChatDetailCubit>().editMessage(
                      _editingMessageId!,
                      text,
                    );
                    setState(() {
                      _editingMessageId = null;
                    });
                  } else {
                    context.read<ChatDetailCubit>().sendMessage(
                      text,
                      replyToId: _replyingToMessage?.id,
                    );
                    setState(() {
                      _replyingToMessage = null;
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  ChatBubbleType _mapMessageType(MessageType type) {
    switch (type) {
      case MessageType.me:
        return ChatBubbleType.me;
      case MessageType.other:
        return ChatBubbleType.other;
      case MessageType.guide:
        return ChatBubbleType.guide;
    }
  }

  String _formatDateHeader(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(localDate.year, localDate.month, localDate.day);

    if (messageDate == today) {
      return context.t('Hoje', 'Today');
    } else if (messageDate == yesterday) {
      return context.t('Ontem', 'Yesterday');
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 40,
      height: 40,
      color: Colors.grey.shade200,
      child: const Icon(Icons.group, color: Colors.grey),
    );
  }
}
