import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';

Future<void> onNonTextUpdate(
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
) async {
  var selection = editorState.selection;

  if (selection == null) {
    return;
  }

  if (!selection.isCollapsed) {
    await editorState.deleteSelection(selection);
  }

  selection = editorState.selection?.normalized;
  if (selection == null || !selection.isCollapsed) {
    return;
  }

  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null) {
    return;
  }
  assert(node.delta != null);

  final delta = node.delta!;

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

  final path = node.path;
  final afterSelection = Selection(
    start: selection.start.copyWith(path: path),
    end: selection.end.copyWith(path: path),
  );
  final transaction = editorState.transaction
    ..updateNode(node, {
      'delta': newDelta.toJson(),
    })
    ..afterSelection = afterSelection;
  editorState.apply(transaction);
}
