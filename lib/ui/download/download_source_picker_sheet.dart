import 'package:flutter/material.dart';

import '../../domain/play/subject_episodes_controller.dart';

/// Bottom sheet letting the user manually pick which downloadable source
/// (out of [EpisodeDownloadOption.candidates]) an episode should be
/// downloaded from. Mirrors the interaction pattern of
/// `lib/ui/player/line_switch_sheet.dart`'s `LineSwitchSheet`, but is typed
/// for [MergedEpisode] (a download candidate) instead of
/// `MediaPlaybackSource` (an online-playback line).
class DownloadSourcePickerSheet extends StatelessWidget {
  const DownloadSourcePickerSheet({
    super.key,
    required this.candidates,
    required this.current,
    required this.onSelect,
  });

  final List<MergedEpisode> candidates;
  final MergedEpisode current;
  final ValueChanged<MergedEpisode> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          final isSelected = candidate.sourceId == current.sourceId;
          return ListTile(
            title: Text(candidate.sourceId),
            selected: isSelected,
            trailing: isSelected ? const Icon(Icons.check) : null,
            onTap: () => onSelect(candidate),
          );
        },
      ),
    );
  }
}
