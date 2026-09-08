import 'package:flutter/material.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({
    super.key,
    this.initialProductId = '',
  });

  final String initialProductId;
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Marketplace'),
      ),
    );
  }
}
