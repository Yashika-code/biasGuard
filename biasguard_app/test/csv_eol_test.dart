import 'package:flutter_test/flutter_test.dart';
import 'package:biasguard_app/core/services/fairness_engine.dart';
import 'package:csv/csv.dart';

void main() {
  test('Test string with only \\n', () {
    final csv = "name,age\nAlice,20\nBob,30";
    final normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    expect(rows.length, 3);
  });
  
  test('Test string with \\r\\n', () {
    final csv = "name,age\r\nAlice,20\r\nBob,30";
    final normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    expect(rows.length, 3);
  });

  test('Test string with only \\r', () {
    final csv = "name,age\rAlice,20\rBob,30";
    final normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    expect(rows.length, 3);
  });
}
