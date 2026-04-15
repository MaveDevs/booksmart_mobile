import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:latlong2/latlong.dart';
import '../../config/app_theme.dart';
import '../../config/page_transitions.dart';
import '../../models/establishment_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../establishment_detail_screen.dart';

// ── Categorías con palabras clave para filtrar ──
class _Category {
  final String label;
  final IconData icon;
  final List<String> keywords;
  const _Category(this.label, this.icon, this.keywords);
}

const _categories = [
  _Category('Barberías', Icons.content_cut_rounded, ['barberia', 'barber', 'barbershop', 'corte', 'cortes', 'pelo', 'cabello', 'fade', 'degradado']),
  _Category('Salones', Icons.brush_rounded, ['salon', 'belleza', 'beauty', 'estetica', 'peinado', 'tinte', 'color', 'alisado', 'keratina']),
  _Category('Spa', Icons.spa_rounded, ['spa', 'masaje', 'relajacion', 'relax', 'sauna', 'terapia', 'bienestar']),
  _Category('Uñas', Icons.back_hand_rounded, ['unas', 'nail', 'nails', 'manicure', 'pedicure', 'gelish', 'acrilico', 'acrilicas']),
  _Category('Facial', Icons.face_retouching_natural_rounded, ['facial', 'skin', 'piel', 'rostro', 'limpieza', 'skincare']),
  _Category('Tattoo', Icons.draw_rounded, ['tattoo', 'tatuaje', 'piercing', 'tatto', 'ink']),
];

/// Sinónimos comunes de búsqueda
const _synonymGroups = <List<String>>[
  ['barberia', 'barber', 'barbershop', 'brberia', 'varber', 'barveria', 'barbero', 'barberos'],
  ['salon', 'belleza', 'beauty', 'estetica', 'estetic'],
  ['corte', 'cortes', 'pelo', 'cabello', 'haircut', 'hair'],
  ['unas', 'nails', 'nail', 'manicure', 'pedicure', 'mani', 'pedi'],
  ['spa', 'masaje', 'massage', 'relax', 'relajacion'],
  ['facial', 'rostro', 'cara', 'piel', 'skin', 'skincare'],
  ['tattoo', 'tatuaje', 'tatto', 'tatoo', 'ink', 'piercing'],
  ['tinte', 'color', 'coloracion'],
  ['alisado', 'keratina', 'lacio'],
  ['cejas', 'ceja', 'brow', 'brows', 'eyebrow'],
  ['depilacion', 'wax', 'cera'],
];

/// Elimina acentos y caracteres especiales para comparación
String _normalize(String input) {
  const _accentMap = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u',
    'ñ': 'n', 'Ñ': 'n', 'ü': 'u', 'Ü': 'u',
  };
  final buffer = StringBuffer();
  for (final ch in input.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    buffer.write(_accentMap[c] ?? c);
  }
  return buffer.toString();
}

/// Calcula distancia de edición simplificada (Levenshtein) entre dos strings
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final la = a.length, lb = b.length;
  var prev = List.generate(lb + 1, (i) => i);
  for (var i = 1; i <= la; i++) {
    final curr = List.filled(lb + 1, 0);
    curr[0] = i;
    for (var j = 1; j <= lb; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].reduce((a, b) => a < b ? a : b);
    }
    prev = curr;
  }
  return prev[lb];
}

/// Expande la query con sinónimos
Set<String> _expandWithSynonyms(String normalizedQuery) {
  final terms = normalizedQuery.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
  final expanded = <String>{...terms};
  for (final term in terms) {
    for (final group in _synonymGroups) {
      // Match exacto o fuzzy contra alguno del grupo
      final matchesGroup = group.any((syn) =>
          syn == term || syn.contains(term) || term.contains(syn) ||
          (term.length >= 4 && _editDistance(term, syn) <= 2));
      if (matchesGroup) {
        expanded.addAll(group);
      }
    }
  }
  return expanded;
}

class SearchTab extends StatefulWidget {
  final ValueChanged<bool>? onMapChanged;
  const SearchTab({super.key, this.onMapChanged});

  @override
  State<SearchTab> createState() => SearchTabState();
}

