import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../app/auth_state.dart';
import '../../app/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _signUp() async {
    if (_name.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 6) {
      AppToast.show(context,
          'Preencha todos os campos (senha com 6+ caracteres).');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            name: _name.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      ref.read(authStateProvider).signIn();
    } on EmailConfirmationRequiredException {
      if (mounted) {
        AppToast.show(
            context, 'Conta criada! Confirme seu e-mail para entrar.');
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, _signUpErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Erros comuns de cadastro traduzidos (usuário já existe, e-mail
  /// inválido, falta de internet) + detalhe técnico para os demais.
  String _signUpErrorMessage(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') || m.contains('already been registered')) {
        return 'Este e-mail já tem conta. Toque em "Já tenho conta".';
      }
      if (m.contains('unable to validate email') || m.contains('invalid')) {
        return 'Este e-mail parece inválido. Confira e tente de novo.';
      }
      return 'Erro no cadastro: ${e.message}';
    }
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('connection') ||
        s.contains('network')) {
      return 'Sem conexão com o servidor. Verifique a internet e tente de novo.';
    }
    return 'Não foi possível criar sua conta. Detalhe: ${e.toString().length > 120 ? '${e.toString().substring(0, 120)}…' : e}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Crie sua conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Transforme uma ideia em projeto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                      controller: _name, label: 'Nome', hint: 'Seu nome'),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                      controller: _username,
                      label: 'Username',
                      hint: 'seuusername'),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                      controller: _email,
                      label: 'E-mail',
                      hint: 'voce@escola.com',
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                      controller: _password,
                      label: 'Senha',
                      hint: '6+ caracteres',
                      obscureText: true),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Criar conta',
                    loading: _loading,
                    expand: true,
                    onPressed: _signUp,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Já tenho conta',
                    variant: AppButtonVariant.ghost,
                    expand: true,
                    onPressed: () => context.go('/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
