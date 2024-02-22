import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/character_shortcut_event_helper.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/delta_input_impl.dart';
import 'package:flutter/services.dart';

Future<void> onReplace(
  TextEditingDeltaReplacement replacement,
  EditorState editorState,
  List<CharacterShortcutEvent> characterShortcutEvents,
) async {
  Log.input.debug('onReplace: $replacement');
  // delete the selection
  final selection = editorState.selection;
  if (selection == null) {
    return;
  }

  if (selection.isSingle) {
    final execution = await executeCharacterShortcutEvent(
      editorState,
      replacement.replacementText,
      characterShortcutEvents,
    );

    if (execution) {
      return;
    }

    if (Platform.isIOS) {
      // remove the trailing '\n' when pressing the return key
      if (replacement.replacementText.endsWith('\n')) {
        replacement = TextEditingDeltaReplacement(
          oldText: replacement.oldText,
          replacementText: replacement.replacementText
              .substring(0, replacement.replacementText.length - 1),
          replacedRange: replacement.replacedRange,
          selection: replacement.selection,
          composing: replacement.composing,
        );
      }
    }

    final node = editorState.getNodesInSelection(selection).first;
    final transaction = editorState.transaction;
    int start = replacement.replacedRange.start;
    int end = replacement.replacedRange.end;
    int length = end - start;
    String text = replacement.replacementText;

    Attributes? attributes = node.delta?.first.attributes;
    if (attributes != null) {
      if (attributes.containsKey('href')) {
        attributes.remove('href');
        if (attributes.keys.isEmpty) {
          attributes = null;
        }
      }
    }
    transaction.replaceText(
      node,
      start,
      length,
      text,
      attributes: attributes,
      composing: replacement.composing,
    );

    await editorState.apply(transaction);

    // check composing is left
    final delta = node.delta!;
    final last = delta.last;
    var shouldResetComposing = false;
    if (last.attributes == null) {
      shouldResetComposing = true;
    } else {
      if (!last.attributes!.containsKey('composing')) {
        shouldResetComposing = true;
      } else {
        if (!replacement.composing.isValid) {
          shouldResetComposing = true;
        }
      }
    }

    if (shouldResetComposing) {
      final oldOperations = delta.map((e) => e).toList();
      var newText = '';
      final newOperations = <TextOperation>[];
      for (final old in oldOperations) {
        if (old.attributes != null) {
          if (old.attributes!.containsKey('composing')) {
            newText += (old as TextInsert).text;
          } else {
            newOperations.add(old);
          }
        } else {
          newOperations.add(old);
        }
      }
      newOperations.add(TextInsert(newText));
      final newDelta = Delta(operations: newOperations);

      final afterSelection = Selection.collapsed(
        Position(
          path: node.path,
          offset: start + text.length,
        ),
      );
      final updateTransaction = editorState.transaction
        ..updateNode(node, {
          'delta': newDelta.toJson(),
        })
        ..afterSelection = afterSelection;
      await editorState.apply(updateTransaction);
    }
  } else {
    await editorState.deleteSelection(selection);
    // insert the replacement
    final insertion = replacement.toInsertion();
    await onInsert(
      insertion,
      editorState,
      characterShortcutEvents,
    );
  }
}

extension on TextEditingDeltaReplacement {
  TextEditingDeltaInsertion toInsertion() {
    final text = oldText.replaceRange(
      replacedRange.start,
      replacedRange.end,
      '',
    );
    return TextEditingDeltaInsertion(
      oldText: text,
      textInserted: replacementText,
      insertionOffset: replacedRange.start,
      selection: selection,
      composing: composing,
    );
  }
}
