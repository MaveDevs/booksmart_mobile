import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/app_theme.dart';
import '../../models/establishment_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

// ── Categorías con palabras clave para filtrar ──
class _Category {
  final String label;
  final IconData icon;
  final List<String> keywords;
  const _Category(this.label, this.icon, this.keywords);
}

const _categories = [
  _Category('Barberías', Icons.content_cut_rounded, ['barbería', 'barberia', 'barber']),
  _Category('Salones', Icons.brush_rounded, ['salón', 'salon', 'belleza', 'beauty', 'estética', 'estetica']),
  _Category('Spa', Icons.spa_rounded, ['spa', 'masaje', 'relajación', 'relajacion']),
  _Category('Uñas', Icons.back_hand_rounded, ['uñas', 'nail', 'manicure', 'pedicure']),
  _Category('Facial', Icons.face_retouching_natural_rounded, ['facial', 'skin', 'piel', 'rostro']),
  _Category('Tattoo', Icons.draw_rounded, ['tattoo', 'tatuaje', 'piercing']),
];

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> with SingleTickerProviderStateMixin {
  // ── Controladores ──
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final MapController _mapController = MapController();
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
  bool _showMap = false;
  bool _showSearchAreaButton = false;

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
    }
  }

  Future<void> _loadEstablishments() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getEstablishments();

    if (mounted) {
      if (result.success && result.data != null) {
        final all = result.data!
          ..sort((a, b) =>
              a.distanceTo(_userLat, _userLon).compareTo(
              b.distanceTo(_userLat, _userLon)));

        setState(() {
          _everyEstablishment = all;
          _allEstablishments = all
              .where((e) => e.distanceTo(_userLat, _userLon) <= _searchRadiusKm)
              .toList();
          _nearbyEstablishments = all
              .where((e) => e.distanceTo(_userLat, _userLon) <= _nearbyRadiusKm)
              .toList();
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
    final query = _searchController.text.toLowerCase();
    final catIndex = _selectedCategoryIndex;

    // Si hay búsqueda activa, buscar en TODOS los establecimientos
    // Si no, solo mostrar los del radio cercano
    final isSearching = query.isNotEmpty || catIndex != null;
    var results = List<EstablishmentModel>.from(
        isSearching ? _everyEstablishment : _allEstablishments);

    // Filtrar por categoría
    if (catIndex != null) {
      final keywords = _categories[catIndex].keywords;
      results = results.where((e) {
        final text = '${e.nombre} ${e.descripcion}'.toLowerCase();
        return keywords.any((kw) => text.contains(kw));
      }).toList();
    }

    // Filtrar por texto de búsqueda
    if (query.isNotEmpty) {
      results = results.where((e) =>
          e.nombre.toLowerCase().contains(query) ||
          e.descripcion.toLowerCase().contains(query) ||
          e.direccion.toLowerCase().contains(query)).toList();
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
    _applyFilters();
    _transitionController.forward(from: 0);
    if (categoryIndex == null) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _searchFocus.requestFocus();
      });
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
      return const Scaffold(
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
              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hasLocation ? 'Tu ubicación actual' : 'Obteniendo ubicación...',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
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
                  const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
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
                  const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
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
                width: 220,
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
                      child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 36),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: const TextStyle(
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
                              const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                dist,
                                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.direccion,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                      child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: const TextStyle(
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
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                            const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              dist,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
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
              top: MediaQuery.of(context).padding.top + 126,
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
        // CartoDB Dark Matter — mapa oscuro minimalista
        TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
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
                  child: const Center(
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
                      color: isSelected ? AppColors.primary : const Color(0xFF2A2A2A),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de búsqueda con botón atrás — estilo Didi/Uber Eats
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: 'Buscar barbería, salón, spa...',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 15),
                        prefixIcon: const Padding(
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
                                child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
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
            // TODO: Navegar a detalle del establecimiento
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
                      child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(dist, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: _clearSelection,
                    ),
                  ],
                ),
                if (e.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(e.descripcion,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(e.direccion,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (e.telefono.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(e.telefono, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filteredEstablishments.length,
        itemBuilder: (context, index) {
          final e = _filteredEstablishments[index];
          final dist = e.distanciaFormateada(_userLat, _userLon);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectEstablishment(e),
              child: Container(
                width: 200,
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
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(e.direccion,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(dist, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
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
            const Icon(Icons.search_off_rounded, color: AppColors.textSecondary, size: 36),
            const SizedBox(height: 8),
            const Text(
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
        child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
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
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
