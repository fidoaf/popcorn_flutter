import 'package:flutter/material.dart';

class MaterialLandingPage extends StatelessWidget {
  const MaterialLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
