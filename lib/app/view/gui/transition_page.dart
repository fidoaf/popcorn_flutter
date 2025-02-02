import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class TransitionPage extends StatefulWidget {
  final Widget destination;
  final int minDelay;
  const TransitionPage({super.key, required this.destination, this.minDelay = 0});

  @override
  TransitionPageState createState() => TransitionPageState();
}

class TransitionPageState extends State<TransitionPage> {
  void _foo() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => widget.destination));
  }

  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(seconds: widget.minDelay), _foo);
    });
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: LoadingWidget(),
    );
  }
}
