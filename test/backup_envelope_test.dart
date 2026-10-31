import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/backup_service.dart';

void main() {
  const schoolId = 'school-a';
  Map<String, dynamic> validEnvelope() => {
        'format': 'lamin-school-backup',
        'version': 2,
        'school_id': schoolId,
        'data': {
          'format': 'lamin-school-backup-v2',
          'school_filter': schoolId,
          'students': <dynamic>[],
        },
      };

  group('validateBackupEnvelope', () {
    test('accepts a matching school and payload', () {
      final result = BackupService.validateBackupEnvelope(
        validEnvelope(),
        expectedSchoolId: schoolId,
      );
      expect(result['school_id'], schoolId);
      expect(result['data']['school_filter'], schoolId);
    });

    test('accepts a cache-only snapshot for the current school', () {
      final backup = validEnvelope();
      backup['data'] = {
        'format': 'lamin-school-backup-v2',
        'school_filter': schoolId,
        'local_cache_snapshot': true,
        'local_cache_version': 1,
        'local_user_id': 'user-a',
        'local_cache': <String, String>{},
        'pending_offline_operations': <dynamic>[],
      };
      final result = BackupService.validateBackupEnvelope(
        backup,
        expectedSchoolId: schoolId,
      );
      expect(result['data']['local_cache_snapshot'], isTrue);
    });

    test('rejects incomplete cache-only snapshots', () {
      final backup = validEnvelope();
      backup['data'] = {
        'format': 'lamin-school-backup-v2',
        'school_filter': schoolId,
        'local_cache_snapshot': true,
        'local_cache_version': 1,
        'local_user_id': 'user-a',
        'pending_offline_operations': <dynamic>[],
      };
      expect(
        () => BackupService.validateBackupEnvelope(
          backup,
          expectedSchoolId: schoolId,
        ),
        throwsException,
      );
    });

    test('rejects an envelope belonging to another school', () {
      expect(
        () => BackupService.validateBackupEnvelope(
          {...validEnvelope(), 'school_id': 'school-b'},
          expectedSchoolId: schoolId,
        ),
        throwsException,
      );
    });

    test('rejects a payload with a mismatched tenant filter', () {
      final backup = validEnvelope();
      backup['data']['school_filter'] = 'school-b';
      expect(
        () => BackupService.validateBackupEnvelope(
          backup,
          expectedSchoolId: schoolId,
        ),
        throwsException,
      );
    });

    test('rejects unsupported or incomplete backup formats', () {
      expect(
        () => BackupService.validateBackupEnvelope(
          {...validEnvelope(), 'version': 99},
          expectedSchoolId: schoolId,
        ),
        throwsException,
      );
      expect(
        () => BackupService.validateBackupEnvelope(
          {...validEnvelope(), 'data': <String, dynamic>{}},
          expectedSchoolId: schoolId,
        ),
        throwsException,
      );
    });
  });
}
