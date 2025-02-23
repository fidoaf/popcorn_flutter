import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/shared/core/model/paginator.dart';

void main() {
  group('Paginator must', () {
    test('be empty when no parameters are given', () {
      assert(Paginator().equals(<int?>[]));
    });
    test('show one page when only is is provided', () {
      assert(Paginator(currentPage: 0, maxPages: 1, totalPages: 1).equals(<int?>[0]));
    });
    test('show both the initial and final page', () {
      assert(Paginator(currentPage: 0, maxPages: 2, totalPages: 2).equals(<int?>[0, 1]));
      assert(Paginator(currentPage: 0, maxPages: 3, totalPages: 10).equals(<int?>[0, null, 9]));
    });

    test('show the initial, current and final page', () {
      assert(Paginator(currentPage: 0, maxPages: 3, totalPages: 3).equals(<int?>[0, 1, 2]));
      assert(Paginator(currentPage: 1, maxPages: 3, totalPages: 3).equals(<int?>[0, 1, 2]));
      assert(Paginator(currentPage: 2, maxPages: 3, totalPages: 3).equals(<int?>[0, 1, 2]));
    });

    test('show current page and surrounding indexes', () {
      assert(Paginator(currentPage: 0, maxPages: 9, totalPages: 11).equals(<int?>[0, 1, 2, 3, 4, 5, 6, null, 10]));
      assert(Paginator(currentPage: 5, maxPages: 9, totalPages: 11).equals(<int?>[0, null, 3, 4, 5, 6, 7, null, 10]));
      assert(Paginator(currentPage: 10, maxPages: 9, totalPages: 11).equals(<int?>[0, null, 4, 5, 6, 7, 8, 9, 10]));
    });

    test('throw an error when any parameter is negative', () {
      expect(() => Paginator(currentPage: -1), throwsA(const TypeMatcher<ArgumentError>()));
      expect(() => Paginator(maxPages: -1), throwsA(const TypeMatcher<ArgumentError>()));
      expect(() => Paginator(totalPages: -1), throwsA(const TypeMatcher<ArgumentError>()));
    });

    test('throw an error when the current page is outside the range', () {
      expect(() => Paginator(currentPage: 10, maxPages: 1, totalPages: 1), throwsA(const TypeMatcher<ArgumentError>()));
    });
  });
}
