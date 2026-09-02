import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/subject_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _detail = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: [],
  selfRating: SelfRating(score: 0, tags: [], isPrivate: false),
);

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  group('SubjectDetailController', () {
    test('returns the detail from SubjectApi.getSubject', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);

      final result = await container.read(subjectDetailControllerProvider(subjectId: 1).future);

      expect(result.nameCn, 'A-cn');
    });

    test('propagates a getSubject failure', () async {
      when(() => api.getSubject(1)).thenThrow(Exception('network error'));

      await expectLater(
        container.read(subjectDetailControllerProvider(subjectId: 1).future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SubjectCharacters', () {
    test('returns the list from SubjectApi.getCharacters', () async {
      const character = RelatedCharacter(index: 0, character: CharacterInfo(name: 'X'), role: 1);
      when(() => api.getCharacters(1)).thenAnswer((_) async => [character]);

      final result = await container.read(subjectCharactersProvider(subjectId: 1).future);

      expect(result.single.character.name, 'X');
    });

    test('propagates a getCharacters failure independently', () async {
      when(() => api.getCharacters(1)).thenThrow(Exception('cast unavailable'));

      await expectLater(
        container.read(subjectCharactersProvider(subjectId: 1).future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SubjectStaff', () {
    test('returns the list from SubjectApi.getStaff', () async {
      const staff = StaffMember(name: 'Y');
      when(() => api.getStaff(1)).thenAnswer((_) async => [staff]);

      final result = await container.read(subjectStaffProvider(subjectId: 1).future);

      expect(result.single.name, 'Y');
    });

    test('propagates a getStaff failure independently', () async {
      when(() => api.getStaff(1)).thenThrow(Exception('staff unavailable'));

      await expectLater(
        container.read(subjectStaffProvider(subjectId: 1).future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
