import 'package:flutter/material.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/features/home/presentation/widgets/post_card.dart';
import 'package:agrobravo/features/home/presentation/widgets/comments_bottom_sheet.dart';
import 'package:agrobravo/features/profile/domain/repositories/profile_repository.dart';
import 'package:agrobravo/features/home/domain/entities/post_entity.dart';
import 'package:agrobravo/features/home/domain/repositories/feed_repository.dart';
import 'package:go_router/go_router.dart';

class UserFeedPage extends StatefulWidget {
  final String userId;
  final String? initialPostId;

  const UserFeedPage({super.key, required this.userId, this.initialPostId});

  @override
  State<UserFeedPage> createState() => _UserFeedPageState();
}

class _UserFeedPageState extends State<UserFeedPage> {
  List<PostEntity> _posts = [];
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final result = await getIt<ProfileRepository>().getUserPosts(widget.userId);
    if (mounted) {
      result.fold(
        (error) => setState(() {
          _error = error.toString();
          _isLoading = false;
        }),
        (posts) {
          setState(() {
            _posts = posts;
            _isLoading = false;
          });

          if (widget.initialPostId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final index = _posts.indexWhere(
                (p) => p.id == widget.initialPostId,
              );
              if (index != -1) {
                _scrollController.jumpTo(index * 550.0 + 130.0);
              }
            });
          }
        },
      );
    }
  }

  Future<void> _toggleLike(PostEntity post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final isLiked = post.isLiked;
    setState(() {
      _posts[index] = post.copyWith(
        isLiked: !isLiked,
        likesCount: isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    });

    final result = isLiked
        ? await getIt<FeedRepository>().unlikePost(post.id)
        : await getIt<FeedRepository>().likePost(post.id);

    result.fold((error) {
      if (mounted) setState(() => _posts[index] = post);
    }, (_) => null);
  }

  void _confirmDeletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Publicação'),
        content: const Text(
          'Tem certeza que deseja excluir esta publicação?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final result =
                  await getIt<FeedRepository>().deletePost(postId);
              result.fold(
                (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erro ao excluir publicação.'),
                      ),
                    );
                  }
                },
                (_) {
                  if (mounted) {
                    setState(() => _posts.removeWhere((p) => p.id == postId));
                  }
                },
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = getIt<FeedRepository>().getCurrentUserId();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppHeader(mode: HeaderMode.back, title: 'Publicações'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _posts.isEmpty
          ? Center(
              child: Text(
                'Nenhuma publicação encontrada.',
                style: AppTextStyles.bodyMedium,
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                top: 130,
                bottom: AppSpacing.md,
              ),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final isOwner = post.userId == currentUserId;
                return PostCard(
                  post: post,
                  isOwner: isOwner,
                  onLike: () => _toggleLike(post),
                  onComment: () => _showComments(context, post.id),
                  onProfileTap: () =>
                      context.push('/profile/${post.userId}'),
                  onDelete: isOwner
                      ? () => _confirmDeletePost(context, post.id)
                      : null,
                  onEdit: isOwner
                      ? () async {
                          final result = await context.push<bool>(
                            '/create-post',
                            extra: {
                              'initialImages': post.images,
                              'postToEdit': post,
                            },
                          );
                          if (result == true && mounted) _loadPosts();
                        }
                      : null,
                );
              },
            ),
    );
  }

  void _showComments(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        onCommentChanged: () => _loadPosts(),
      ),
    );
  }
}
