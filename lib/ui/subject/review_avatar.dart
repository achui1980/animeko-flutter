// lib/ui/subject/review_avatar.dart
import 'package:flutter/material.dart';

import '../../data/subject/review_models.dart';

/// A commenter's avatar. `avatarUrl` is often present but may 404, so a
/// bare `onBackgroundImageError` callback is not enough to satisfy the
/// design doc's 「加载 / 错误 / 空态」 table (「封面 / 角色头像 / 评价者头像
/// 加载失败 → 占位图标」) -- an empty callback only swallows the exception,
/// it does not swap in the placeholder icon. `CircleAvatar.backgroundImage`
/// has no `errorBuilder`, so the swap can only happen via `setState`,
/// which is why this is a [StatefulWidget]: hence the `mounted` guard (the
/// image stream's callback is async and the widget may already be gone) and
/// the URL-not-bool tracking (unkeyed cells in a scrollable list recycle
/// `State` across different authors; a bool would leak one author's failure
/// onto the next author rendered in that slot).
///
/// `CharacterAvatar` (`character_avatar.dart`) used to share this exact
/// shape, but had to move to `ClipOval` + `Image.network` to gain
/// `alignment` control (Bangumi character art is a tall portrait that must
/// be cropped to its top), and `Image.network.errorBuilder` made it
/// stateless in the process. That is deliberately not mirrored here:
/// Bangumi user avatars are square, so `CircleAvatar` still crops them
/// correctly and there is no reason to hand-roll the clipping.
class ReviewAvatar extends StatefulWidget {
  const ReviewAvatar({super.key, required this.author, this.radius = 14});

  final ReviewAuthor author;
  final double radius;

  @override
  State<ReviewAvatar> createState() => _ReviewAvatarState();
}

class _ReviewAvatarState extends State<ReviewAvatar> {
  /// The URL that most recently failed to load. Tracked by value, not a
  /// bool, for the State-recycling reason in the class dartdoc.
  String? _failedUrl;

  @override
  Widget build(BuildContext context) {
    final source = widget.author.avatarUrl;
    final url = source == _failedUrl ? null : source;
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: url == null ? null : NetworkImage(url),
      onBackgroundImageError: url == null
          ? null
          : (_, _) {
              if (mounted) setState(() => _failedUrl = url);
            },
      child: url == null ? Icon(Icons.person, size: widget.radius) : null,
    );
  }
}
