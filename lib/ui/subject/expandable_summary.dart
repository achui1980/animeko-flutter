// lib/ui/subject/expandable_summary.dart
import 'package:flutter/material.dart';

/// A block of text that collapses to [collapsedHeight] with a
/// "展开"/"收起" toggle button when it would render more than [maxLines]
/// lines at the widget's actual width.
///
/// Mirrors Kazumi's `infoBody` pattern (measure the real rendered line
/// count via [TextPainter] before deciding whether to show a
/// collapse/expand control), rather than always truncating regardless
/// of how short the text actually is.
class ExpandableSummary extends StatefulWidget {
  const ExpandableSummary({super.key, required this.text, this.maxLines = 7, this.collapsedHeight = 120});

  final String text;
  final int maxLines;
  final double collapsedHeight;

  @override
  State<ExpandableSummary> createState() => _ExpandableSummaryState();
}

class _ExpandableSummaryState extends State<ExpandableSummary> {
  bool _expanded = false;

  bool _exceedsMaxLines(BuildContext context, double maxWidth) {
    final style = DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflowing = _exceedsMaxLines(context, constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: (!overflowing || _expanded) ? null : widget.collapsedHeight,
                child: ClipRect(child: SelectableText(widget.text)),
              ),
            ),
            if (overflowing)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '收起' : '展开'),
              ),
          ],
        );
      },
    );
  }
}
