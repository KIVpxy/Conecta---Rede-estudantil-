import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/tokens.dart';
import '../../core/utils/limits.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';

final _schoolsProvider =
    FutureProvider.family<List<School>, String>((ref, query) {
  return ref.watch(schoolRepositoryProvider).listSchools(query: query);
});

/// Edição de perfil (§2): nome, foto, bio, Instagram, X, contato e
/// escola. NUNCA permite escolher cargo, virar Developer ou ativar
/// moderação (§46) — o cargo é definido exclusivamente no backend.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _xCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  String? _avatarUrl; // null = remover foto (fallback de iniciais)
  String? _schoolId;
  String _schoolQuery = '';
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _instagramCtrl.dispose();
    _xCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  void _load(UserProfile user) {
    if (_loaded) return;
    _loaded = true;
    _nameCtrl.text = user.name;
    _bioCtrl.text = user.bio ?? '';
    _instagramCtrl.text = user.instagram ?? '';
    _xCtrl.text = user.xHandle ?? '';
    _contactCtrl.text = user.contactNumber ?? '';
    _avatarUrl = user.avatarUrl;
    _schoolId = user.schoolId;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _load(me);

    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;
    final schools = ref.watch(_schoolsProvider(_schoolQuery)).value ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/perfil/${me.username}'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Editar perfil',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ---- Foto (§3): selecionar, pré-visualizar, remover ----
              // A moldura do rank NÃO faz parte da imagem do usuário.
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Row(
                  children: [
                    AppAvatar(
                      url: _avatarUrl,
                      name: _nameCtrl.text.isEmpty ? me.name : _nameCtrl.text,
                      size: 72,
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Foto de perfil',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Sem foto, suas iniciais aparecem como avatar.',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              AppButton(
                                label: 'Selecionar foto',
                                icon: Icons.photo_library_outlined,
                                variant: AppButtonVariant.secondary,
                                onPressed: _pickPhoto,
                              ),
                              if (_avatarUrl != null)
                                AppButton(
                                  label: 'Remover foto',
                                  icon: Icons.delete_outline,
                                  variant: AppButtonVariant.ghost,
                                  onPressed: () =>
                                      setState(() => _avatarUrl = null),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---- Nome ----
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Nome de exibição',
                      hint: 'Como você aparece no Conecta',
                      maxLength: AppLimits.displayNameMaxLength,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Bio multilinha (§4) — quebras preservadas no perfil.
                    AppTextField(
                      controller: _bioCtrl,
                      label: 'Bio',
                      hint: 'Conte um pouco sobre você…',
                      maxLines: 5,
                      maxLength: AppLimits.bioMaxLength,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Redes sociais e contato (§5) — opcionais; os
                    // vazios não aparecem no perfil público.
                    AppTextField(
                      controller: _instagramCtrl,
                      label: 'Instagram (opcional)',
                      hint: 'seu.usuario',
                      prefixText: '@',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _xCtrl,
                      label: 'X / Twitter (opcional)',
                      hint: 'seu.usuario',
                      prefixText: '@',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _contactCtrl,
                      label: 'Número de contato (opcional)',
                      hint: '(82) 99999-9999',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---- Escola (§9): busca + lista filtrada, nunca texto
              // livre. O perfil guarda o ID da escola.
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Escola',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Pesquise e selecione sua escola na lista.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Buscar escola',
                      hint: 'Nome, cidade ou estado…',
                      prefixIcon: Icons.search,
                      onChanged: (v) =>
                          setState(() => _schoolQuery = v.trim()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final school in schools)
                      _SchoolOption(
                        school: school,
                        selected: _schoolId == school.id,
                        onTap: () => setState(() => _schoolId = school.id),
                      ),
                    if (schools.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(
                          'Nenhuma escola encontrada para essa busca.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _saving ? 'Salvando…' : 'Salvar alterações',
                      icon: Icons.check,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1024);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // Mock: data URL. No Supabase (futuro): upload no Storage e a
      // URL pública é salva em profiles.avatar_url.
      final dataUrl =
          'data:image/${picked.name.split('.').last};base64,${base64Encode(bytes)}';
      setState(() => _avatarUrl = dataUrl);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Não foi possível selecionar a imagem.');
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      AppToast.show(context, 'Informe um nome de exibição válido.');
      return;
    }
    setState(() => _saving = true);
    final me = ref.read(currentUserProvider).value;
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            ProfileUpdate(
              name: name,
              avatarUrl: _avatarUrl,
              clearAvatar: _avatarUrl == null && me?.avatarUrl != null,
              bio: _bioCtrl.text.trim(),
              instagram: _instagramCtrl.text.trim(),
              xHandle: _xCtrl.text.trim(),
              contactNumber: _contactCtrl.text.trim(),
              schoolId: _schoolId,
            ),
          );
      // Nome/foto mudaram: invalida os caches para refletir em todo o
      // app (as telas referenciam o mesmo perfil — §2).
      ref.invalidate(currentUserProvider);
      // Troca de escola: estatísticas das comunidades mudam (rodada 6).
      ref.invalidate(schoolStatsProvider);
      if (mounted) {
        AppToast.show(context, 'Perfil atualizado!');
        context.go('/perfil/${me?.username ?? ''}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SchoolOption extends StatelessWidget {
  const _SchoolOption({
    required this.school,
    required this.selected,
    required this.onTap,
  });

  final School school;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.pastelLavanda.withValues(alpha: 0.14)
                : AppColors.surface2,
            borderRadius: AppRadii.controlRadius,
            border: Border.all(
              color: selected ? AppColors.pastelLavanda : AppColors.borderSoft,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.school_outlined,
                size: 18,
                color: selected
                    ? AppColors.pastelLavanda
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(school.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    Text(school.location,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
