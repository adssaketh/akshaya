import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../diagnostics/diag.dart';
import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';

/// The search box used on every list screen: a full pill with a search icon
/// and a clear button once something is typed.
///
/// It owns its focus node and, when tapped, asks the keyboard to open
/// explicitly (and again if it has still not appeared shortly after). It also
/// writes focus and keyboard changes to the diagnostics log, so a report from
/// a phone shows what happened when the field was tapped.
class AkshayaSearchField extends StatefulWidget {
  const AkshayaSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.logName = 'search',
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  /// Name used in the diagnostics log lines.
  final String logName;

  @override
  State<AkshayaSearchField> createState() => _AkshayaSearchFieldState();
}

class _AkshayaSearchFieldState extends State<AkshayaSearchField>
    with WidgetsBindingObserver {
  late final FocusNode _node = FocusNode(debugLabel: 'AkshayaSearchField');
  bool _keyboardUp = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _node.removeListener(_onFocusChanged);
    _node.dispose();
    super.dispose();
  }

  bool get _keyboardVisible {
    if (!mounted) {
      return false;
    }
    return View.of(context).viewInsets.bottom > 0;
  }

  void _onFocusChanged() {
    Diag.info(
      widget.logName,
      _node.hasFocus ? 'Field focused' : 'Field lost focus',
    );
    if (_node.hasFocus) {
      _ensureKeyboard();
    }
  }

  @override
  void didChangeMetrics() {
    final bool up = _keyboardVisible;
    if (up != _keyboardUp) {
      _keyboardUp = up;
      Diag.info(widget.logName, up ? 'Keyboard shown' : 'Keyboard hidden');
    }
  }

  /// Opens the keyboard now, and once more if it is still not up a moment
  /// later while the field has focus.
  void _ensureKeyboard() {
    _showKeyboard();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || !_node.hasFocus || _keyboardVisible) {
          return;
        }
        Diag.warn(
          widget.logName,
          'Field has focus but the keyboard is not showing; asking again',
        );
        _showKeyboard();
      }),
    );
  }

  void _showKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _node.hasFocus) {
        unawaited(
          SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
        );
      }
    });
  }

  void _onTap() {
    Diag.info(widget.logName, 'Field tapped');
    if (!_node.hasFocus) {
      _node.requestFocus();
    } else {
      _ensureKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        return TextField(
          controller: widget.controller,
          focusNode: _node,
          onChanged: widget.onChanged,
          onTap: _onTap,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          // Names are typed in romanised Telugu and Hindi as well as English,
          // which autocorrect would "fix" into other words.
          autocorrect: false,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                      _node.requestFocus();
                    },
                  ),
            border: border(colors.outline),
            enabledBorder: border(colors.outline),
            focusedBorder: border(colors.primary, width: 2),
          ),
        );
      },
    );
  }
}