class SearchTabState extends State<SearchTab> with SingleTickerProviderStateMixin {
  // ── Controladores ──
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final MapController _mapController = MapController();
  final GlobalKey _topPanelKey = GlobalKey();
  late final AnimationController _transitionController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // ── Estado ──
  List<EstablishmentModel> _everyEstablishment = []; // TODOS sin filtro de distancia
  List<EstablishmentModel> _allEstablishments = []; // Dentro del radio
  List<EstablishmentModel> _nearbyEstablishments = [];
  List<EstablishmentModel> _filteredEstablishments = [];
  EstablishmentModel? _selectedEstablishment;
  int? _selectedCategoryIndex;

  double _userLat = 20.6597;
  double _userLon = -103.3496;
  bool _isLoading = true;
  bool _hasLocation = false;
  String _locationName = '';
  bool _showMap = false;
  bool _showSearchAreaButton = false;
  double _topPanelHeight = 0;

  static const double _nearbyRadiusKm = 5.0;
  static const double _searchRadiusKm = 20.0;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    ));
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _getUserLocation();
    await _loadEstablishments();
  }

  Future<void> _getUserLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _userLat = position.latitude;
        _userLon = position.longitude;
        _hasLocation = true;
      });
      // Reverse geocoding para obtener el nombre de la calle/colonia
      try {
        final placemarks = await geo.placemarkFromCoordinates(
          position.latitude, position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final p = placemarks.first;
          // Construir dirección corta: colonia, ciudad (calle solo como fallback)
          final parts = <String>[
            if (p.subLocality != null && p.subLocality!.isNotEmpty)
              p.subLocality!
            else if (p.street != null && p.street!.isNotEmpty)
              p.street!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          ];
          if (parts.isNotEmpty) {
            setState(() => _locationName = parts.join(', '));
          }
        }
      } catch (e) {
        debugPrint('[Location] Reverse geocoding error: $e');
      }
    }
  }

  Future<void> _loadEstablishments() async {
    setState(() => _isLoading = true);

    // Intentar usar el endpoint nearby si tenemos ubicación
    ApiResult<List<EstablishmentModel>> result;
    if (_hasLocation) {
      result = await ApiService.getNearbyEstablishments(
        latitude: _userLat,
        longitude: _userLon,
        radiusKm: _searchRadiusKm,
      );
    } else {
      result = await ApiService.getEstablishments();
    }

    if (mounted) {
      if (result.success && result.data != null) {
        final all = result.data!;
        // Si vino del nearby endpoint, ya viene ordenado por ranking/distancia
        // Si no, ordenar por distancia calculada
        if (!_hasLocation) {
          all.sort((a, b) =>
              a.distanceTo(_userLat, _userLon).compareTo(
              b.distanceTo(_userLat, _userLon)));
        }

        setState(() {
          _everyEstablishment = all;
          // Si viene del nearby, distanceKm ya está, usar eso; sino calcular
          _allEstablishments = all.where((e) {
            final dist = e.distanceKm ?? e.distanceTo(_userLat, _userLon);
            return dist <= _searchRadiusKm;
          }).toList();
          _nearbyEstablishments = all.where((e) {
            final dist = e.distanceKm ?? e.distanceTo(_userLat, _userLon);
            return dist <= _nearbyRadiusKm;
          }).toList();
          _filteredEstablishments = _allEstablishments;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Filtrado ──
  void _applyFilters() {
    final rawQuery = _searchController.text;
    final normalizedQuery = _normalize(rawQuery);
    final catIndex = _selectedCategoryIndex;

    final isSearching = normalizedQuery.isNotEmpty || catIndex != null;
    var results = List<EstablishmentModel>.from(
        isSearching ? _everyEstablishment : _allEstablishments);

    // Filtrar por categoría (keywords ya están normalizados)
    if (catIndex != null) {
      final keywords = _categories[catIndex].keywords;
      results = results.where((e) {
        final text = _normalize('${e.nombre} ${e.descripcion}');
        return keywords.any((kw) => text.contains(kw));
      }).toList();
    }

    // Filtrar por texto de búsqueda con normalización, sinónimos y tolerancia a errores
    if (normalizedQuery.isNotEmpty) {
      final expandedTerms = _expandWithSynonyms(normalizedQuery);

      results = results.where((e) {
        final text = _normalize('${e.nombre} ${e.descripcion} ${e.direccion}');
        final words = text.split(RegExp(r'\s+'));
        // Al menos un término expandido debe hacer match
        return expandedTerms.any((term) {
          // Match exacto parcial
          if (text.contains(term)) return true;
          // Fuzzy: edit distance ≤ 2 para palabras de 4+ caracteres
          if (term.length >= 4) {
            return words.any((w) =>
                w.length >= 4 && _editDistance(term, w) <= 2);
          }
          return false;
        });
      }).toList();
    }

    setState(() {
      _filteredEstablishments = results;
      _selectedEstablishment = null;
    });
  }

  void _selectCategory(int? index) {
    setState(() {
      _selectedCategoryIndex = (_selectedCategoryIndex == index) ? null : index;
    });
    _applyFilters();
  }

  void _openMapView({int? categoryIndex}) {
    setState(() {
      _showMap = true;
      if (categoryIndex != null) {
        _selectedCategoryIndex = categoryIndex;
      }
    });
    widget.onMapChanged?.call(true);
    _applyFilters();
    _transitionController.forward(from: 0);
    // Medir el panel superior después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTopPanel());
    if (categoryIndex == null) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  void _measureTopPanel() {
    final box = _topPanelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && mounted) {
      final height = box.size.height + MediaQuery.of(context).padding.top;
      if (height != _topPanelHeight) {
        setState(() => _topPanelHeight = height);
      }
    }
  }

  Future<void> _closeMapView() async {
    _searchFocus.unfocus();
    await _transitionController.reverse();
    if (mounted) {
      setState(() {
        _showMap = false;
        _searchController.clear();
        _selectedCategoryIndex = null;
        _selectedEstablishment = null;
        _filteredEstablishments = _allEstablishments;
      });
      widget.onMapChanged?.call(false);
    }
  }

  /// Regresa a la vista principal de descubrimiento
  void goHome() {
    if (_showMap) {
      _closeMapView();
    }
  }

  void _selectEstablishment(EstablishmentModel e) {
    setState(() => _selectedEstablishment = e);
    _mapController.move(LatLng(e.latitud, e.longitud), 15.0);
  }

  void _searchInCurrentArea() {
    final bounds = _mapController.camera.visibleBounds;
    final results = _everyEstablishment.where((e) {
      return e.latitud >= bounds.south &&
          e.latitud <= bounds.north &&
          e.longitud >= bounds.west &&
          e.longitud <= bounds.east;
    }).toList()
      ..sort((a, b) => a.distanceTo(_userLat, _userLon).compareTo(
          b.distanceTo(_userLat, _userLon)));

    setState(() {
      _filteredEstablishments = results;
      _selectedEstablishment = null;
      _showSearchAreaButton = false;
    });
  }

  void _clearSelection() {
    setState(() => _selectedEstablishment = null);
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Stack(
      children: [
        // Discovery siempre detrás
        _buildDiscoveryView(),
        // Map se desliza encima con animación
        if (_showMap)
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildMapView(),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DISCOVERY VIEW (estilo Uber Eats)
  // ══════════════════════════════════════════════════════════
  Widget _buildDiscoveryView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header + Search bar ──
            SliverToBoxAdapter(child: _buildDiscoveryHeader()),

            // ── Categorías ──
            SliverToBoxAdapter(child: _buildCategoryRow(onTap: (i) => _openMapView(categoryIndex: i))),

            // ── Cerca de ti ──
            if (_nearbyEstablishments.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _SectionTitle('Cerca de ti')),
              SliverToBoxAdapter(child: _buildNearbyHorizontalList()),
            ],

            // ── Todos los establecimientos ──
            if (_allEstablishments.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _SectionTitle('Explorar')),
              _buildAllEstablishmentsList(),
            ],

            // espacio para navbar
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hasLocation
                      ? (_locationName.isNotEmpty ? _locationName : 'Mi ubicación actual')
                      : 'Obteniendo ubicación...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Descubre',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Search bar estilo Didi Food / Uber Eats
          GestureDetector(
            onTap: () => _openMapView(),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.greyDark, width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Buscar barbería, salón, spa...',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.5),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(height: 28, width: 1, color: AppColors.greyDark),
                  const SizedBox(width: 12),
                  Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({required void Function(int) onTap}) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onTap(index),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.greyDark,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      cat.icon,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNearbyHorizontalList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.55).clamp(180.0, 280.0);

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _nearbyEstablishments.length,
        itemBuilder: (context, index) {
          final e = _nearbyEstablishments[index];
          final dist = e.distanciaFormateada(_userLat, _userLon);
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                _openMapView();
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) _selectEstablishment(e);
                });
              },
              child: Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.greyDark, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con icono
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Icon(Icons.store_rounded, color: AppColors.primary, size: 36),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 13, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                dist,
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.direccion,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  SliverList _buildAllEstablishmentsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final e = _allEstablishments[index];
          final dist = e.distanciaFormateada(_userLat, _userLon);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: GestureDetector(
              onTap: () {
                _openMapView();
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) _selectEstablishment(e);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.greyDark, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.store_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            e.direccion,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              dist,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: _allEstablishments.length,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  MAP VIEW (mapa oscuro + búsqueda activa)
  // ══════════════════════════════════════════════════════════
  Widget _buildMapView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Mapa oscuro
          _buildDarkMap(),

          // Panel superior: botón atrás + búsqueda + categorías
          _buildMapTopPanel(),

          // Botón "Buscar en esta área"
          if (_showSearchAreaButton)
            Positioned(
              top: _topPanelHeight + 12,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _searchInCurrentArea,
                  child: AnimatedOpacity(
                    opacity: _showSearchAreaButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Buscar en esta área',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Card del establecimiento seleccionado
          if (_selectedEstablishment != null)
            _buildEstablishmentCard(),

          // Lista inferior de resultados
          if (_selectedEstablishment == null && _filteredEstablishments.isNotEmpty)
            _buildMapBottomList(),

          // Sin resultados
          if (_filteredEstablishments.isEmpty && !_isLoading)
            _buildNoResults(),

          // Botón centrar
          if (_hasLocation && _selectedEstablishment == null)
            _buildCenterButton(),
        ],
      ),
    );
  }

  Widget _buildDarkMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_userLat, _userLon),
        initialZoom: 13.0,
        onTap: (_, __) => _clearSelection(),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && !_showSearchAreaButton) {
            setState(() => _showSearchAreaButton = true);
          }
        },
      ),
      children: [
        // CartoDB — mapa oscuro o claro según tema
        TileLayer(
          urlTemplate: AppColors.isDark
              ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.booksmart_movile_app',
        ),

        // Marcadores
        MarkerLayer(
          markers: [
            // Ubicación del usuario
            if (_hasLocation)
              Marker(
                point: LatLng(_userLat, _userLon),
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                  ),
                ),
              ),

            // Establecimientos
            ..._filteredEstablishments.map((e) {
              final isSelected = _selectedEstablishment?.establecimientoId == e.establecimientoId;
              return Marker(
                point: LatLng(e.latitud, e.longitud),
                width: isSelected ? 44 : 36,
                height: isSelected ? 44 : 36,
                child: GestureDetector(
                  onTap: () => _selectEstablishment(e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : AppColors.primary,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.4)
                              : Colors.black.withOpacity(0.3),
                          blurRadius: isSelected ? 8 : 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: isSelected ? 22 : 18,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildMapTopPanel() {
    return SafeArea(
      child: Column(
        key: _topPanelKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de búsqueda con botón atrás — estilo Didi/Uber Eats
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                  onPressed: _closeMapView,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.greyDark, width: 1),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: 'Buscar barbería, salón, spa...',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 15),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 14, right: 8),
                          child: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                                child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chips de categorías
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(64, 8, 16, 0),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectCategory(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.greyDark,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 16,
                            color: isSelected ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildEstablishmentCard() {
    final e = _selectedEstablishment!;
    final dist = e.distanciaFormateada(_userLat, _userLon);

    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        elevation: 8,
        color: AppColors.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              appRoute(EstablishmentDetailScreen(
                establishment: e,
                distance: dist,
              )),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.store_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(dist, style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: _clearSelection,
                    ),
                  ],
                ),
                if (e.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(e.descripcion,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(e.direccion,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (e.telefono.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(e.telefono, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapBottomList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.48).clamp(170.0, 260.0);

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredEstablishments.length,
        itemBuilder: (context, index) {
          final e = _filteredEstablishments[index];
          final dist = e.distanciaFormateada(_userLat, _userLon);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectEstablishment(e),
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.greyDark, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.nombre,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(e.direccion,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(dist, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoResults() {
    return Positioned(
      bottom: 100,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: AppColors.textSecondary, size: 36),
            const SizedBox(height: 8),
            Text(
              'No se encontraron resultados',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Intenta con otra búsqueda o categoría',
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return Positioned(
      bottom: 220,
      right: 16,
      child: FloatingActionButton.small(
        backgroundColor: AppColors.surface,
        heroTag: 'center_btn',
        onPressed: () => _mapController.move(LatLng(_userLat, _userLon), 13.0),
        child: Icon(Icons.my_location, color: AppColors.primary, size: 20),
      ),
    );
  }
}

// ── Widget auxiliar para títulos de sección ──
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
