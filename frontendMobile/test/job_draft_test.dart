import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/models/job_draft.dart';

void main() {
  group('JobDraft model', () {
    test('fromJson parses all read fields', () {
      final draft = JobDraft.fromJson({
        'draft_id': 7,
        'description': 'Projektor wys nie beeld nie.',
        'cleaned_description': 'Projektor lewer geen beeld nie.',
        'title': 'Projektor werk nie',
        'work_instruction': 'Vervang die HDMI-kabel.',
        'suggested_type': 'REPAIR',
        'suggested_priority': 'HIGH',
        'failure_category': 'electrical',
        'language': 'af',
        'ai_status': 'ok',
        'source': 'manual',
        'status': 'draft',
        'review_note': '',
        'resolved_asset_id': 12,
        'resolved_room_id': 3,
        'duplicate_of': null,
        'user_id': 2,
        'reviewer_id': null,
        'created_at': '2026-08-11T10:30:00',
        'updated_at': '2026-08-11T10:30:00',
        'reviewed_at': null,
      });

      expect(draft.draftId, 7);
      expect(draft.description, 'Projektor wys nie beeld nie.');
      expect(draft.cleanedDescription, 'Projektor lewer geen beeld nie.');
      expect(draft.title, 'Projektor werk nie');
      expect(draft.workInstruction, 'Vervang die HDMI-kabel.');
      expect(draft.suggestedType, 'REPAIR');
      expect(draft.suggestedPriority, 'HIGH');
      expect(draft.failureCategory, 'electrical');
      expect(draft.aiStatus, 'ok');
      expect(draft.source, 'manual');
      expect(draft.status, 'draft');
      expect(draft.resolvedAssetId, 12);
      expect(draft.resolvedRoomId, 3);
      expect(draft.userId, 2);
      expect(draft.reviewerId, isNull);
      expect(draft.createdAt, isNotNull);
      expect(draft.updatedAt, isNotNull);
      expect(draft.reviewedAt, isNull);
    });

    test('label getters map to Afrikaans', () {
      final draft = JobDraft.fromJson({
        'draft_id': 1,
        'description': 'x',
        'cleaned_description': '',
        'title': '',
        'work_instruction': '',
        'suggested_type': 'MAINTENANCE',
        'suggested_priority': 'LOW',
        'failure_category': '',
        'language': 'af',
        'ai_status': 'degraded',
        'source': 'auto',
        'status': 'approved',
        'review_note': '',
        'resolved_asset_id': null,
        'resolved_room_id': null,
        'duplicate_of': null,
        'user_id': 1,
        'reviewer_id': 2,
        'created_at': null,
        'updated_at': null,
        'reviewed_at': '2026-08-11T11:00:00',
      });

      expect(draft.statusLabel, 'Goedgekeur');
      expect(draft.typeLabel, 'Onderhoud');
      expect(draft.priorityLabel, 'Laag');
      expect(draft.reviewerId, 2);
      expect(draft.reviewedAt, isNotNull);
    });

    test('copyWith keeps unchanged fields', () {
      final draft = JobDraft.fromJson({
        'draft_id': 3,
        'description': 'd',
        'cleaned_description': '',
        'title': '',
        'work_instruction': '',
        'suggested_type': 'REPAIR',
        'suggested_priority': 'MEDIUM',
        'failure_category': '',
        'language': 'af',
        'ai_status': 'ok',
        'source': 'manual',
        'status': 'draft',
        'review_note': '',
        'resolved_asset_id': null,
        'resolved_room_id': null,
        'duplicate_of': null,
        'user_id': 1,
        'reviewer_id': null,
        'created_at': null,
        'updated_at': null,
        'reviewed_at': null,
      });

      final updated =
          draft.copyWith(status: 'rejected', reviewNote: 'Duplikaat');

      expect(updated.draftId, 3);
      expect(updated.status, 'rejected');
      expect(updated.reviewNote, 'Duplikaat');
      expect(updated.suggestedType, 'REPAIR');
      expect(updated.suggestedPriority, 'MEDIUM');
    });

    test('JobDraftDetail.fromJson parses candidates via super.fromJson', () {
      final detail = JobDraftDetail.fromJson({
        'draft_id': 5,
        'description': 'd',
        'cleaned_description': '',
        'title': '',
        'work_instruction': '',
        'suggested_type': 'REPAIR',
        'suggested_priority': 'MEDIUM',
        'failure_category': '',
        'language': 'af',
        'ai_status': 'ok',
        'source': 'manual',
        'status': 'draft',
        'review_note': '',
        'resolved_asset_id': null,
        'resolved_room_id': null,
        'duplicate_of': null,
        'user_id': 1,
        'reviewer_id': null,
        'created_at': null,
        'updated_at': null,
        'reviewed_at': null,
        'asset_candidates': [
          {'id': 12, 'name': 'Projektor 4k', 'detail': 'Lokaal A-12'},
          {'id': 13, 'name': 'Laserstraal', 'detail': 'Lokaal B-01'},
        ],
        'room_candidates': [
          {'id': 3, 'name': 'Lesinglokaal A', 'detail': '1ste vloer'},
        ],
      });

      expect(detail.draftId, 5);
      expect(detail.suggestedType, 'REPAIR');
      expect(detail.assetCandidates.length, 2);
      expect(detail.assetCandidates.first.id, 12);
      expect(detail.assetCandidates.first.name, 'Projektor 4k');
      expect(detail.assetCandidates.first.detail, 'Lokaal A-12');
      expect(detail.roomCandidates.length, 1);
      expect(detail.roomCandidates.first.name, 'Lesinglokaal A');
      expect(detail.roomCandidates.first.detail, '1ste vloer');
      expect(detail.statusLabel, 'Wag');
    });

    test('fromJson falls back gracefully on missing fields', () {
      final draft = JobDraft.fromJson({
        'draft_id': 9,
        'description': 'n',
        'user_id': 4,
      });

      expect(draft.draftId, 9);
      expect(draft.userId, 4);
      expect(draft.description, 'n');
      expect(draft.title, '');
      expect(draft.suggestedType, 'REPAIR');
      expect(draft.suggestedPriority, 'MEDIUM');
      expect(draft.status, 'draft');
      expect(draft.aiStatus, 'ok');
      expect(draft.source, 'manual');
      expect(draft.resolvedAssetId, isNull);
      expect(draft.createdAt, isNull);
    });
  });
}
