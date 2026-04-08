import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/profile_photo_service.dart';
import 'login_screen.dart';

/// Pantalla para editar el perfil del usuario
///

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos editables
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _correoController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  bool _isLoading = false;
  bool _changePassword = false; // Toggle para mostrar campos de contraseña
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;
  File? _profilePhoto; // Foto de perfil local
  bool _photoChanged = false; // Indica si la foto fue cambiada
  int _photoTimestamp = DateTime.now().millisecondsSinceEpoch; // Para forzar recarga de imagen

  @override
  void initState() {
    super.initState();
    // Inicializa los controladores con los datos actuales del usuario
    _nombreController = TextEditingController(text: widget.user.nombre);
    _apellidoController = TextEditingController(text: widget.user.apellido);
    _correoController = TextEditingController(text: widget.user.correo);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    // Carga la foto de perfil si existe
    _loadProfilePhoto();
  }

  /// Carga la foto de perfil desde almacenamiento local
  Future<void> _loadProfilePhoto() async {
    final photo = await ProfilePhotoService.getProfilePhoto(widget.user.usuarioId);
    if (photo != null && mounted) {
      setState(() => _profilePhoto = photo);
    }
  }

  /// Muestra opciones para cambiar la foto de perfil
  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Cambiar foto de perfil',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_outlined, color: AppColors.primary),
                ),
                title: Text('Galería', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('Selecciona de tu galería', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () async {
                  Navigator.pop(context);
                  final photo = await ProfilePhotoService.pickFromGallery(widget.user.usuarioId);
                  if (photo != null && mounted) {
                    // Limpiar caché de la imagen anterior
                    if (_profilePhoto != null) {
                      FileImage(_profilePhoto!).evict();
                    }
                    imageCache.clear();
                    imageCache.clearLiveImages();
                    setState(() {
                      _profilePhoto = photo;
                      _photoChanged = true;
                      _photoTimestamp = DateTime.now().millisecondsSinceEpoch;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Foto de perfil guardada'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                ),
                title: Text('Cámara', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text('Toma una nueva foto', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () async {
                  Navigator.pop(context);
                  final photo = await ProfilePhotoService.pickFromCamera(widget.user.usuarioId);
                  if (photo != null && mounted) {
                    // Limpiar caché de la imagen anterior
                    if (_profilePhoto != null) {
                      FileImage(_profilePhoto!).evict();
                    }
                    imageCache.clear();
                    imageCache.clearLiveImages();
                    setState(() {
                      _profilePhoto = photo;
                      _photoChanged = true;
                      _photoTimestamp = DateTime.now().millisecondsSinceEpoch;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Foto de perfil guardada'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              if (_profilePhoto != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline, color: AppColors.error),
                  ),
                  title: Text('Eliminar foto', style: TextStyle(color: AppColors.error)),
                  subtitle: Text('Quitar foto de perfil', style: TextStyle(color: AppColors.textSecondary)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ProfilePhotoService.deleteProfilePhoto(widget.user.usuarioId);
                    if (mounted) {
                      setState(() {
                        _profilePhoto = null;
                        _photoChanged = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Foto de perfil eliminada'),
                          backgroundColor: AppColors.textSecondary,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Limpia los controladores cuando se destruye el widget
    _nombreController.dispose();
    _apellidoController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Valida que el nombre no esté vacío
  String? _validateNombre(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es requerido';
    }
    if (value.trim().length < 2) {
      return 'Mínimo 2 caracteres';
    }
    return null;
  }

  /// Valida que el apellido no esté vacío
  String? _validateApellido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El apellido es requerido';
    }
    if (value.trim().length < 2) {
      return 'Mínimo 2 caracteres';
    }
    return null;
  }

  /// Valida el formato del correo electrónico
  String? _validateCorreo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es requerido';
    }
    // Expresión regular para validar email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// Valida la contraseña si el usuario quiere cambiarla
  String? _validatePassword(String? value) {
    if (!_changePassword) return null; // No validar si no quiere cambiar
    if (value == null || value.isEmpty) {
      return 'Ingresa la nueva contraseña';
    }
    if (value.length < 4) {
      return 'Mínimo 4 caracteres';
    }
    return null;
  }

  /// Valida que las contraseñas coincidan
  String? _validateConfirmPassword(String? value) {
    if (!_changePassword) return null;
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  /// Guarda los cambios del perfil
  ///
  /// FLUJO:
  /// 1. Valida el formulario
  /// 2. Compara cada campo con el valor original
  /// 3. Solo envía los campos que cambiaron (PATCH)
  /// 4. NUNCA envía rol_id ni activo
  ///
  Future<void> _saveChanges() async {
    // Limpia mensajes previos
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    // Valida el formulario
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Prepara solo los campos que cambiaron
    // Esto es importante para:
    // 1. Reducir datos enviados al servidor
    // 2. Evitar sobrescribir datos accidentalmente
    String? nuevoNombre;
    String? nuevoApellido;
    String? nuevoCorreo;
    String? nuevaContrasena;

    // Compara con los valores originales
    if (_nombreController.text.trim() != widget.user.nombre) {
      nuevoNombre = _nombreController.text.trim();
    }
    if (_apellidoController.text.trim() != widget.user.apellido) {
      nuevoApellido = _apellidoController.text.trim();
    }
    if (_correoController.text.trim() != widget.user.correo) {
      nuevoCorreo = _correoController.text.trim();
    }
    if (_changePassword && _passwordController.text.isNotEmpty) {
      nuevaContrasena = _passwordController.text;
    }

    // Si no hay cambios en los campos de texto
    if (nuevoNombre == null &&
        nuevoApellido == null &&
        nuevoCorreo == null &&
        nuevaContrasena == null) {
      setState(() => _isLoading = false);

      // Si solo cambió la foto, mostrar éxito y regresar
      if (_photoChanged) {
        setState(() {
          _successMessage = 'Perfil actualizado correctamente';
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        setState(() {
          _successMessage = 'No hay cambios para guardar';
        });
      }
      return;
    }

    // Llama al API para actualizar
    // NOTA: El método updateUser NO envía rol_id ni activo
    // Esto es intencional para seguridad
    final result = await ApiService.updateUser(
      userId: widget.user.usuarioId,
      nombre: nuevoNombre,
      apellido: nuevoApellido,
      correo: nuevoCorreo,
      contrasena: nuevaContrasena,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _successMessage = 'Perfil actualizado correctamente';
        _changePassword = false;
        _passwordController.clear();
        _confirmPasswordController.clear();
      });

      // Regresa a la pantalla anterior con el usuario actualizado
      // El pop(true) indica que hubo cambios
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  /// Muestra diálogo de confirmación para eliminar cuenta
  ///
  /// SEGURIDAD:
  /// 1. Requiere la contraseña actual del usuario
  /// 2. Verifica la contraseña con el servidor antes de eliminar
  /// 3. No elimina datos, solo desactiva (soft delete)
  ///
  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isVerifying = false;
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Eliminar Cuenta',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción desactivará tu cuenta. No podrás iniciar sesión hasta que un administrador la reactive.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text(
                'Ingresa tu contraseña para confirmar:',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tu contraseña',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  errorText: errorText,
                  filled: true,
                  fillColor: AppColors.background,
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.error),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setDialogState(() => obscurePassword = !obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        setDialogState(() => errorText = 'Ingresa tu contraseña');
                        return;
                      }

                      setDialogState(() {
                        isVerifying = true;
                        errorText = null;
                      });

                      // Verifica la contraseña intentando hacer login
                      final result = await ApiService.login(
                        email: widget.user.correo,
                        password: passwordController.text,
                      );

                      if (result.success) {
                        Navigator.of(context).pop(true);
                      } else {
                        setDialogState(() {
                          isVerifying = false;
                          errorText = 'Contraseña incorrecta';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );

    // Si confirmó, procede a desactivar la cuenta
    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  /// Desactiva la cuenta del usuario
  ///
  /// FLUJO:
  /// 1. Llama al API con activo: false
  /// 2. El servidor marca la cuenta como inactiva
  /// 3. Se limpia la sesión local
  /// 4. Redirige al login
  ///
  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    final result = await ApiService.deactivateAccount(widget.user.usuarioId);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      // Limpia toda la información local
      await StorageService.clearAll();

      // Navega al login y limpia el stack de navegación
      Navigator.of(context).pushAndRemoveUntil(
        appFadeRoute(const LoginScreen()),
        (route) => false,
      );

      // Muestra mensaje de despedida
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tu cuenta ha sido desactivada'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(height: 32),

                // Mensajes de error/éxito
                if (_errorMessage != null) _buildErrorMessage(),
                if (_successMessage != null) _buildSuccessMessage(),

                // Campos editables
                _buildEditableFields(),
                const SizedBox(height: 24),

                // Sección de contraseña
                _buildPasswordSection(),
                const SizedBox(height: 32),

                // Botón guardar
                _buildSaveButton(),
                const SizedBox(height: 48),

                // Zona de peligro
                _buildDangerZone(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Stack(
              children: [
                Container(
                  key: ValueKey('avatar_$_photoTimestamp'),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
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
                            widget.user.iniciales,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showPhotoOptions,
            child: Text(
              'Cambiar foto',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          Text(
            'ID: ${widget.user.usuarioId}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.greyDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Personal',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Campo Nombre
          TextFormField(
            controller: _nombreController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _validateNombre,
          ),
          const SizedBox(height: 16),

          // Campo Apellido
          TextFormField(
            controller: _apellidoController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Apellido',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _validateApellido,
          ),
          const SizedBox(height: 16),

          // Campo Correo
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _validateCorreo,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.greyDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cambiar Contraseña',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _changePassword,
                onChanged: (value) {
                  setState(() {
                    _changePassword = value;
                    if (!value) {
                      // Limpia los campos si desactiva
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    }
                  });
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),

          // Campos de contraseña (solo si está activado)
          if (_changePassword) ...[
            const SizedBox(height: 16),
            Text(
              'La nueva contraseña debe tener al menos 4 caracteres',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Nueva contraseña
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),

            // Confirmar contraseña
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),
              validator: _validateConfirmPassword,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveChanges,
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : const Text('Guardar Cambios'),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 12),
              Text(
                'Zona de Peligro',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Al eliminar tu cuenta, no podrás iniciar sesión hasta que un administrador la reactive.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _showDeleteAccountDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Eliminar mi cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}
