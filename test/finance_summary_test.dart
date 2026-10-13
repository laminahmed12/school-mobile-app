import 'package:flutter_test/flutter_test.dart';
import 'package:lamin_school/finance_summary.dart';

void main() {
  group('calculateStudentFinancialTotals', () {
    test('allocations reduce only the obligation they target', () {
      final totals = calculateStudentFinancialTotals(
        fees: [
          {'id': 'fee-1', 'total_fee': 100, 'discount': 10},
        ],
        payments: [
          {'id': 'pay-1', 'amount': 20, 'fee_assessment_id': 'fee-1'},
        ],
        openingBalances: [
          {'id': 'opening-1', 'amount': 60},
        ],
        allocationRows: [
          {
            'payment_id': 'pay-1',
            'fee_assessment_id': 'fee-1',
            'opening_balance_id': null,
            'amount': 20,
            'reversed_at': null,
          },
        ],
      );

      expect(totals['fees'], 100);
      expect(totals['discount'], 10);
      expect(totals['opening_balance'], 60);
      expect(totals['paid'], 20);
      expect(totals['remaining'], 130);
    });

    test('payment allocated to opening balance does not reduce unrelated fees', () {
      final totals = calculateStudentFinancialTotals(
        fees: [
          {'id': 'fee-1', 'total_fee': 100, 'discount': 0},
        ],
        payments: [
          {'id': 'pay-1', 'amount': 30, 'fee_assessment_id': 'fee-1'},
        ],
        openingBalances: [
          {'id': 'opening-1', 'amount': 50},
        ],
        allocationRows: [
          {
            'payment_id': 'pay-1',
            'fee_assessment_id': null,
            'opening_balance_id': 'opening-1',
            'amount': 30,
            'reversed_at': null,
          },
        ],
      );

      expect(totals['paid'], 30);
      expect(totals['remaining'], 120);
    });

    test('legacy payment reduces only its explicitly linked fee assessment', () {
      final totals = calculateStudentFinancialTotals(
        fees: [
          {'id': 'fee-1', 'total_fee': 100, 'discount': 0},
          {'id': 'fee-2', 'total_fee': 80, 'discount': 0},
        ],
        payments: [
          {'id': 'legacy-1', 'amount': 25, 'fee_assessment_id': 'fee-1'},
        ],
        openingBalances: [],
        allocationRows: [],
      );

      expect(totals['paid'], 25);
      expect(totals['remaining'], 155);
    });

    test('reversed allocation history prevents legacy fallback double counting', () {
      final totals = calculateStudentFinancialTotals(
        fees: [
          {'id': 'fee-1', 'total_fee': 100, 'discount': 0},
        ],
        payments: [
          {'id': 'pay-1', 'amount': 20, 'fee_assessment_id': 'fee-1'},
        ],
        openingBalances: [],
        allocationRows: [
          {
            'payment_id': 'pay-1',
            'fee_assessment_id': 'fee-1',
            'opening_balance_id': null,
            'amount': 20,
            'reversed_at': '2026-10-13T00:00:00Z',
          },
        ],
      );

      expect(totals['paid'], 0);
      expect(totals['remaining'], 100);
    });

    test('remaining debt never becomes negative from excess applied amounts', () {
      final totals = calculateStudentFinancialTotals(
        fees: [
          {'id': 'fee-1', 'total_fee': 10, 'discount': 0},
        ],
        payments: [],
        openingBalances: [],
        allocationRows: [
          {
            'payment_id': 'pay-1',
            'fee_assessment_id': 'fee-1',
            'opening_balance_id': null,
            'amount': 25,
            'reversed_at': null,
          },
        ],
      );

      expect(totals['remaining'], 0);
      expect(totals['paid'], 25);
    });
  });
}
