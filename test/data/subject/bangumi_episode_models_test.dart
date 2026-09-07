// test/data/subject/bangumi_episode_models_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BangumiEpisode', () {
    test('parses a real /v0/episodes data item', () {
      final json = {
        'airdate': '2023-09-29',
        'name': '冒険の終わり',
        'name_cn': '冒险结束',
        'duration': '00:26:00',
        'desc': '...',
        'ep': 1,
        'sort': 1,
        'id': 1227087,
        'subject_id': 400602,
        'comment': 297,
        'type': 0,
        'disc': 0,
        'duration_seconds': 1560,
      };

      final episode = BangumiEpisode.fromJson(json);

      expect(episode.id, 1227087);
      expect(episode.sort, 1);
      expect(episode.name, '冒険の終わり');
      expect(episode.nameCn, '冒险结束');
      expect(episode.airdate, '2023-09-29');
      expect(episode.type, 0);
    });

    test(
      'displayName prefers nameCn, falls back to name when nameCn is empty',
      () {
        const withCn = BangumiEpisode(
          id: 1,
          sort: 1,
          name: 'EN',
          nameCn: '中文',
          airdate: '',
          type: 0,
        );
        const withoutCn = BangumiEpisode(
          id: 2,
          sort: 2,
          name: 'EN Only',
          nameCn: '',
          airdate: '',
          type: 0,
        );

        expect(withCn.displayName, '中文');
        expect(withoutCn.displayName, 'EN Only');
      },
    );
  });

  group('BangumiEpisodesResponse', () {
    test('parses the {data,total,limit,offset} wrapper', () {
      final json = {
        'data': [
          {
            'airdate': '2023-09-29',
            'name': 'A',
            'name_cn': 'A_CN',
            'ep': 1,
            'sort': 1,
            'id': 1,
            'type': 0,
          },
        ],
        'total': 28,
        'limit': 1,
        'offset': 0,
      };

      final response = BangumiEpisodesResponse.fromJson(json);

      expect(response.data, hasLength(1));
      expect(response.data.single.id, 1);
      expect(response.total, 28);
    });
  });
}
