import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/models/report.dart';
import 'package:fbs/services/report_service.dart';

import 'test_api_helpers.dart';

Report _report(String id) => Report(
      id: id,
      assetId: '',
      location: '',
      title: 'Fout $id',
      description: 'Beskrywing',
      category: 'Onderhoud',
      priority: 'Medium',
      phase: 'Oop',
      user: 'Tester',
      timestamp: DateTime(2025),
    );

void main() {
  initTestApi();

  group('ReportService', () {
    test('fetchReports laai verslae suksesvol', () async {
      mockAdapter.onGet('/fault', (server) {
        server.reply(200, [
          {
            'fault_id': 'F001',
            'fault_description': 'Lekkende kraan',
            'fault_status': 'open',
          },
          {
            'fault_id': 'F002',
            'fault_description': 'Gebreekte venster',
            'fault_status': 'closed',
          },
        ]);
      });

      await ReportService.fetchReports();

      expect(ReportService.reportsNotifier.value.length, 2);
      expect(ReportService.isLoadingNotifier.value, isFalse);
    });

    test('fetchReports skakel isLoading af selfs op fout', () async {
      mockAdapter.onGet('/fault', (server) {
        server.reply(500, {'detail': 'error'});
      });

      await ReportService.fetchReports();

      expect(ReportService.isLoadingNotifier.value, isFalse);
      expect(ReportService.lastError, isNotNull);
    });

    test('fetchReports slaan slegte items oor', () async {
      mockAdapter.onGet('/fault', (server) {
        server.reply(200, [
          {
            'fault_id': 'F001',
            'fault_description': 'Lekkende kraan',
            'fault_status': 'open',
          },
          {'broken': true},
        ]);
      });

      await ReportService.fetchReports();

      expect(ReportService.reportsNotifier.value.length, 1);
    });

    test('addReport skep verslag en voeg by lys', () async {
      mockAdapter.onGet('/fault', (server) {
        server.reply(200, <dynamic>[]);
      });
      mockAdapter.onPost('/fault', (server) {
        server.reply(201, {
          'fault_id': 'F100',
          'fault_description': 'Nuwe fout',
          'fault_status': 'open',
        });
      });

      await ReportService.fetchReports();
      final result = await ReportService.addReport(_report('new'));

      expect(result, isNotNull);
      expect(result!.id, 'F100');
      expect(ReportService.reportsNotifier.value.length, 1);
    });

    test('deleteReport verwyder verslag uit lys', () async {
      mockAdapter.onGet('/fault', (server) {
        server.reply(200, [
          {
            'fault_id': 'F001',
            'fault_description': 'Fout',
            'fault_status': 'open',
          },
        ]);
      });
      mockAdapter.onDelete('/fault/F001', (server) {
        server.reply(204, null);
      });

      await ReportService.fetchReports();
      final result = await ReportService.deleteReport('F001');

      expect(result, isTrue);
      expect(ReportService.reportsNotifier.value, isEmpty);
    });

    test('deleteReport behou oorspronklik toegevoegde verslag', () async {
      mockAdapter.onGet('/fault', (server) {
        server.reply(200, <dynamic>[]);
      });
      var addCount = 0;
      mockAdapter.onPost('/fault', (server) {
        server.reply(201, (options) {
          addCount++;
          final id = addCount == 1 ? 'F200' : 'F300';
          return {
            'fault_id': id,
            'fault_description': id == 'F200' ? 'Verslag A' : 'Verslag B',
            'fault_status': 'open',
          };
        });
      });
      mockAdapter.onDelete('/fault/F300', (server) {
        server.reply(204, null);
      });

      await ReportService.fetchReports();
      final first = await ReportService.addReport(_report('A'));
      final second = await ReportService.addReport(_report('B'));
      expect(first!.id, 'F200');
      expect(second!.id, 'F300');

      final deleted = await ReportService.deleteReport('F300');
      expect(deleted, isTrue);

      final ids = ReportService.reportsNotifier.value.map((r) => r.id).toList();
      expect(ids, contains('F200'));
      expect(ids, isNot(contains('F300')));
    });
  });
}
