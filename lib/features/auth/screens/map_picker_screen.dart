import 'dart:async';

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

class _LocationSearchSuggestion {
  const _LocationSearchSuggestion({
    required this.primaryText,
    required this.secondaryText,
    required this.position,
  });

  final String primaryText;
  final String secondaryText;
  final LatLng position;

  String get fullLabel =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';
}

class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  static const int _minimumSearchQueryLength = 3;
  static const int _maxSearchSuggestions = 5;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 400);

  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(22.5726, 88.3639); // Default: Kolkata
  bool _isLoadingLocation = true;
  bool _isSearchingLocation = false;
  bool _isResolvingSelection = false;
  bool _isFetchingCurrentAddress = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<_LocationSearchSuggestion> _searchSuggestions = const [];
  bool _isLoadingSuggestions = false;
  bool _hasFetchedSuggestions = false;
  bool _showSuggestionList = false;
  int _searchSuggestionRequestId = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
    _hideSuggestions();
    setState(() {
      _isResolvingSelection = true;
    });

    try {
      final data = await _buildAddressPayload(_currentPosition);
      if (!mounted) return;
      print(" address is ${data.toString()}");
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
    
    print("full address is ${placemarks.toString()}");
    final place = placemarks.first;
    final building = (place.subThoroughfare ?? '').isNotEmpty
        ? place.subThoroughfare!
        : (place.name ?? '');
    // final street = (place.street ?? '').isNotEmpty
    //     ? place.street!
    //     : (place.thoroughfare ?? '');
    // final localityParts = [
    //   place.locality,
    //   place.administrativeArea,
    //   place.subAdministrativeArea,
    //   place.country,
    // ].whereType<String>().where((part) => part.isNotEmpty).toList();
    //
    // final fullAddressParts = [
    //   if (street.isNotEmpty) street,
    //   ...localityParts,
    //   if ((place.postalCode ?? '').isNotEmpty) place.postalCode!,
    // ];

    var streets = placemarks.reversed
        .map((placemark) => placemark.street)
        .where((street) => street != null);
    var address = '';
    // Filter out unwanted parts
    streets = streets.where((street) =>
    street!.toLowerCase() !=
        placemarks.reversed.last.locality!
            .toLowerCase()); // Remove city names
    streets =
        streets.where((street) => !street!.contains('+')); // Remove street codes

    address += streets.join(', ');

    address += ', ${placemarks.reversed.last.subLocality ?? ''}';
    address += ', ${placemarks.reversed.last.locality ?? ''}';
    address += ', ${placemarks.reversed.last.subAdministrativeArea ?? ''}';
    address += ', ${placemarks.reversed.last.administrativeArea ?? ''}';
    address += ', ${placemarks.reversed.last.postalCode ?? ''}';
    address += ', ${placemarks.reversed.last.country ?? ''}';


    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'building': building,
      //'street': street.isNotEmpty ? street : localityParts.join(', '),
      'street':address,
      'pincode': place.postalCode ?? '',
      //'fullAddress': fullAddressParts.join(', '),
      'fullAddress': address,
    };
  }

  Future<void> _searchForLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    final selectedSuggestion =
        _searchSuggestions.isNotEmpty ? _searchSuggestions.first : null;

    FocusScope.of(context).unfocus();

    if (selectedSuggestion != null) {
      await _selectSuggestion(selectedSuggestion);
      return;
    }

    _hideSuggestions();

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

  void _onSearchQueryChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _hideSuggestions();
      return;
    }

    if (query.length < _minimumSearchQueryLength) {
      _clearSuggestions(showList: false);
      return;
    }

    if (mounted) {
      setState(() {
        _showSuggestionList = true;
        _isLoadingSuggestions = true;
        _hasFetchedSuggestions = false;
      });
    }

    _searchDebounce = Timer(
      _searchDebounceDuration,
      () => _loadSearchSuggestions(query),
    );
  }

  void _onSearchFieldTapped() {
    final query = _searchController.text.trim();
    if (query.length < _minimumSearchQueryLength) {
      return;
    }

    if (mounted) {
      setState(() {
        _showSuggestionList = true;
      });
    }

    if (_searchSuggestions.isEmpty && !_isLoadingSuggestions) {
      _loadSearchSuggestions(query);
    }
  }

  Future<void> _loadSearchSuggestions(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < _minimumSearchQueryLength) {
      return;
    }

    final requestId = ++_searchSuggestionRequestId;

    if (mounted) {
      setState(() {
        _isLoadingSuggestions = true;
        _showSuggestionList = true;
      });
    }

    try {
      final locations = await locationFromAddress(normalizedQuery);
      final suggestions = await _buildSearchSuggestions(locations);

      if (!_shouldApplySuggestionResults(requestId, normalizedQuery)) {
        return;
      }

      setState(() {
        _searchSuggestions = suggestions;
        _isLoadingSuggestions = false;
        _hasFetchedSuggestions = true;
      });
    } catch (e) {
      debugPrint('Error fetching search suggestions: $e');
      if (!_shouldApplySuggestionResults(requestId, normalizedQuery)) {
        return;
      }

      setState(() {
        _searchSuggestions = const [];
        _isLoadingSuggestions = false;
        _hasFetchedSuggestions = true;
      });
    }
  }

  Future<List<_LocationSearchSuggestion>> _buildSearchSuggestions(
    List<Location> locations,
  ) async {
    final results = await Future.wait(
      locations.take(_maxSearchSuggestions * 2).map((location) async {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isEmpty) {
            return null;
          }

          return _createSearchSuggestion(location, placemarks.first);
        } catch (e) {
          debugPrint('Error reverse geocoding search suggestion: $e');
          return null;
        }
      }),
    );

    final suggestions = <_LocationSearchSuggestion>[];
    final seenLabels = <String>{};

    for (final suggestion in results) {
      if (suggestion == null) {
        continue;
      }

      final normalizedLabel = suggestion.fullLabel.toLowerCase();
      if (!seenLabels.add(normalizedLabel)) {
        continue;
      }

      suggestions.add(suggestion);
      if (suggestions.length == _maxSearchSuggestions) {
        break;
      }
    }

    return suggestions;
  }

  _LocationSearchSuggestion? _createSearchSuggestion(
    Location location,
    Placemark placemark,
  ) {
    final addressParts = _uniqueAddressParts([
      placemark.street,
      placemark.name,
      placemark.subLocality,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
      placemark.country,
      placemark.postalCode,
    ]);

    if (addressParts.isEmpty) {
      return null;
    }

    return _LocationSearchSuggestion(
      primaryText: addressParts.first,
      secondaryText: addressParts.skip(1).join(', '),
      position: LatLng(location.latitude, location.longitude),
    );
  }

  List<String> _uniqueAddressParts(List<String?> parts) {
    final results = <String>[];
    final seen = <String>{};

    for (final part in parts) {
      final value = part?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      final normalizedValue = value.toLowerCase();
      if (!seen.add(normalizedValue)) {
        continue;
      }

      results.add(value);
    }

    return results;
  }

  bool _shouldApplySuggestionResults(int requestId, String query) {
    return mounted &&
        requestId == _searchSuggestionRequestId &&
        query == _searchController.text.trim();
  }

  Future<void> _selectSuggestion(_LocationSearchSuggestion suggestion) async {
    final label = suggestion.fullLabel;
    _hideSuggestions();
    FocusScope.of(context).unfocus();
    _searchController.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );

    setState(() {
      _currentPosition = suggestion.position;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(suggestion.position, 16),
    );
  }

  void _hideSuggestions() {
    _searchDebounce?.cancel();
    _searchSuggestionRequestId++;
    _clearSuggestions(showList: false);
  }

  void _clearSuggestions({required bool showList}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchSuggestions = const [];
      _isLoadingSuggestions = false;
      _hasFetchedSuggestions = false;
      _showSuggestionList = showList;
    });
  }

  bool get _shouldShowSuggestions {
    final hasEnoughText =
        _searchController.text.trim().length >= _minimumSearchQueryLength;

    return _showSuggestionList &&
        hasEnoughText &&
        (_isLoadingSuggestions ||
            _searchSuggestions.isNotEmpty ||
            _hasFetchedSuggestions);
  }

  Widget _buildSuggestionList() {
    if (!_shouldShowSuggestions) {
      return const SizedBox.shrink();
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.32;

    return Material(
      elevation: AppSizes.elevation4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radius4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _isLoadingSuggestions && _searchSuggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppSizes.spacing16),
                child: Center(
                  child: SizedBox(
                    width: AppSizes.scaleLoading,
                    height: AppSizes.scaleLoading,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              )
            : _searchSuggestions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSizes.spacing16),
                    child: Text(
                      'No matching locations found',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _searchSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.dividerColor,
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _searchSuggestions[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        title: Text(
                          suggestion.primaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Lato',
                          ),
                        ),
                        subtitle: suggestion.secondaryText.isEmpty
                            ? null
                            : Text(
                                suggestion.secondaryText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize12,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Lato',
                                ),
                              ),
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _useCurrentAddress() async {
    FocusScope.of(context).unfocus();
    _hideSuggestions();
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
              onTap: (_) {
                FocusScope.of(context).unfocus();
                _hideSuggestions();
              },
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
                        onTap: _onSearchFieldTapped,
                        onChanged: _onSearchQueryChanged,
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
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius4),
                            borderSide: const BorderSide(
                              color: AppColors.borderColor,
                              width: AppSizes.borderMedium,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius4),
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
                    if (_shouldShowSuggestions) ...[
                      const SizedBox(height: AppSizes.spacing8),
                      _buildSuggestionList(),
                    ],
                    const SizedBox(height: AppSizes.spacing12),
                    PrimaryButton(
                      height: AppSizes.buttonHeight,
                      text: AppStrings.useCurrentAddress,
                      onPressed:
                          _isFetchingCurrentAddress ? null : _useCurrentAddress,
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
                      onPressed:
                          _isResolvingSelection ? null : _confirmSelection,
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
                  child:
                      CircularProgressIndicator(color: AppColors.primaryGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
