import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/profile_photo_service.dart';
import '../login_screen.dart';
import '../edit_profile_screen.dart';

/// Tab de perfil de usuario
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserModel? _user;
  bool _isLoading = true;
  File? _profilePhoto;
  int _photoTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    // Usa getCurrentUser() que obtiene datos del usuario actual via /users/me
    final result = await ApiService.getCurrentUser();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _user = result.data;
          // Carga la foto de perfil
          _loadProfilePhoto();
        }
      });
    }
  }

  Future<void> _loadProfilePhoto() async {
    if (_user == null) return;
    // Limpiar caché de imagen anterior
    if (_profilePhoto != null) {
      FileImage(_profilePhoto!).evict();
    }
    imageCache.clear();
    imageCache.clearLiveImages();
    final photo = await ProfilePhotoService.getProfilePhoto(_user!.usuarioId);
    if (mounted) {
      setState(() {
        _profilePhoto = photo;
        _photoTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Cerrar Sesion',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Estas seguro de que quieres salir?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                child: Column(
                  children: [
                    // Header con avatar
                    _buildHeader(),
                    const SizedBox(height: 32),

                    // Informacion del usuario
                    _buildUserInfo(),
                    const SizedBox(height: 24),

                    // Opciones
                    _buildOptions(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Avatar con foto de perfil
        Container(
          key: ValueKey('profile_avatar_$_photoTimestamp'),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary,
              width: 3,
            ),
            image: _profilePhoto != null
                ? DecorationImage(
                    image: FileImage(File(_profilePhoto!.path)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _profilePhoto == null
              ? Center(
                  child: Text(
                    _user != null
                        ? '${_user!.nombre[0]}${_user!.apellido[0]}'.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),

        // Nombre
        Text(
          _user?.nombreCompleto ?? 'Usuario',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _user?.correo ?? '',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    if (_user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'No se pudieron cargar los datos',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.greyDark),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Nombre',
            value: _user!.nombre,
          ),
          const Divider(color: AppColors.greyDark, height: 24),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Apellido',
            value: _user!.apellido,
          ),
          const Divider(color: AppColors.greyDark, height: 24),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Correo',
            value: _user!.correo,
          ),
          const Divider(color: AppColors.greyDark, height: 24),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Miembro desde',
            value: _formatDate(_user!.fechaCreacion),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        // Editar perfil
        _OptionTile(
          icon: Icons.edit_outlined,
          title: 'Editar perfil',
          onTap: () async {
            if (_user == null) return;
            
            // Navega a editar perfil y espera resultado
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(user: _user!),
              ),
            );
            
            // Si hubo cambios (result == true), recarga los datos
            if (result == true) {
              _loadUserData();
            }
          },
        ),
        const SizedBox(height: 12),

        // Configuracion
        _OptionTile(
          icon: Icons.settings_outlined,
          title: 'Configuracion',
          onTap: () {
            // Navegar a configuracion
          },
        ),
        const SizedBox(height: 12),

        // Cerrar sesion
        _OptionTile(
          icon: Icons.logout_rounded,
          title: 'Cerrar sesion',
          isDestructive: true,
          onTap: _logout,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Fila de informacion
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tile de opcion
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? AppColors.error.withOpacity(0.3)
                : AppColors.greyDark,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? AppColors.error : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive ? AppColors.error : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
