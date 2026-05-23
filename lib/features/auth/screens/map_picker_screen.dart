import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.primaryText,
    required this.secondaryText,
    required this.placeId,
  });

  final String primaryText;
  final String secondaryText;
  final String placeId;

  String get fullLabel =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  static const int _minQueryLength = 2;
  static const int _maxSuggestions = 5;
  static const Duration _debounceDuration = Duration(milliseconds: 350);

  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(22.5726, 88.3639); // Default: Kolkata
  bool _isLoadingLocation = true;
  bool _isSearchingLocation = false;
  bool _isResolvingSelection = false;
  bool _isFetchingCurrentAddress = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<_PlaceSuggestion> _suggestions = const [];
  bool _isLoadingSuggestions = false;
  bool _hasFetchedSuggestions = false;
  bool _showSuggestionList = false;
  int _suggestionRequestId = 0;

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

  // ─── Location ──────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _determinePosition();
      if (position == null) {
        setState(() => _isLoadingLocation = false);
        return;
      }
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15),
      );
    } catch (e) {
      debugPrint('[MapPicker] getCurrentLocation error: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return null;
      }

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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      debugPrint('[MapPicker] determinePosition error: $e');
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

  void _onCameraMove(CameraPosition position) {
    setState(() => _currentPosition = position.target);
  }

  // ─── Places Autocomplete ────────────────────────────────────────────────────

  void _onSearchQueryChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _hideSuggestions();
      return;
    }

    if (query.length < _minQueryLength) {
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

    _searchDebounce = Timer(_debounceDuration, () => _loadSuggestions(query));
  }

  void _onSearchFieldTapped() {
    final query = _searchController.text.trim();
    if (query.length < _minQueryLength) return;

    if (mounted) setState(() => _showSuggestionList = true);

    if (_suggestions.isEmpty && !_isLoadingSuggestions) {
      _loadSuggestions(query);
    }
  }

  Future<void> _loadSuggestions(String query) async {
    final normalized = query.trim();
    if (normalized.length < _minQueryLength) return;

    final requestId = ++_suggestionRequestId;

    if (mounted) {
      setState(() {
        _isLoadingSuggestions = true;
        _showSuggestionList = true;
      });
    }

    try {
      final results = await _fetchAutocompletePredictions(normalized);
      if (!_shouldApplyResults(requestId, normalized)) return;

      setState(() {
        _suggestions = results;
        _isLoadingSuggestions = false;
        _hasFetchedSuggestions = true;
      });
    } catch (e) {
      debugPrint('[MapPicker] loadSuggestions error: $e');
      if (!_shouldApplyResults(requestId, normalized)) return;

      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
        _hasFetchedSuggestions = true;
      });
    }
  }

  /// Calls the Google Places Autocomplete API, restricted to India.
  Future<List<_PlaceSuggestion>> _fetchAutocompletePredictions(
      String query) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'components': 'country:in',
        'key': AppConfig.googleMapsApiKey,
        'language': 'en',
        //'types': 'geocode',
      },
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final status = json['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        debugPrint('[Places] Autocomplete status: $status');
        return const [];
      }

      final predictions = json['predictions'] as List<dynamic>? ?? [];
      return predictions.take(_maxSuggestions).map((p) {
        final pred = p as Map<String, dynamic>;
        final sf =
            pred['structured_formatting'] as Map<String, dynamic>?;
        final primary = sf?['main_text'] as String? ??
            pred['description'] as String? ??
            '';
        final secondary = sf?['secondary_text'] as String? ?? '';
        return _PlaceSuggestion(
          primaryText: primary,
          secondaryText: secondary,
          placeId: pred['place_id'] as String? ?? '',
        );
      }).where((s) => s.placeId.isNotEmpty).toList();
    } finally {
      client.close();
    }
  }

  /// Calls the Google Places Details API to resolve coordinates for a place_id.
  Future<LatLng> _fetchPlaceCoordinates(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry',
        'key': AppConfig.googleMapsApiKey,
      },
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final status = json['status'] as String? ?? '';
      if (status != 'OK') {
        throw Exception('Place Details API error: $status');
      }

      final result = json['result'] as Map<String, dynamic>;
      final geometry = result['geometry'] as Map<String, dynamic>;
      final loc = geometry['location'] as Map<String, dynamic>;
      return LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
    } finally {
      client.close();
    }
  }

  bool _shouldApplyResults(int requestId, String query) {
    return mounted &&
        requestId == _suggestionRequestId &&
        query == _searchController.text.trim();
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    final label = suggestion.fullLabel;
    _hideSuggestions();
    FocusScope.of(context).unfocus();
    _searchController.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );

    setState(() => _isResolvingSelection = true);
    try {
      final target = await _fetchPlaceCoordinates(suggestion.placeId);
      if (!mounted) return;
      setState(() {
        _currentPosition = target;
        _isResolvingSelection = false;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (e) {
      debugPrint('[MapPicker] selectSuggestion error: $e');
      if (!mounted) return;
      setState(() => _isResolvingSelection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to resolve location. Please try again.'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  void _hideSuggestions() {
    _searchDebounce?.cancel();
    _suggestionRequestId++;
    _clearSuggestions(showList: false);
  }

  void _clearSuggestions({required bool showList}) {
    if (!mounted) return;
    setState(() {
      _suggestions = const [];
      _isLoadingSuggestions = false;
      _hasFetchedSuggestions = false;
      _showSuggestionList = showList;
    });
  }

  bool get _shouldShowSuggestions {
    return _showSuggestionList &&
        _searchController.text.trim().length >= _minQueryLength &&
        (_isLoadingSuggestions ||
            _suggestions.isNotEmpty ||
            _hasFetchedSuggestions);
  }

  // ─── Search submit (keyboard action) ───────────────────────────────────────

  Future<void> _searchForLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // If suggestions are visible, select the first one
    if (_suggestions.isNotEmpty) {
      await _selectSuggestion(_suggestions.first);
      return;
    }

    FocusScope.of(context).unfocus();
    _hideSuggestions();
    setState(() => _isSearchingLocation = true);

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) throw Exception('Location not found');

      final target =
          LatLng(locations.first.latitude, locations.first.longitude);
      setState(() => _currentPosition = target);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (e) {
      debugPrint('[MapPicker] searchForLocation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to find that address. Try a different search.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  // ─── Confirm Selection ─────────────────────────────────────────────────────

  Future<void> _confirmSelection() async {
    FocusScope.of(context).unfocus();
    _hideSuggestions();
    setState(() => _isResolvingSelection = true);

    try {
      final data = await _buildAddressPayload(_currentPosition);
      if (!mounted) return;
      context.pop(data);
    } catch (e) {
      debugPrint('[MapPicker] confirmSelection error: $e');
      if (!mounted) return;
      setState(() => _isResolvingSelection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to fetch address for the selected location'),
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

    if (placemarks.isEmpty) throw Exception('No address found');

    final place = placemarks.first;
    final building = (place.subThoroughfare ?? '').isNotEmpty
        ? place.subThoroughfare!
        : (place.name ?? '');

    var streets = placemarks.reversed
        .map((p) => p.street)
        .where((s) => s != null);
    streets = streets.where((s) =>
        s!.toLowerCase() !=
        (placemarks.reversed.last.locality ?? '').toLowerCase());
    streets = streets.where((s) => !s!.contains('+'));

    var address = streets.join(', ');
    final last = placemarks.reversed.last;
    address += ', ${last.subLocality ?? ''}';
    address += ', ${last.locality ?? ''}';
    address += ', ${last.subAdministrativeArea ?? ''}';
    address += ', ${last.administrativeArea ?? ''}';
    address += ', ${last.postalCode ?? ''}';
    address += ', ${last.country ?? ''}';

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'building': building,
      'street': address,
      'pincode': place.postalCode ?? '',
      'fullAddress': address,
    };
  }

  // ─── Use Current Address ───────────────────────────────────────────────────

  Future<void> _useCurrentAddress() async {
    FocusScope.of(context).unfocus();
    _hideSuggestions();
    setState(() => _isFetchingCurrentAddress = true);

    try {
      final position = await _determinePosition();
      if (position == null) {
        if (mounted) setState(() => _isFetchingCurrentAddress = false);
        return;
      }

      final latLng = LatLng(position.latitude, position.longitude);
      final data = await _buildAddressPayload(latLng);
      if (!mounted) return;
      context.pop(data);
    } catch (e) {
      debugPrint('[MapPicker] useCurrentAddress error: $e');
      if (!mounted) return;
      setState(() => _isFetchingCurrentAddress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch your current address'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

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
          'Location permission is required to show your current location. '
          'Please grant permission in settings.',
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
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

            // Fixed center pin
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

            // Search bar + suggestions + current-location button
            Positioned(
              left: AppSizes.spacing16,
              right: AppSizes.spacing16,
              top: AppSizes.spacing16,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
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
                          filled: true,
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
                          suffixIcon: _isSearchingLocation ||
                                  (_isResolvingSelection &&
                                      _suggestions.isEmpty)
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

                    // Suggestions dropdown
                    if (_shouldShowSuggestions) ...[
                      const SizedBox(height: AppSizes.spacing4),
                      _buildSuggestionList(),
                    ],

                    const SizedBox(height: AppSizes.spacing12),

                    // Use current location button
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

            // Confirm button at bottom
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
                      color:
                          Colors.black.withValues(alpha: AppSizes.opacity10),
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

            // Full-screen loading overlay while fetching initial location
            if (_isLoadingLocation)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.35;

    return Material(
      elevation: AppSizes.elevation4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radius4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _isLoadingSuggestions && _suggestions.isEmpty
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
            : _suggestions.isEmpty
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
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.dividerColor,
                    ),
                    itemBuilder: (context, index) {
                      final s = _suggestions[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        title: Text(
                          s.primaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        subtitle: s.secondaryText.isEmpty
                            ? null
                            : Text(
                                s.secondaryText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize12,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Lato',
                                ),
                              ),
                        onTap: () => _selectSuggestion(s),
                      );
                    },
                  ),
      ),
    );
  }
}
