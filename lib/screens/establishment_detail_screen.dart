import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/establishment_model.dart';
import '../models/service_model.dart';
import '../models/rating_model.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';

/// Pantalla de detalle de un establecimiento
class EstablishmentDetailScreen extends StatefulWidget {
  final EstablishmentModel establishment;
  final String? distance;

  const EstablishmentDetailScreen({
    super.key,
    required this.establishment,
    this.distance,
  });

  @override
  State<EstablishmentDetailScreen> createState() =>
      _EstablishmentDetailScreenState();
}

class _EstablishmentDetailScreenState extends State<EstablishmentDetailScreen> {
  List<ServiceModel> _services = [];
  List<RatingModel> _ratings = [];
  bool _isLoadingServices = true;
  bool _isLoadingRatings = true;

  EstablishmentModel get est => widget.establishment;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Cargar servicios y ratings en paralelo
    final servicesFuture = ApiService.getServices(est.establecimientoId);
    final ratingsFuture = ApiService.getRatings(est.establecimientoId);

    final servicesResult = await servicesFuture;
    if (mounted) {
      setState(() {
        if (servicesResult.success && servicesResult.data != null) {
          _services = servicesResult.data!.where((s) => s.activo).toList();
        }
        _isLoadingServices = false;
      });
    }

    final ratingsResult = await ratingsFuture;
    if (mounted) {
      setState(() {
        if (ratingsResult.success && ratingsResult.data != null) {
          _ratings = ratingsResult.data!;
        }
        _isLoadingRatings = false;
      });
    }
  }

  double get _averageRating {
    if (_ratings.isEmpty) return 0;
    final total = _ratings.fold<int>(0, (sum, r) => sum + r.puntuacion);
    return total / _ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header con botón atrás ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.store_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        est.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Info del establecimiento ──
          SliverToBoxAdapter(child: _buildInfoSection()),

          // ── Rating resumido ──
          SliverToBoxAdapter(child: _buildRatingSummary()),

          // ── Servicios ──
          SliverToBoxAdapter(child: _buildServicesSection()),

          // ── Reseñas ──
          SliverToBoxAdapter(child: _buildReviewsSection()),

          // Espacio inferior
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyDark, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (est.descripcion.isNotEmpty) ...[
            Text(
              est.descripcion,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          _infoRow(Icons.place_outlined, est.direccion),
          if (est.telefono.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.phone_outlined, est.telefono),
          ],
          if (widget.distance != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.location_on, widget.distance!),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSummary() {
    if (_isLoadingRatings) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyDark, width: 0.5),
      ),
      child: Row(
        children: [
          // Número grande
          Column(
            children: [
              Text(
                _ratings.isEmpty ? '--' : _averageRating.toStringAsFixed(1),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStarRow(_averageRating, size: 16),
              const SizedBox(height: 4),
              Text(
                '${_ratings.length} reseña${_ratings.length == 1 ? '' : 's'}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Barras de distribución
          Expanded(child: _buildRatingBars()),
        ],
      ),
    );
  }

  Widget _buildStarRow(double rating, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        if (rating >= starValue) {
          return Icon(Icons.star_rounded, size: size, color: AppColors.warning);
        } else if (rating >= starValue - 0.5) {
          return Icon(Icons.star_half_rounded,
              size: size, color: AppColors.warning);
        } else {
          return Icon(Icons.star_outline_rounded,
              size: size, color: AppColors.greyDark);
        }
      }),
    );
  }

  Widget _buildRatingBars() {
    final total = _ratings.length;
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final count = _ratings.where((r) => r.puntuacion == star).length;
        final fraction = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$star',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: AppColors.greyDark,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.warning),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 20,
                child: Text('$count',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildServicesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Servicios',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingServices)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_services.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.greyDark, width: 0.5),
              ),
              child: Center(
                child: Text(
                  'No hay servicios disponibles',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(_services.length, (i) => _buildServiceCard(_services[i])),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greyDark, width: 0.5),
      ),
      child: Row(
        children: [
          // Icono del servicio
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.content_cut_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.nombre,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (service.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    service.descripcion,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(service.duracionFormateada,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Precio + botón agendar
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                service.precioFormateado,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                        service: service,
                        establishment: est,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Agendar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reseñas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingRatings)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_ratings.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.greyDark, width: 0.5),
              ),
              child: Center(
                child: Text(
                  'Aún no hay reseñas',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(
              _ratings.length > 5 ? 5 : _ratings.length,
              (i) => _buildReviewCard(_ratings[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(RatingModel rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greyDark, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStarRow(rating.puntuacion.toDouble(), size: 14),
              const Spacer(),
              Text(
                _formatDate(rating.fecha),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          if (rating.comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comentario,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
