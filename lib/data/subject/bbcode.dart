// lib/data/subject/bbcode.dart

/// Matches an `[img]…[/img]` or `[mask]…[/mask]` block including its content,
/// with an optional `=param` on the opening tag.
///
/// The `\1` backreference makes the closing tag name the same tag as the
/// opening one, so `[img]x[/mask]` is *not* a block -- both of its tags fall
/// through to [_anyTag] as strays and `x` survives.
final _discardedBlock = RegExp(
  r'\[(img|mask)(?:=[^\]]*)?\].*?\[/\1\]',
  caseSensitive: false,
  dotAll: true,
);

/// Matches any single BBCode tag: `[b]`, `[/b]`, `[size=16]`, `[url=...]`.
///
/// A tag name starts with a letter and continues with letters or digits, which
/// is what leaves prose like `[9/10]` alone.
final _anyTag = RegExp(r'\[/?[a-zA-Z][a-zA-Z0-9]*(?:=[^\]]*)?\]');

/// Strips BBCode markup from [input], returning trimmed plain text.
///
/// Rules:
///  - `[img]…[/img]` and `[mask]…[/mask]` blocks are discarded entirely
///    (content included).
///  - Every other tag is removed but its content is kept.
///  - Unclosed or stray tags are removed; surrounding text survives.
///  - The result is trimmed, so tag-free input comes back unchanged except for
///    leading/trailing whitespace. Discarding a leading or trailing `[img]`
///    therefore does not leave a blank line behind.
///
/// `[mask]` is Bangumi's masked-text tag ("马赛克文字", Ctrl+M) — a spoiler.
/// It is discarded rather than unwrapped because leaking a spoiler is not
/// recoverable by the reader, whereas losing a few characters of preview text
/// is; the full review is still on Bangumi.
///
/// Note that rules 1 and 3 combine: an *unclosed* `[img]` leaves its bare URL
/// in the text. That is deliberate — running an unclosed `[img]` to
/// end-of-input would silently delete all remaining prose over a single typo,
/// and a bare URL is visually identical to `[url]http://chii.in/[/url]`, which
/// this helper deliberately preserves.
///
/// Used for `SubjectReview.contentBbcode`, which the 热门评价 card and
/// sheet render as plain text.
String stripBbcode(String input) {
  // Fast path, not a behavioural branch: callers pass `contentBbcode ?? ''`,
  // so empty input is common and this skips two regex passes and a trim. The
  // code below already returns '' for '' — do not write a test believing this
  // line is the thing under test.
  if (input.isEmpty) return '';
  return input.replaceAll(_discardedBlock, '').replaceAll(_anyTag, '').trim();
}
