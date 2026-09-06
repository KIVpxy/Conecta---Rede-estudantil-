import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../app/auth_state.dart';
import '../../app/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      AppToast.show(context, 'Preencha e-mail e senha para continuar.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
      ref.read(authStateProvider).signIn();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, _loginErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Traduz o erro real do backend/rede para uma mensagem útil —
  /// nunca engolir a causa atrás de um "confira seus dados" genérico.
  String _loginErrorMessage(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login credentials')) {
        return 'E-mail ou senha incorretos.';
      }
      if (m.contains('email not confirmed')) {
        return 'Confirme seu e-mail antes de entrar (veja sua caixa de entrada).';
      }
      return 'Erro de autenticação: ${e.message}';
    }
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('connection') ||
        s.contains('network')) {
      return 'Sem conexão com o servidor. Verifique a internet e tente de novo.';
    }
    return 'Não foi possível entrar. Detalhe: ${e.toString().length > 120 ? '${e.toString().substring(0, 120)}…' : e}';
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
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: AppRadii.controlRadius,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.onAccent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Bem-vindo de volta 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Continue criando de onde parou.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    controller: _email,
                    label: 'E-mail',
                    hint: 'voce@escola.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _password,
                    label: 'Senha',
                    hint: '••••••••',
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Entrar',
                    loading: _loading,
                    expand: true,
                    onPressed: _signIn,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Criar minha conta',
                    variant: AppButtonVariant.ghost,
                    expand: true,
                    onPressed: () => context.go('/signup'),
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
