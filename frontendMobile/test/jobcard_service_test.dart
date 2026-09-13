import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/models/user_session.dart';
import 'package:fbs/services/jobcard_service.dart';

import 'test_api_helpers.dart';

void main() {
  initTestApi();

  setUp(() {
    UserSession.rights = ['jobs.manage'];
    UserSession.role = UserRole.admin;
  });

  group('JobcardService', () {
    test('fetchJobs laai werksopdragte suksesvol', () async {
      mockAdapter.onGet('/job', (server) {
        server.reply(200, [
          {
            'jobcard_id': 1,
            'job_desc': 'Herstel kraan',
            'job_status': 'OPEN',
          },
          {
            'jobcard_id': 2,
            'job_desc': 'Skoonmaak',
            'job_status': 'WAIT',
          },
        ]);
      });

      await JobcardService.fetchJobs();

      expect(JobcardService.jobcardsNotifier.value.length, 2);
      expect(JobcardService.jobcardsNotifier.value[0].description,
          'Herstel kraan');
    });

    test('createJob skep kaart en voeg by lys', () async {
      mockAdapter.onGet('/job', (server) {
        server.reply(200, <dynamic>[]);
      });
      mockAdapter.onPost('/job', (server) {
        server.reply(201, {
          'jobcard_id': 50,
          'job_desc': 'Nuwe taak',
          'job_status': 'OPEN',
        });
      });

      await JobcardService.fetchJobs();
      final result = await JobcardService.createJob({'job_desc': 'Nuwe taak'});

      expect(result, isNotNull);
      expect(result!.id, 50);
      expect(JobcardService.jobcardsNotifier.value.length, 1);
    });

    test('updateJob dateer kaart in lys', () async {
      mockAdapter.onGet('/job', (server) {
        server.reply(200, [
          {
            'jobcard_id': 1,
            'job_desc': 'Ou beskrywing',
            'job_status': 'OPEN',
          },
        ]);
      });
      mockAdapter.onPatch('/job/1', (server) {
        server.reply(200, {
          'jobcard_id': 1,
          'job_desc': 'Nuwe beskrywing',
          'job_status': 'IN_PROGRESS',
        });
      });

      await JobcardService.fetchJobs();
      final result =
          await JobcardService.updateJob(1, {'job_desc': 'Nuwe beskrywing'});

      expect(result, isNotNull);
      expect(JobcardService.jobcardsNotifier.value[0].description,
          'Nuwe beskrywing');
    });

    test('deleteJob verwyder kaart uit lys', () async {
      mockAdapter.onGet('/job', (server) {
        server.reply(200, [
          {
            'jobcard_id': 1,
            'job_desc': 'Taak',
            'job_status': 'OPEN',
          },
        ]);
      });
      mockAdapter.onDelete('/job/1', (server) {
        server.reply(204, null);
      });

      await JobcardService.fetchJobs();
      final result = await JobcardService.deleteJob(1);

      expect(result, isTrue);
      expect(JobcardService.jobcardsNotifier.value, isEmpty);
    });

    test('requestCompletion gee true by sukses', () async {
      mockAdapter.onPost('/job/1/complete-request', (server) {
        server.reply(200, {});
      });

      final result = await JobcardService.requestCompletion(1);
      expect(result, isTrue);
    });
  });
}
