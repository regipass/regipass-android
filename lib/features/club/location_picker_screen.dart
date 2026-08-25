import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../l10n/app_strings.dart';
import '../../services/geocoding_service.dart';

/// Haritadan seçilen konum.
class PickedLocation {
  const PickedLocation({
    required this.lat,
    required this.lng,
    required this.address,
    required this.radius,
  });

  final double lat;
  final double lng;

  /// Ters coğrafi kodlamadan gelen okunabilir adres.
  final String address;

  /// Giriş doğrulamasında kullanılacak yarıçap (metre).
  final int radius;
}

/// Türkiye'nin yaklaşık merkezi — hiç konum yokken haritanın açılacağı yer.
const LatLng _kTurkeyCenter = LatLng(39.0, 35.0);

/// club-create-event.js'teki harita modalinin mobil karşılığı.
///
/// Harita ortasındaki sabit iğne konumu belirler: kullanıcı haritayı kaydırır,
/// iğne hep merkezde kalır — küçük ekranda parmakla tam noktaya dokunmaktan
/// çok daha isabetli. Adres araması ve ters kodlama Photon/Nominatim'de kalır
/// (Google Places sayaçlı bir kalem; harita ise mobilde ücretsiz).
///
/// **Kaydırma sırasında ağa çıkılmaz.** Adres yalnızca kamera tamamen durunca
/// sorulur; koordinat metni ise her karede dinlenebilir değerlerden güncellenir
/// (bunun için `setState` çağırmak haritayı da yeniden kurar ve kaydırma
/// gözle görülür biçimde takılırdı).
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    this.initialLat,
    this.initialLng,
    this.initialRadius = 50,
    super.key,
  });

  final double? initialLat;
  final double? initialLng;
  final int initialRadius;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const GeocodingService _geocoding = GeocodingService();

  GoogleMapController? _map;
  final TextEditingController _query = TextEditingController();

  late LatLng _center = widget.initialLat != null && widget.initialLng != null
      ? LatLng(widget.initialLat!, widget.initialLng!)
      : _kTurkeyCenter;

  late int _radius = widget.initialRadius;

  /// Harita gerçekten hareket ediyor mu. Yalnızca yarıçap dairesini
  /// gizlemek için `setState`e girer (hareket başına bir kez).
  bool _dragging = false;

  bool _initializingCurrentLocation = false;
  bool _hasPreciseInitialLocation = false;

  // Alt panelin ve arama katmanının durumu: bunlar değiştiğinde haritanın
  // yeniden kurulmasına gerek yok, o yüzden `setState` yerine dinlenebilir
  // değerlerde tutuluyorlar.
  late final ValueNotifier<LatLng> _coords = ValueNotifier<LatLng>(_center);
  final ValueNotifier<String> _address = ValueNotifier<String>('');
  final ValueNotifier<bool> _resolving = ValueNotifier<bool>(false);
  final ValueNotifier<List<GeoPlace>> _results =
      ValueNotifier<List<GeoPlace>>(const <GeoPlace>[]);
  final ValueNotifier<bool> _searching = ValueNotifier<bool>(false);

  // Adres çözümü ve arama birbirinden bağımsız iki iş; ortak bir sayaç
  // paylaşırlarsa biri diğerinin sonucunu iptal eder.
  int _addressRequestId = 0;
  int _searchRequestId = 0;

  bool get _hasInitialLocation =>
      widget.initialLat != null && widget.initialLng != null;

  @override
  void initState() {
    super.initState();
    if (_hasInitialLocation) {
      _hasPreciseInitialLocation = true;
      _resolveAddress();
    } else {
      _initializingCurrentLocation = true;
      _loadInitialCurrentLocation();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _map?.dispose();
    _coords.dispose();
    _address.dispose();
    _resolving.dispose();
    _results.dispose();
    _searching.dispose();
    super.dispose();
  }

  /// Merkezin adresini sorar. Sürükleme sürerken **çağrılmaz**.
  Future<void> _resolveAddress() async {
    final int id = ++_addressRequestId;
    final LatLng target = _center;
    _resolving.value = true;

    // Nominatim saniyede en fazla bir istek kabul ediyor. Kısa bekleme,
    // arka arkaya duran kamera hareketlerinde yalnızca sonuncusunu sorar.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || id != _addressRequestId) return;

    final String address = await _geocoding.reverse(
      target.latitude,
      target.longitude,
    );

    if (!mounted || id != _addressRequestId) return;
    _address.value = address;
    _resolving.value = false;
  }

  /// Kamera kımıldadı: bekleyen adres isteği geçersizleşir. Parmak kalkana
  /// (ya da animasyon bitene) kadar ağa hiç gidilmez.
  void _onCameraMoveStarted() {
    _addressRequestId++;
    _resolving.value = false;
    if (!_dragging) setState(() => _dragging = true);
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
    // Yalnızca koordinat metni yeniden çizilir; harita dokunulmadan kalır.
    _coords.value = position.target;
  }

  void _onCameraIdle() {
    if (_dragging) setState(() => _dragging = false);
    _resolveAddress();
  }

  Future<void> _moveTo(LatLng target, {double zoom = 16}) async {
    _center = target;
    _coords.value = target;
    // Animasyon `onCameraIdle`i tetikler, adres orada çözülür.
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  Future<LatLng?> _readCurrentLocation({required bool showFeedback}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('clubCreateEvent.location.error')),
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('location.permissionDenied'))),
          );
        }
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 12),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('clubCreateEvent.location.error'))),
        );
      }
      return null;
    }
  }

  Future<void> _loadInitialCurrentLocation() async {
    final LatLng? location = await _readCurrentLocation(showFeedback: false);
    if (!mounted) return;

    setState(() {
      _initializingCurrentLocation = false;
      if (location != null) {
        _center = location;
        _coords.value = location;
        _hasPreciseInitialLocation = true;
      }
    });

    if (location != null) {
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    }
  }

  Future<void> _useCurrentLocation() async {
    final LatLng? location = await _readCurrentLocation(showFeedback: true);
    if (location != null && mounted) {
      await _moveTo(location);
    }
  }

  Future<void> _search(String value) async {
    final int id = ++_searchRequestId;

    if (value.trim().length < kMinSuggestLength) {
      _results.value = const <GeoPlace>[];
      _searching.value = false;
      return;
    }

    _searching.value = true;

    // Kullanıcı yazmayı sürdürürse bu istek geçersizleşir.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || id != _searchRequestId) return;

    final List<GeoPlace> places = await _geocoding.suggest(value);
    if (!mounted || id != _searchRequestId) return;

    _results.value = places;
    _searching.value = false;
  }

  /// Seçilen noktayı cihazın harita uygulamasında açar.
  ///
  /// Yalnızca **görüntüleme** amaçlıdır: ne Google Haritalar ne de Apple
  /// Haritalar, üçüncü taraf bir uygulamaya seçilen konumu geri döndüren bir
  /// arayüz sunuyor (Google'ın Place Picker niyeti 2019'da kapatıldı).
  Future<void> _openInExternalMaps() async {
    final Uri uri = defaultTargetPlatform == TargetPlatform.android
        ? Uri.parse(
            'geo:${_center.latitude},${_center.longitude}'
            '?q=${_center.latitude},${_center.longitude}',
          )
        : Uri.parse(
            'https://maps.apple.com/?ll=${_center.latitude},${_center.longitude}',
          );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('clubCreateEvent.location.mapError')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('clubCreateEvent.location.mapError')),
          ),
        );
      }
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      PickedLocation(
        lat: _center.latitude,
        lng: _center.longitude,
        address: _address.value,
        radius: _radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('clubCreateEvent.location.pickTitle')),
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: _hasPreciseInitialLocation ? 16 : 5.5,
            ),
            onMapCreated: (GoogleMapController controller) {
              _map = controller;
              if (_hasPreciseInitialLocation) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_center, 16),
                );
              }
            },
            onCameraMoveStarted: _onCameraMoveStarted,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onTap: _moveTo,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Giriş yarıçapı: öğrenci bu dairenin dışındaysa QR reddedilir.
            // Kaydırırken gizlenir — daire iğnenin arkasında sürüklenip
            // "geride kalıyor" izlenimi veriyordu.
            circles: _dragging
                ? const <Circle>{}
                : <Circle>{
                    Circle(
                      circleId: const CircleId('radius'),
                      center: _center,
                      radius: _radius.toDouble(),
                      fillColor: BrandColors.red.withValues(alpha: 0.16),
                      strokeColor: BrandColors.red,
                      strokeWidth: 2,
                    ),
                  },
          ),

          // Merkez iğnesi — haritanın tam ortasında sabit durur.
          IgnorePointer(
            child: Center(
              child: Padding(
                // İğnenin ucu merkeze denk gelsin diye yarı yüksekliği kadar
                // yukarı kaydırılır.
                padding: const EdgeInsets.only(bottom: 38),
                child: Icon(
                  Icons.location_on,
                  size: 42,
                  color: BrandColors.red,
                  shadows: <Shadow>[
                    Shadow(
                      color: BrandColors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Arama ────────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: <Widget>[
                Material(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(BrandShape.controlRadius),
                  elevation: 4,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _searching,
                    builder: (BuildContext context, bool searching, _) =>
                        TextField(
                          controller: _query,
                          onChanged: _search,
                          textInputAction: TextInputAction.search,
                          inputFormatters: guardedInput(InputLimits.search),
                          decoration: InputDecoration(
                            hintText: context.t(
                              'clubCreateEvent.location.search',
                            ),
                            prefixIcon: const Icon(Icons.search),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            suffixIcon: searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                  ),
                ),
                ValueListenableBuilder<List<GeoPlace>>(
                  valueListenable: _results,
                  builder: (BuildContext context, List<GeoPlace> results, _) {
                    if (results.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(
                          BrandShape.controlRadius,
                        ),
                        boxShadow: BrandShape.card,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          for (final GeoPlace place in results)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.place_outlined,
                                size: 20,
                                color: context.brandInk,
                              ),
                              title: Text(
                                place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: place.subtitle.isEmpty
                                  ? null
                                  : Text(
                                      place.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                _results.value = const <GeoPlace>[];
                                _query.clear();
                                _moveTo(LatLng(place.lat, place.lng));
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Konumum + alt panel ──────────────────────────────────
          //
          // İkisi tek sütunda: panel adres uzadıkça büyüyor, sabit bir
          // "bottom" değeriyle konumlanan düğme panelin altında kalırdı.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.small(
                      heroTag: 'locationPickerGps',
                      backgroundColor: context.surface,
                      foregroundColor: context.brandInk,
                      onPressed: _useCurrentLocation,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ),
                _BottomPanel(
                  address: _address,
                  resolving: _resolving,
                  coords: _coords,
                  radius: _radius,
                  onRadiusChanged: (int value) =>
                      setState(() => _radius = value),
                  onConfirm: _confirm,
                  onOpenExternal: _openInExternalMaps,
                ),
              ],
            ),
          ),
          if (_initializingCurrentLocation)
            Positioned.fill(
              child: ColoredBox(
                color: context.canvas,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.address,
    required this.resolving,
    required this.coords,
    required this.radius,
    required this.onRadiusChanged,
    required this.onConfirm,
    required this.onOpenExternal,
  });

  final ValueListenable<String> address;
  final ValueListenable<bool> resolving;
  final ValueListenable<LatLng> coords;
  final int radius;
  final ValueChanged<int> onRadiusChanged;
  final VoidCallback onConfirm;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: BrandShape.raised,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.place, size: 20, color: context.brandInk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Adres yalnızca kamera durduktan sonra gelir.
                        //
                        // Yükseklik adrese göre büyür: sabit iki satırda uzun
                        // adresler ("... Mahallesi, ... Caddesi, No 12,
                        // Kadıköy/İstanbul") ortadan kesiliyor, kulüp doğru
                        // noktada mı olduğunu okuyamıyordu. Alt sınır iki
                        // satırda kalır ve değişim animasyonlu olur ki panel
                        // her adres güncellemesinde zıplamasın.
                        AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 38),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: resolving,
                              builder:
                                  (BuildContext context, bool busy, _) =>
                                      ValueListenableBuilder<String>(
                                        valueListenable: address,
                                        builder:
                                            (
                                              BuildContext context,
                                              String value,
                                              _,
                                            ) => Text(
                                              busy
                                                  ? context.t('common.loading')
                                                  : value.isNotEmpty
                                                  ? value
                                                  : context.t(
                                                      'clubCreateEvent.location.moveHint',
                                                    ),
                                              // Üst sınır yalnızca uç
                                              // durumlar için: panel haritanın
                                              // yarısını kaplamasın.
                                              maxLines: 6,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                height: 1.35,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                      ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<LatLng>(
                          valueListenable: coords,
                          builder: (BuildContext context, LatLng value, _) =>
                              Text(
                                '${value.latitude.toStringAsFixed(5)}, '
                                '${value.longitude.toStringAsFixed(5)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Seçimi dış haritada doğrulama. Dış harita seçim geri
                  // döndüremediği için bu yalnızca bir kontrol kısayolu.
                  IconButton(
                    tooltip: context.t('clubCreateEvent.location.openExternal'),
                    onPressed: onOpenExternal,
                    icon: Icon(Icons.open_in_new, color: context.brandInk),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Text(
                    context.t('form.locationRadius'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '$radius m',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.brandInk,
                    ),
                  ),
                ],
              ),
              Slider(
                value: radius.toDouble().clamp(20, 1000),
                min: 20,
                max: 1000,
                divisions: 49,
                activeColor: BrandColors.red,
                onChanged: (double value) => onRadiusChanged(value.round()),
              ),

              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check),
                label: Text(context.t('clubCreateEvent.location.confirm')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
