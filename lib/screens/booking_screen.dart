import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/establishment_model.dart';
import '../models/service_model.dart';
import '../models/worker_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Pantalla de agendamiento: seleccionar fecha → ver slots → confirmar
class BookingScreen extends StatefulWidget {
  final ServiceModel service;
  final EstablishmentModel establishment;

  const BookingScreen({
    super.key,
    required this.service,
    required this.establishment,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  List<String> _slots = [];
  String? _selectedSlot;
  bool _isLoadingSlots = false;
  bool _isBooking = false;

  // Profesionales
  List<WorkerModel> _workers = [];
  int? _selectedWorkerId; // null = "Cualquiera"
  bool _isLoadingWorkers = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
    _loadSlots();
  }

  String get _fechaFormatted =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    final result = await ApiService.getWorkers(
      widget.establishment.establecimientoId,
      servicioId: widget.service.servicioId,
    );
    if (mounted) {
      setState(() {
        _isLoadingWorkers = false;
        if (result.success && result.data != null) {
          _workers = result.data!;
        }
      });
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _isLoadingSlots = true;
      _selectedSlot = null;
    });

    final result = await ApiService.getAvailableSlots(
      servicioId: widget.service.servicioId,
      fecha: _fechaFormatted,
      trabajadorId: _selectedWorkerId,
    );

    if (mounted) {
      setState(() {
        _isLoadingSlots = false;
        if (result.success && result.data != null) {
          var slots = result.data!;
          // Si la fecha seleccionada es hoy, filtrar horarios ya pasados
          final now = DateTime.now();
          final isToday = _selectedDate.year == now.year &&
              _selectedDate.month == now.month &&
              _selectedDate.day == now.day;
          if (isToday) {
            slots = slots.where((slot) {
              final parts = slot.split(':');
              final slotHour = int.tryParse(parts[0]) ?? 0;
              final slotMin = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
              return slotHour > now.hour ||
                  (slotHour == now.hour && slotMin > now.minute);
            }).toList();
          }
          _slots = slots;
        } else {
          _slots = [];
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadSlots();
    }
  }

  /// Calcula hora_fin sumando la duración del servicio al slot seleccionado
  String _calcHoraFin(String horaInicio) {
    final parts = horaInicio.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final totalMin = h * 60 + m + widget.service.duracionMin;
    final fh = (totalMin ~/ 60).toString().padLeft(2, '0');
    final fm = (totalMin % 60).toString().padLeft(2, '0');
    return '$fh:$fm';
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) return;

    setState(() => _isBooking = true);

    final userId = await StorageService.getUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: no se encontró el usuario')),
        );
        setState(() => _isBooking = false);
      }
      return;
    }

    final result = await ApiService.createAppointment(
      clienteId: userId,
      servicioId: widget.service.servicioId,
      fecha: _fechaFormatted,
      horaInicio: _selectedSlot!,
      horaFin: _calcHoraFin(_selectedSlot!),
      trabajadorId: _selectedWorkerId,
    );

    if (!mounted) return;
    setState(() => _isBooking = false);

    if (result.success) {
      final appt = result.data!;
      final workerName = appt.trabajadorNombreCompleto;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 56),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Cita agendada!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.service.nombre}\n$_fechaFormatted  •  $_selectedSlot',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              if (workerName != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Con $workerName',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // cerrar dialog
                Navigator.pop(context); // volver al detalle
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error al agendar')),
      );
    }
  }

  Widget _buildWorkerSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greyDark, width: 0.5),
      ),
      child: _isLoadingWorkers
          ? Row(
              children: [
                Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Cargando profesionales...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedWorkerId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      hint: Text(
                        'Cualquier profesional',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Cualquier profesional',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        ..._workers.map((w) => DropdownMenuItem<int?>(
                              value: w.trabajadorId,
                              child: Text(
                                w.nombreCompleto,
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedWorkerId = value);
                        _loadSlots();
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final dateLabel = '${_selectedDate.day} de ${months[_selectedDate.month - 1]}, ${_selectedDate.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Agendar cita',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Resumen del servicio ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.greyDark, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.store_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.establishment.nombre,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(widget.service.nombre,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(widget.service.precioFormateado,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text(widget.service.duracionFormateada,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // ── Selector de profesional ──
          _buildWorkerSelector(),

          // ── Selector de fecha ──
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.greyDark, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),

          // ── Label "Horarios disponibles" ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Horarios disponibles',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Grid de slots ──
          Expanded(
            child: _isLoadingSlots
                ? Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _slots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_rounded,
                                size: 48,
                                color:
                                    AppColors.textSecondary.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No hay horarios disponibles\npara esta fecha',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          final isSelected = _selectedSlot == slot;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedSlot = slot),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.greyDark,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Botón confirmar ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _selectedSlot != null && !_isBooking
                          ? _confirmBooking
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.greyDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Confirmar cita',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
