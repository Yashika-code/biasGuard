import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:biasguard_app/core/services/fairness_engine.dart';

void main() {
  test('Test Fairness Engine Demo CSV parsing', () {
    final csvContent = File('assets/demo/bihar_scholarship_2026.csv').readAsStringSync();
    final engine = FairnessEngine();
    
    // 1. Initial Parse via CsvToListConverter
    final rawData = engine.parseCsv(csvContent);
    print('Parsed Data Rows Length: ${rawData.length}');
    
    // 2. Full Metrics Run
    try {
      final results = engine.runFullMetrics(csvContent, null);
      print('Group Col Selected: ${results['group_col']}');
      print('Outcome Col Selected: ${results['outcome_col']}');
      print('Overall Pass Rate: ${results['overall_approval_rate']}');
    } catch (e) {
      print('runFullMetrics threw Exception: $e');
    }
  });

  test('Test Fairness Engine Loan CSV parsing', () {
    final csvContent = File('assets/demo/loan_application_demo.csv').readAsStringSync();
    final engine = FairnessEngine();
    
    // 1. Initial Parse via CsvToListConverter
    final rawData = engine.parseCsv(csvContent);
    print('Loan Parsed Data Rows Length: ${rawData.length}');
    
    // 2. Full Metrics Run
    try {
      final results = engine.runFullMetrics(csvContent, null);
      print('Loan Group Col Selected: ${results['group_col']}');
      print('Loan Outcome Col Selected: ${results['outcome_col']}');
    } catch (e) {
      print('Loan runFullMetrics threw Exception: $e');
    }
  });
}
