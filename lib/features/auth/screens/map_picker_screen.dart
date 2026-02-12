import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';

class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(22.5726, 88.3639); // Default: Kolkata
  bool _isLoadingLocation = true;
  bool _isSearchingLocation = false;
  bool _isResolvingSelection = false;
  bool _isFetchingCurrentAddress = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Get user's current device location and update the map camera
  Future<void> _getCurrentLocation() async {
    try {
      Position? position = await _determinePosition();
      if (position == null) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<Position?> _determinePosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Error determining position: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to fetch current location'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
      return null;
    }
  }

  /// Handle camera move - update center position
  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentPosition = position.target;
    });
  }

  /// Confirm selection, reverse geocode, and return the full address payload
  Future<void> _confirmSelection() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isResolvingSelection = true;
    });

    try {
      final data = await _buildAddressPayload(_currentPosition);
      if (!mounted) return;
      context.pop(data);
    } catch (e) {
      debugPrint('Error confirming selection: $e');
      if (!mounted) return;
      setState(() {
        _isResolvingSelection = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch address for the selected location'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _buildAddressPayload(LatLng position) async {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      throw Exception('No address found');
    }

    final place = placemarks.first;
    final building = (place.subThoroughfare ?? '').isNotEmpty
        ? place.subThoroughfare!
        : (place.name ?? '');
    final street = (place.street ?? '').isNotEmpty
        ? place.street!
        : (place.thoroughfare ?? '');
    final localityParts =
        [
              place.locality,
              place.administrativeArea,
              place.subAdministrativeArea,
              place.country,
            ]
            .where((part) => part != null && part!.isNotEmpty)
            .map((part) => part!)
            .toList();

    final fullAddressParts = [
      if (street.isNotEmpty) street,
      ...localityParts,
      if ((place.postalCode ?? '').isNotEmpty) place.postalCode!,
    ];

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'building': building,
      'street': street.isNotEmpty ? street : localityParts.join(', '),
      'pincode': place.postalCode ?? '',
      'fullAddress': fullAddressParts.join(', '),
    };
  }

  Future<void> _searchForLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearchingLocation = true;
    });

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        throw Exception('Location not found');
      }

      final location = locations.first;
      final target = LatLng(location.latitude, location.longitude);
      setState(() {
        _currentPosition = target;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (e) {
      debugPrint('Error searching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to find that address. Try a different search.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
        });
      }
    }
  }

  Future<void> _useCurrentAddress() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isFetchingCurrentAddress = true;
    });

    try {
      final position = await _determinePosition();
      if (position == null) {
        if (mounted) {
          setState(() {
            _isFetchingCurrentAddress = false;
          });
        }
        return;
      }

      final latLng = LatLng(position.latitude, position.longitude);
      final data = await _buildAddressPayload(latLng);
      if (!mounted) return;
      context.pop(data);
    } catch (e) {
      debugPrint('Error getting current address: $e');
      if (!mounted) return;
      setState(() {
        _isFetchingCurrentAddress = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch your current address'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services to use the map picker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is required to show your current location on the map. Please grant permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: Colors.white,
      //   elevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
      //     onPressed: () => context.pop(),
      //   ),
      //   title: const Text(
      //     'Select Location',
      //     style: TextStyle(
      //       color: AppColors.textPrimary,
      //       fontWeight: FontWeight.w600,
      //       fontFamily: 'Lato',
      //     ),
      //   ),
      // ),
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_isLoadingLocation) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition, 15),
                  );
                }
              },
              onCameraMove: _onCameraMove,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onTap: (_) => FocusScope.of(context).unfocus(),
            ),
        
            // Center Pin Marker (fixed at center)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_pin,
                    size: AppSizes.mapPinSize,
                    color: AppColors.errorColor,
                  ),
                  Container(
                    width: AppSizes.mapPinDotSize,
                    height: AppSizes.mapPinDotSize,
                    decoration: const BoxDecoration(
                      color: AppColors.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
        
            // Search bar and current address button
            Positioned(
              left: AppSizes.spacing16,
              right: AppSizes.spacing16,
              top: AppSizes.spacing16,
              child: SafeArea(
                child: Column(
                  children: [
                    Material(
                      elevation: AppSizes.spacing4,
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchForLocation(),
                        decoration: InputDecoration(
                          hintText: AppStrings.searchLocationHint,
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radius4
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.borderColor,
                              width: AppSizes.borderMedium,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radius4
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: AppSizes.borderMedium,
                            ),
                          ),
                          suffixIcon: _isSearchingLocation
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSizes.radius8),
                                  child: SizedBox(
                                    width: AppSizes.scaleLoading,
                                    height: AppSizes.scaleLoading,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    color: AppColors.primaryGreen,
                                  ),
                                  onPressed: _searchForLocation,
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacing16,
                            vertical: AppSizes.spacing12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing12),
                    PrimaryButton(
                      height: AppSizes.buttonHeight,
                      text: AppStrings.useCurrentAddress,
                      onPressed: _isFetchingCurrentAddress
                          ? null
                          : _useCurrentAddress,
                      isLoading: _isFetchingCurrentAddress,
                      backgroundColor: Colors.white,
                      textColor: AppColors.primaryGreen,
                      borderColor: AppColors.primaryGreen,
                      borderWidth: AppSizes.borderThin,
                    ),
                  ],
                ),
              ),
            ),
        
            // Confirm Button at Bottom
            Positioned(
              left: AppSizes.spacing16,
              right: AppSizes.spacing16,
              bottom: AppSizes.spacing16,
              child: Container(
                padding: const EdgeInsets.all(AppSizes.spacing20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: AppSizes.opacity10),
                      blurRadius: AppSizes.shadowBlur10,
                      offset: Offset(0, AppSizes.spacing4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Move the map to select your delivery location',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing12),
                    PrimaryButton(
                      text: 'Confirm Location',
                      onPressed: _isResolvingSelection ? null : _confirmSelection,
                      textColor: Colors.white,
                      height: AppSizes.buttonHeightMedium,
                      isLoading: _isResolvingSelection,
                    ),
                  ],
                ),
              ),
            ),
        
            // Loading indicator
            if (_isLoadingLocation)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
