import 'package:flutter/material.dart';
import 'package:popcorn_flutter/not_found/domain/not_found_page.dart';

class MaterialNotFoundPage extends StatelessWidget implements NotFoundPage {
  const MaterialNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('NOT FOUND!'),
      ),
    );
  }

  @override
  void goBack() {
    // TODO: implement goBack
  }
}
