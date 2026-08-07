import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final channels = [
      _Channel('Amazon', Icons.shopping_cart, 'Connect Amazon SP-API'),
      _Channel('Flipkart', Icons.store, 'Connect Flipkart API'),
      _Channel('Meesho', Icons.storefront, 'Connect Meesho'),
      _Channel('Shopify', Icons.shopping_bag, 'Connect Shopify store'),
      _Channel('WooCommerce', Icons.web, 'Connect WooCommerce'),
      _Channel('Manual', Icons.edit_note, 'Create orders manually'),
    ];

    return ListView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      children: [
        const Text('Marketplace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Connect marketplaces to sync orders automatically.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final cross = c.maxWidth > 800 ? 3 : (c.maxWidth > 500 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemCount: channels.length,
            itemBuilder: (_, i) {
              final ch = channels[i];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${ch.name} connection wizard — next')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.accent.withOpacity(0.12),
                          child: Icon(ch.icon, color: AppColors.accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(ch.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(ch.subtitle,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class _Channel {
  final String name, subtitle;
  final IconData icon;
  const _Channel(this.name, this.icon, this.subtitle);
}