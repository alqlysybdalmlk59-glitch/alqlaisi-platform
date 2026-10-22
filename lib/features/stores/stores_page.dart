import 'package:flutter/material.dart';

class StoresPage extends StatelessWidget {
  const StoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المتاجر'),
      ),
      body: const Center(child: Text('صفحة المتاجر')),
    );
  }
}
