import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';

class LocationViewSheet extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;

  const LocationViewSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final position = LatLng(latitude, longitude);

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
              child: Text(
                'Your Delivery Location',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: position,
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('user_location'),
                      position: position,
                      infoWindow: InfoWindow(title: address),
                    ),
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
              ),
            ),
            // Address bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.spacing16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primaryGreen,
                    size: AppSizes.icon20,
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.medium,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}