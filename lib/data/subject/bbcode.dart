// lib/data/subject/bbcode.dart

/// Matches an `[img]...[/img]` or `[img=param]...[/img]` block including
/// its content -- images are dropped entirely, we render plain text only.
final _imgBlock = RegExp(
  r'\[img(?:=[^\]]*)?\].*?\[/img\]',
  caseSensitive: false,
  dotAll: true,
);

/// Matches any single BBCode tag: `[b]`, `[/b]`, `[size=16]`, `[url=...]`.
final _anyTag = RegExp(r'\[/?[a-zA-Z][a-zA-Z0-9]*(?:=[^\]]*)?\]');

/// Strips BBCode markup from [input], returning plain text.
///
/// Rules:
///  - `[img]...[/img]` blocks are discarded entirely (content included).
///  - Every other tag is removed but its content is kept.
///  - Unclosed or stray tags are removed; surrounding text survives.
///  - Input without tags is returned unchanged.
///
/// Used for `SubjectReview.contentBbcode`, which the 热门评价 card and
/// sheet render as plain text.
String stripBbcode(String input) {
  if (input.isEmpty) return '';
  return input.replaceAll(_imgBlock, '').replaceAll(_anyTag, '');
}
