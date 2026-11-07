import 'package:flutter/material.dart';

import '../tokens/app_shape.dart';

/// Um campo de texto com rótulo. A variante [AppTextField.password]
/// esconde o texto e oferece o botão de mostrá-lo; os dois rótulos desse
/// botão são obrigatórios, porque o pacote não tem texto próprio e o
/// leitor de tela precisa dizer o que o ícone faz.
final class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  }) : obscure = false,
       showLabel = null,
       hideLabel = null;

  const AppTextField.password({
    super.key,
    required this.controller,
    required this.label,
    required String this.showLabel,
    required String this.hideLabel,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  }) : obscure = true,
       keyboardType = TextInputType.visiblePassword;

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final String? showLabel;
  final String? hideLabel;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

final class _AppTextFieldState extends State<AppTextField> {
  // Estado efêmero: mostrar ou esconder a senha não interessa a ninguém
  // fora do campo.
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      // Senha não passa pelo corretor nem pelas sugestões do teclado.
      autocorrect: !widget.obscure,
      enableSuggestions: !widget.obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(
          borderRadius: AppBorderRadius.extraSmall,
        ),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? widget.showLabel : widget.hideLabel,
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
