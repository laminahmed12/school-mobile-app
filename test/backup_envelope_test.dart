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
