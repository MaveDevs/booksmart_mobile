import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

/// Diálogo de calificación con estrellas y comentario.
/// Retorna `true` si la reseña se envió correctamente.
class RatingDialog extends StatefulWidget {
  final int establecimientoId;
  final int usuarioId;
  final String establecimientoNombre;

  const RatingDialog({
    super.key,
    required this.establecimientoId,
    required this.usuarioId,
    required this.establecimientoNombre,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;

    setState(() => _isSubmitting = true);

    final result = await ApiService.createRating(
      establecimientoId: widget.establecimientoId,
      usuarioId: widget.usuarioId,
      calificacion: _rating,
      comentario: _commentController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error al enviar reseña')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Calificar servicio',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.establecimientoNombre,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Estrellas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starNum),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starNum <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: starNum <= _rating
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _rating == 0 ? 'Toca para calificar' : '$_rating de 5',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // Comentario
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Escribe un comentario (opcional)',
                hintStyle: TextStyle(color: AppColors.placeholder),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.greyDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.greyDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: (_rating == 0 || _isSubmitting) ? null : _submit,
          child: _isSubmitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Enviar',
                  style: TextStyle(
                    color: _rating == 0
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
