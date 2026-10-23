import 'app_network_image.dart';
import 'package:flutter/material.dart';
import '../models/home_carousel_slide.dart';
import '../services/deals_service.dart';
import '../screens/Main/deals_screen.dart';
import '../theme/app_theme.dart';

/// The home promotion is an entrance only. Deals load after opening the page.
class DealsHomeSection extends StatelessWidget {
  const DealsHomeSection({
    super.key,
    this.refreshToken = 0,
    this.service,
    this.bannerSlide,
  });
  final int refreshToken;
  final DealsService? service;
  final HomeCarouselSlide? bannerSlide;
  static const defaultImage = 'assets/naijago-deals-banner.png';

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(defaultImage, fit: BoxFit.contain);
    final slide = bannerSlide;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Semantics(
        label: 'NaijaGo Deals. Browse deals',
        button: true,
        child: Material(
          color: AppTheme.deepForest,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('open-naijago-deals'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DealsScreen(service: service),
              ),
            ),
            child: AspectRatio(
              aspectRatio: 2.6,
              child: ExcludeSemantics(
                child: slide?.isRemoteImage == true
                    ? AppNetworkImage(
                        imageUrl: slide!.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => fallback(),
                        errorWidget: (_, _, _) => fallback(),
                      )
                    : fallback(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
