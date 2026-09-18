import 'package:flutter/material.dart';

import 'download_panel.dart';

/// Thin wrapper around [DownloadPanel] for the `/downloads` route (still
/// reachable from Settings -> "下载管理"). `subjectId: null` means this
/// covers every subject's downloads, with no episode-selection tab.
class DownloadManagerScreen extends StatelessWidget {
  const DownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载管理')),
      body: const DownloadPanel(subjectId: null),
    );
  }
}
