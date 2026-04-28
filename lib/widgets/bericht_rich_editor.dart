import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

import '../utils/theme.dart';

/// Notion-aehnlicher Rich-Text-Editor fuer Berichte.
/// Unterstuetzt Headings, Bold/Italic/Underline, Listen, Checkboxen, Code,
/// Quotes, Undo/Redo. Speichert Inhalt als Quill-Delta-JSON.
class BerichtRichEditor extends StatefulWidget {
  /// Initialer Inhalt — entweder Quill-Delta-JSON-String oder Plain Text
  /// (wird automatisch erkannt und konvertiert).
  final String? initialDelta;

  /// Wird mit aktuellem Delta-JSON + Plaintext aufgerufen.
  final void Function(String deltaJson, String plainText)? onChanged;

  /// Hoehe des Editors (mind. 320).
  final double minHeight;

  const BerichtRichEditor({
    super.key,
    this.initialDelta,
    this.onChanged,
    this.minHeight = 380,
  });

  @override
  State<BerichtRichEditor> createState() => BerichtRichEditorState();
}

class BerichtRichEditorState extends State<BerichtRichEditor> {
  late q.QuillController _controller;
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.initialDelta);
    _controller.addListener(_emitChange);
  }

  q.QuillController _buildController(String? initial) {
    if (initial == null || initial.trim().isEmpty) {
      return q.QuillController.basic();
    }
    // Versuche Delta-JSON zu parsen, sonst als Plain Text einfuegen.
    try {
      final decoded = jsonDecode(initial);
      if (decoded is List) {
        final doc = q.Document.fromJson(decoded);
        return q.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {/* fallthrough */}
    // Plain text
    final doc = q.Document()..insert(0, initial);
    return q.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _emitChange() {
    final delta = jsonEncode(_controller.document.toDelta().toJson());
    final plain = _controller.document.toPlainText().trim();
    widget.onChanged?.call(delta, plain);
  }

  @override
  void dispose() {
    _controller.removeListener(_emitChange);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Aktueller Plaintext (z.B. fuer Validierung).
  String get plainText => _controller.document.toPlainText().trim();

  /// Aktueller Delta-JSON (zum Speichern).
  String get deltaJson => jsonEncode(_controller.document.toDelta().toJson());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.slate300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.slate200),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: q.QuillSimpleToolbar(
              controller: _controller,
              configurations: const q.QuillSimpleToolbarConfigurations(
                multiRowsDisplay: false,
                showFontFamily: false,
                showFontSize: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showAlignmentButtons: false,
                showDirection: false,
                showLink: true,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showInlineCode: true,
                showCodeBlock: true,
                showQuote: true,
                showIndent: true,
                showHeaderStyle: true,
                showListBullets: true,
                showListNumbers: true,
                showListCheck: true,
                showClearFormat: true,
                showDividers: true,
                showUndo: true,
                showRedo: true,
              ),
            ),
          ),
          // Editor
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: q.QuillEditor.basic(
                controller: _controller,
                focusNode: _focus,
                scrollController: _scroll,
                configurations: const q.QuillEditorConfigurations(
                  autoFocus: false,
                  expands: false,
                  placeholder: 'Schreiben Sie hier den Bericht …',
                  padding: EdgeInsets.zero,
                  scrollable: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only Anzeige eines Quill-Delta-Inhalts (oder Plain-Text-Fallback).
class BerichtRichViewer extends StatefulWidget {
  final String inhalt; // Delta-JSON oder Plain
  const BerichtRichViewer({super.key, required this.inhalt});

  @override
  State<BerichtRichViewer> createState() => _BerichtRichViewerState();
}

class _BerichtRichViewerState extends State<BerichtRichViewer> {
  late q.QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.inhalt);
  }

  q.QuillController _buildController(String value) {
    if (value.trim().isEmpty) {
      return q.QuillController.basic();
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return q.QuillController(
          document: q.Document.fromJson(decoded),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {/* fallthrough */}
    final doc = q.Document()..insert(0, value);
    return q.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return q.QuillEditor.basic(
      controller: _controller,
      configurations: const q.QuillEditorConfigurations(
        autoFocus: false,
        showCursor: false,
        scrollable: false,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
