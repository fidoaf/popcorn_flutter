import 'dart:math';

import 'package:flutter/foundation.dart';

class Paginator {
  final int currentPage;
  final int totalPages;
  final int maxPages;

  final List<int?> _data;

  Paginator({
    this.currentPage = 0,
    this.totalPages = 0,
    this.maxPages = 0,
  }) : _data = _generate(currentPage: currentPage, maxSlots: maxPages, totalPages: totalPages);

  static List<int?> _generate({
    required int currentPage,
    required int totalPages,
    required int maxSlots,
    int initalPage = 0,
  }) {
    final data = <int?>[];

    /// Validation
    if (currentPage < 0 || totalPages < 0 || maxSlots < 0 || initalPage < 0) {
      throw ArgumentError('Index must be a positive value');
    } else {
      if (totalPages > 0) {
        if (currentPage > totalPages) {
          throw ArgumentError('Out of range current page');
        } else {
          final finalPage = max(totalPages - 1, 0);
          final fixedPlaces = (currentPage == initalPage ? 0 : 1) + 1 + (currentPage == finalPage ? 0 : 1);
          if (fixedPlaces > maxSlots) {
            throw ArgumentError('Paginator cannot display all the pages with size $maxSlots');
          } else {
            // Base case: the paginator fits in the alloted space
            data.addAll(List<int>.generate(totalPages, (index) => initalPage + index));

            if (maxSlots < totalPages) {
              // If paginator does not fit, we need to include spacing with ellipsis
              bool hiddenOnLeft = false, hiddenOnRight = false;
              while (maxSlots < data.length + (hiddenOnLeft ? 1 : 0) + (hiddenOnRight ? 1 : 0)) {
                final currentIndex = data.indexOf(currentPage);
                final lastIndex = data.length - 1;
                final exceedingLeft = (currentIndex - initalPage).abs();
                final exceedingRight = (lastIndex - currentIndex).abs();
                final int refIndex;
                if (exceedingLeft < exceedingRight) {
                  refIndex = lastIndex - 1;
                  hiddenOnRight = true;
                } else {
                  refIndex = initalPage + 1;
                  hiddenOnLeft = true;
                }
                data.removeAt(refIndex);
              }
              if (hiddenOnLeft) data.insert(1, null);
              if (hiddenOnRight) data.insert(data.length - 1, null);
            }
          }
        }
      }
    }

    return data;
  }

  bool equals(List<int?> data) {
    return listEquals(data, _data);
  }

  Iterable<T> map<T>(T Function(int?) toElement) {
    return _data.map(toElement);
  }
}
