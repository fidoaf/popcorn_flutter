import 'dart:math';

import 'package:flutter/material.dart';
import 'package:popcorn_flutter/shared/core/model/paginator.dart';

class PaginatorView extends StatelessWidget {
  static const int _pageSize = 10;
  static const int _maxPages = 9;

  final int currentPage;
  final int totalCount;
  final void Function(int index) onPageChanged;
  const PaginatorView({super.key, required this.currentPage, required this.totalCount, required this.onPageChanged});

  int get totalPages => totalCount ~/ _pageSize;

  @override
  Widget build(BuildContext context) {
    final pagerSize = min(totalPages, _maxPages);
    final paginator = Paginator(currentPage: currentPage, totalPages: totalPages, maxPages: pagerSize);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: paginator.map<Widget>((page) {
            final isSelected = page == currentPage;
            return page == null
                ? const Text('...')
                : TextButton(
                    onPressed: () => isSelected ? null : onPageChanged(page),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(isSelected ? Theme.of(context).colorScheme.onSecondary : null),
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(fontWeight: isSelected ? FontWeight.w900 : null),
                      ),
                    ),
                    child: Text('${page + 1}'),
                  );
          }).toList(),
        ),
      ],
    );
  }
}
