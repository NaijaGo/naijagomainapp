import 'app_network_image.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class VendorLogoEntry {
  const VendorLogoEntry({required this.id, required this.name, this.logoUrl});
  final String id;
  final String name;
  final String? logoUrl;

  /// Use only vendors represented by the existing public product catalogue.
  /// Never assign a product's vendor logo to a different selected seller.
  static List<VendorLogoEntry> fromProducts(Iterable<Product> products) {
    final vendors = <String, VendorLogoEntry>{};
    for (final product in products) {
      if (!product.isActive ||
          product.sellerType != 'vendor' ||
          !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(product.vendorId) ||
          (product.sellerId != null && product.sellerId != product.vendorId)) {
        continue;
      }
      final name = product.vendorBusinessName?.trim();
      final entry = VendorLogoEntry(
        id: product.vendorId,
        name: name?.isNotEmpty == true ? name! : product.sellerName,
        logoUrl: product.vendorBusinessLogoUrl,
      );
      final existing = vendors[entry.id];
      if (existing == null ||
          (existing.logoUrl?.isNotEmpty != true &&
              entry.logoUrl?.isNotEmpty == true)) {
        vendors[entry.id] = entry;
      }
    }
    return vendors.values.toList(growable: false);
  }
}

class VendorLogo extends StatelessWidget {
  const VendorLogo({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 48,
  });
  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(logoUrl ?? '');
    final valid =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    Widget fallback() => Center(
      child: Icon(
        Icons.storefront_outlined,
        color: AppTheme.forestGreen,
        size: size * .45,
      ),
    );
    return Semantics(
      image: true,
      label: '$name logo',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: valid
            ? AppNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.contain,
                placeholder: (_, _) => fallback(),
                errorWidget: (_, _, _) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

class VendorLogoStrip extends StatelessWidget {
  const VendorLogoStrip({
    super.key,
    required this.vendors,
    required this.onOpen,
  });
  final List<VendorLogoEntry> vendors;
  final ValueChanged<VendorLogoEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Shop by vendor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.secondaryBlack,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80 + MediaQuery.textScalerOf(context).scale(38),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: vendors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final vendor = vendors[index];
                return SizedBox(
                  width: 98,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('vendor-logo-${vendor.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onOpen(vendor),
                      child: Column(
                        children: [
                          VendorLogo(
                            name: vendor.name,
                            logoUrl: vendor.logoUrl,
                            size: 68,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vendor.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondaryBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
