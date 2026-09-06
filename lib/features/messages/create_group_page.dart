import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../../app/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'messages_page.dart';

/// Fluxo "Criar grupo" (§20–§22): nome → imagem opcional → pesquisar
/// usuários → selecionar convidados → criar. Selecionar alguém NÃO o
/// coloca dentro do grupo: um convite é enviado e o convidado decide.
class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = {};
  List<UserProfile> _results = [];
  Timer? _debounce;
  String? _imageUrl;
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = query.trim();
      if (q.isEmpty) {
        setState(() => _results = []);
        return;
      }
      final users =
          await ref.read(projectRepositoryProvider).searchUsers(q);
      final me = ref.read(currentUserProvider).value;
      if (mounted) {
        setState(() {
          _results =
              users.where((u) => u.id != me?.id).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

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
                    onPressed: () => context.go('/mensagens'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Criar grupo',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ---- Nome + imagem opcional ----
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickImage,
                          borderRadius: AppRadii.controlRadius,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.pastelRoxoClaro
                                  .withValues(alpha: 0.14),
                              borderRadius: AppRadii.controlRadius,
                              border: Border.all(
                                  color: AppColors.borderSoft),
                              image: _imageUrl != null
                                  ? DecorationImage(
                                      image: MemoryImage(base64Decode(
                                          _imageUrl!.split(',').last)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _imageUrl == null
                                ? const Icon(Icons.add_a_photo_outlined,
                                    color: AppColors.textSecondary)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: AppTextField(
                            controller: _nameCtrl,
                            label: 'Nome do grupo',
                            hint: 'Ex.: Equipe de Matemática',
                            maxLength: 60,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Imagem opcional — toque no quadrado para escolher.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ---- Convidados ----
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convidar estudantes${_selected.isEmpty ? '' : ' (${_selected.length})'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Quem você selecionar recebe um convite e decide se entra.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSearchField(
                      controller: _searchCtrl,
                      hint: 'Buscar por nome ou @usuário…',
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final user in _results)
                      _InviteOption(
                        user: user,
                        selected: _selected.contains(user.id),
                        onTap: () => setState(() {
                          if (!_selected.remove(user.id)) {
                            _selected.add(user.id);
                          }
                        }),
                      ),
                    if (_searchCtrl.text.trim().isNotEmpty &&
                        _results.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text('Nenhum usuário encontrado.',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _creating
                          ? 'Criando…'
                          : 'Criar grupo e enviar convites',
                      icon: Icons.send_outlined,
                      loading: _creating,
                      onPressed: _creating ? null : _create,
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

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 512);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _imageUrl =
          'data:image/${picked.name.split('.').last};base64,${base64Encode(bytes)}');
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Não foi possível selecionar a imagem.');
      }
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      AppToast.show(context, 'Dê um nome ao grupo.');
      return;
    }
    setState(() => _creating = true);
    try {
      final group =
          await ref.read(messagingRepositoryProvider).createGroup(
                name: name,
                imageUrl: _imageUrl,
                invitedUserIds: _selected.toList(),
              );
      ref.invalidate(conversationsProvider);
      if (mounted) {
        AppToast.show(
            context,
            _selected.isEmpty
                ? 'Grupo criado!'
                : 'Grupo criado! Convites enviados.');
        context.go('/mensagens/${group.id}');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _InviteOption extends ConsumerWidget {
  const _InviteOption({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserProfile user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankFuture = ref.watch(profileRepositoryProvider).rankOf(user.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.controlRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.pastelRoxoClaro.withValues(alpha: 0.12)
                : AppColors.surface2,
            borderRadius: AppRadii.controlRadius,
            border: Border.all(
              color:
                  selected ? AppColors.pastelRoxoClaro : AppColors.borderSoft,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              AppAvatar(url: user.avatarUrl, name: user.name, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FutureBuilder<RankTier>(
                  future: rankFuture,
                  builder: (context, snapshot) => UserDisplayName(
                    name: user.name,
                    rank: snapshot.data ?? RankTier.bronze,
                    isDeveloper: user.isDeveloper,
                  ),
                ),
              ),
              Text('@${user.username}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected
                    ? AppColors.pastelRoxoClaro
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
