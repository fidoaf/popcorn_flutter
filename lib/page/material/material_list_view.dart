import 'package:flutter/material.dart';

abstract class MaterialListView<X> extends StatefulWidget {
  const MaterialListView({super.key});

  Future<X> fetcher();
  Widget renderer(BuildContext context, X value);
  void onSuccessAction(BuildContext context, X value);
  void onErrorAction(BuildContext context);

  @override
  State<StatefulWidget> createState() => _MaterialListViewState();
}

class _MaterialListViewState extends State<MaterialListView> {
  late Future task;

  @override
  void initState() {
    task = widget.fetcher();
    task.then((value) {
      if (mounted) {
        if (value == null) {
          widget.onSuccessAction(context, value);
        } else {
          widget.onErrorAction(context);
        }
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: task,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return widget.renderer(context, snapshot.data);
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
