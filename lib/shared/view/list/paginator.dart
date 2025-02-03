import 'package:flutter/material.dart';

class Paginator extends StatelessWidget {
  static const int _pageSize = 10;

  final int currentPage;
  final int totalCount;
  final void Function(int index) onPageChanged;
  const Paginator({super.key, required this.currentPage, required this.totalCount, required this.onPageChanged});

  int get numPages => totalCount ~/ _pageSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        numPages,
        (i) => TextButton(
          onPressed: () => onPageChanged(i),
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontWeight: i == currentPage ? FontWeight.bold : null),
            ),
          ),
          child: Text('${i + 1}'),
        ),
      ),
    );
  }
}
