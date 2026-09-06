import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Fluxo de denúncia de projeto (rodada 6, §10–§15):
/// ⋮ "Reportar projeto" → escolha do motivo → envio para a moderação.
///
/// Regras:
///  • reportar NUNCA remove o projeto — só enfileira para análise;
///  • quem participa do projeto (autor/colaborador) não o denuncia;
///  • o mesmo usuário não empilha denúncias pendentes no mesmo projeto;
///  • o autor do projeto nunca sabe quem denunciou.
Future<void> showProjectReportDialog(
    BuildContext context, WidgetRef ref, Project project) async {
  final me = await ref.read(currentUserProvider.future);
  if (!context.mounted) return;

  if (!PermissionService.canReportProject(me, project)) {
    AppToast.show(
        context, 'Você não pode denunciar um projeto do qual participa.');
    return;
  }

  // Já existe denúncia pendente deste usuário para este projeto?
  final pending = await ref.read(reportRepositoryProvider).myPendingReports();
  if (!context.mounted) return;
  if (pending.any((r) => r.projectId == project.id)) {
    AppToast.show(context,
        'Você já denunciou este projeto. A moderação vai analisar.');
    return;
  }

  await AppModal.show(
    context,
    title: 'Reportar projeto',
    child: _ReportForm(project: project),
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.project});

  final Project project;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  ReportReason _reason = ReportReason.conteudoInadequado;
  final _description = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final description = _description.text.trim();
    if (_reason == ReportReason.outro && description.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(reportRepositoryProvider).reportProject(
            widget.project.id,
            reason: _reason,
            description: _reason == ReportReason.outro ? description : null,
          );
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.show(
            context, 'Denúncia enviada para análise da moderação.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Por que você está denunciando "${widget.project.title}"? '
          'A moderação do Conecta vai analisar — o autor não saberá quem denunciou.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        RadioGroup<ReportReason>(
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v ?? _reason),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in ReportReason.values)
                RadioListTile<ReportReason>(
                  value: reason,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(reason.label, style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
        ),
        if (_reason == ReportReason.outro) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _description,
            label: 'Descreva o problema',
            hint: 'Conte em poucas palavras o que há de errado.',
            maxLines: 3,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Enviar denúncia',
                icon: Icons.flag_outlined,
                loading: _sending,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
