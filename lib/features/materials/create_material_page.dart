import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/utils/limits.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'materials_page.dart';

/// Criação de postagem em Materiais (SPEC §3–4):
/// "Nova postagem" / "Criar material" — material, pergunta ou pedido.
class CreateMaterialPage extends ConsumerStatefulWidget {
  const CreateMaterialPage({super.key});

  @override
  ConsumerState<CreateMaterialPage> createState() =>
      _CreateMaterialPageState();
}

class _CreateMaterialPageState extends ConsumerState<CreateMaterialPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  MaterialPostKind _kind = MaterialPostKind.compartilhamento;
  String _subject = 'Matemática';
  bool _publishing = false;

  bool get _valid =>
      _title.text.trim().isNotEmpty && _content.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final padding = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppSpacing.lg
        : AppSpacing.xxxl;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nova postagem',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                  'Compartilhe um material, faça uma pergunta ou peça ajuda.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de postagem',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final k in MaterialPostKind.values)
                          AppFilterChip(
                            label: k.label,
                            selected: _kind == k,
                            onTap: () => setState(() => _kind = k),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _title,
                      label: 'Título',
                      hint: switch (_kind) {
                        MaterialPostKind.compartilhamento =>
                          'Ex.: Resumo completo de Funções',
                        MaterialPostKind.pergunta =>
                          'Ex.: Como balancear essa equação?',
                        MaterialPostKind.pedido =>
                          'Ex.: Alguém tem exercícios de logaritmo?',
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Matéria',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: _subject,
                      decoration: const InputDecoration(),
                      items: [
                        for (final s in materialSubjects.skip(1))
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _subject = v!),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _content,
                      label: 'Conteúdo',
                      hint: switch (_kind) {
                        MaterialPostKind.compartilhamento =>
                          'Descreva o material e cole links úteis...',
                        MaterialPostKind.pergunta =>
                          'Explique sua dúvida com detalhes...',
                        MaterialPostKind.pedido =>
                          'Diga o que você precisa...',
                      },
                      maxLines: 8,
                      maxLength: AppLimits.materialPostMaxLength,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  AppButton(
                    label: 'Cancelar',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go('/materiais'),
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Publicar',
                    icon: Icons.rocket_launch,
                    loading: _publishing,
                    onPressed: _valid ? _publish : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final post = await ref.read(materialRepositoryProvider).createPost(
            title: _title.text.trim(),
            content: _content.text.trim(),
            subject: _subject,
            kind: _kind,
          );
      ref.invalidate(materialsPostsProvider);
      if (mounted) {
        AppToast.show(context, 'Postagem publicada!');
        context.go('/materiais/${post.id}');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }
}
