// lib/ui/subject/subject_navigation.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/subject_card.dart';

/// Pushes to the subject detail route for [card]. Does nothing if the
/// card has no [SubjectCard.id] -- all five `SubjectCard.from*` factories
/// set this from a required wire field, so in practice this should not
/// happen for cards rendered by Home/Search/Schedule/My-Collection;
/// guarded defensively so a malformed API response can't crash navigation.
void openSubjectDetail(BuildContext context, SubjectCard card) {
  final id = card.id;
  if (id == null) return;
  final name = Uri.encodeComponent(card.nameCn ?? card.name);
  final imageUrl = card.imageUrl;
  final query = imageUrl == null
      ? 'name=$name'
      : 'name=$name&imageUrl=${Uri.encodeComponent(imageUrl)}';
  context.push('/subject/$id?$query');
}
