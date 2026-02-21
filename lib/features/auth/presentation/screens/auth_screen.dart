import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/security/pat_storage_service.dart';
import 'package:gitty/features/auth/presentation/notifiers/auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _patController = TextEditingController();
  final _patFocusNode = FocusNode();
  bool _obscureText = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _patController.dispose();
    _patFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeController.forward(from: 0);
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .signIn(_patController.text.trim());
  }

  Future<void> _onPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      _patController.text = data!.text!.trim();
      _patController.selection =
          TextSelection.collapsed(offset: _patController.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthStateLoading;
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthStateError) _shakeController.forward(from: 0);
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  _buildForm(context, isLoading),
                  const SizedBox(height: 16),
                  if (authState is AuthStateError) ...[
                    _buildErrorCard(context, authState.failure.userMessage),
                    const SizedBox(height: 16),
                  ],
                  _buildSignInButton(context, isLoading),
                  const SizedBox(height: 32),
                  _buildHelpSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.merge_type_rounded,
              size: 32, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 24),
        Text('Welcome to\nGitty',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 8),
        Text(
            'Connect your GitHub account via\nPersonal Access Token to get started.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5)),
      ],
    );
  }

  Widget _buildForm(BuildContext context, bool isLoading) {
    final colorScheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERSONAL ACCESS TOKEN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                  _shakeAnimation.value * 8 * (1 - _shakeAnimation.value), 0),
              child: child,
            ),
            child: TextFormField(
              controller: _patController,
              focusNode: _patFocusNode,
              enabled: !isLoading,
              obscureText: _obscureText,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  letterSpacing: 0.5),
              decoration: InputDecoration(
                hintText: 'github_pat_••••••••••••••••••••',
                hintStyle: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.content_paste_rounded),
                        tooltip: 'Paste',
                        onPressed: isLoading ? null : _onPaste),
                    IconButton(
                      icon: Icon(_obscureText
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _obscureText = !_obscureText),
                    ),
                  ],
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Token cannot be empty';
                final result = PatStorageService.validate(value.trim());
                if (!result.isValid) return result.message;
                return null;
              },
              onFieldSubmitted: (_) => _onSignIn(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onErrorContainer))),
        IconButton(
          icon: Icon(Icons.close_rounded,
              size: 18, color: colorScheme.onErrorContainer),
          onPressed: () => ref.read(authNotifierProvider.notifier).clearError(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _buildSignInButton(BuildContext context, bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: isLoading ? null : _onSignIn,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.login_rounded),
        label: Text(isLoading ? 'Signing in…' : 'Connect GitHub Account',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.help_outline_rounded,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text('How to generate a token',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        _helpStep(context, '1', 'Go to GitHub → Settings → Developer settings'),
        _helpStep(context, '2', 'Select Personal access tokens → Fine-grained'),
        _helpStep(context, '3', 'Grant repo read/write permissions'),
        _helpStep(context, '4', 'Copy and paste the token above'),
      ]),
    );
  }

  Widget _helpStep(BuildContext context, String n, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: colorScheme.primaryContainer, shape: BoxShape.circle),
          child: Text(n,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant, height: 1.4))),
      ]),
    );
  }
}
