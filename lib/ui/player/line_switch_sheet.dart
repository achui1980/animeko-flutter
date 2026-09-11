// lib/ui/player/line_switch_sheet.dart
import 'package:flutter/material.dart';

import '../../data/torrent/torrent_playback_source.dart';
import '../../domain/media/media_source.dart';

class LineSwitchSheet extends StatelessWidget {
  const LineSwitchSheet({
    super.key,
    required this.candidates,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<MediaPlaybackSource> candidates;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          final isSelected = index == currentIndex;
          final subtitle = candidate is TorrentPlaybackSource
              ? Text(candidate.release.item.title)
              : null;
          return ListTile(
            title: Text(candidate.label ?? '线路 ${index + 1}'),
            subtitle: subtitle,
            selected: isSelected,
            trailing: isSelected ? const Icon(Icons.check) : null,
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}
