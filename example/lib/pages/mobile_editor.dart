import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MobileEditor extends StatefulWidget {
  const MobileEditor({
    super.key,
    required this.editorState,
    this.editorStyle,
  });

  final EditorState editorState;
  final EditorStyle? editorStyle;

  @override
  State<MobileEditor> createState() => _MobileEditorState();
}

class _MobileEditorState extends State<MobileEditor> {
  EditorState get editorState => widget.editorState;

  late final EditorScrollController editorScrollController;

  late EditorStyle editorStyle;
  late Map<String, BlockComponentBuilder> blockComponentBuilders;

  @override
  void initState() {
    super.initState();

    editorScrollController = EditorScrollController(
      editorState: editorState,
      shrinkWrap: false,
    );

    editorStyle = _buildMobileEditorStyle();
    blockComponentBuilders = _buildBlockComponentBuilders();
  }

  @override
  void reassemble() {
    super.reassemble();

    editorStyle = _buildMobileEditorStyle();
    blockComponentBuilders = _buildBlockComponentBuilders();
  }

  @override
  Widget build(BuildContext context) {
    assert(PlatformExtension.isMobile);
    return Column(
      children: [
        // build appflowy editor
        SizedBox(
          height: 300,
          width: MediaQuery.of(context).size.width,
          child: AppFlowyEditor(
            editorStyle: editorStyle,
            editorState: editorState,
            editorScrollController: editorScrollController,
            characterShortcutEvents: [
              hashTagEvent,
              mensionEvent,
              newLineHashTagEvent,
              newLineMensionEvent,
              zenkakuMensionEvent,
              zenkakuHashTagEvent,
            ],
            footer: const SizedBox(
              height: 100,
            ),
          ),
        ),
      ],
    );
  }

  // showcase 1: customize the editor style.
  EditorStyle _buildMobileEditorStyle() {
    return EditorStyle.mobile(
      cursorColor: const Color.fromARGB(255, 134, 46, 247),
      dragHandleColor: const Color.fromARGB(255, 134, 46, 247),
      selectionColor: const Color.fromARGB(50, 134, 46, 247),
      textStyleConfiguration: TextStyleConfiguration(
        text: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black,
        ),
        code: GoogleFonts.sourceCodePro(
          backgroundColor: Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      magnifierSize: const Size(144, 96),
      mobileDragHandleBallSize: const Size(12, 12),
      showLine: false,
    );
  }

  // showcase 2: customize the block style
  Map<String, BlockComponentBuilder> _buildBlockComponentBuilders() {
    final map = {
      ...standardBlockComponentBuilderMap,
    };
    // customize the heading block component
    final levelToFontSize = [
      24.0,
      22.0,
      20.0,
      18.0,
      16.0,
      14.0,
    ];
    map[HeadingBlockKeys.type] = HeadingBlockComponentBuilder(
      textStyleBuilder: (level) => GoogleFonts.poppins(
        fontSize: levelToFontSize.elementAtOrNull(level - 1) ?? 14.0,
        fontWeight: FontWeight.w600,
      ),
    );
    map[ParagraphBlockKeys.type] = ParagraphBlockComponentBuilder(
      configuration: BlockComponentConfiguration(
        placeholderText: (node) => 'Type something...',
      ),
    );
    return map;
  }
}

CharacterShortcutEvent hashTagEvent = CharacterShortcutEvent(
  key: 'sharp to hashtag',
  character: ' ',
  handler: (editorState) async {
    return handleFormatByWrappingHashtagLink(
      editorState: editorState,
      character: '#',
      shouldNewLine: false,
    );
  },
);

CharacterShortcutEvent mensionEvent = CharacterShortcutEvent(
  key: 'at to mension',
  character: ' ',
  handler: (editorState) async {
    return handleFormatByWrappingHashtagLink(
      editorState: editorState,
      character: '@',
      shouldNewLine: false,
    );
  },
);

CharacterShortcutEvent zenkakuHashTagEvent = CharacterShortcutEvent(
  key: 'sharp to hashtag zenkaku',
  character: '　',
  handler: (editorState) async {
    return handleFormatByWrappingHashtagLink(
      editorState: editorState,
      character: '#',
      shouldNewLine: false,
    );
  },
);

CharacterShortcutEvent zenkakuMensionEvent = CharacterShortcutEvent(
  key: 'at to mension zenkaku',
  character: '　',
  handler: (editorState) async {
    return await handleFormatByWrappingHashtagLink(
      editorState: editorState,
      character: '@',
      shouldNewLine: false,
    );
  },
);

CharacterShortcutEvent newLineHashTagEvent = CharacterShortcutEvent(
  key: 'sharp to hashtag newline',
  character: '\n',
  handler: (editorState) async {
    return handleFormatByWrappingHashtagLink(
      editorState: editorState,
      character: '#',
      shouldNewLine: true,
    );
  },
);

CharacterShortcutEvent newLineMensionEvent = CharacterShortcutEvent(
  key: 'at to mension newline',
  character: '\n',
  handler: (editorState) async {
    return handleFormatByWrappingHashtagLink(
      editorState: editorState,
      character: '@',
      shouldNewLine: true,
    );
  },
);

Future<bool> handleFormatByWrappingHashtagLink({
  required EditorState editorState,
  required String character,
  required bool shouldNewLine,
}) async {
  final selection = editorState.selection;
  // if the selection is not collapsed or the cursor is
  // at the first two index range, we don't need to format it.
  // we should return false to let the IME handle it.
  if (selection == null || !selection.isCollapsed || selection.end.offset < 2) {
    return false;
  }

  final path = selection.end.path;
  final node = editorState.getNodeAtPath(path);
  final delta = node?.delta;
  // if the node doesn't contain the delta(which means it isn't a text)
  // we don't need to format it.
  if (node == null || delta == null) {
    return false;
  }

  final plainText = delta.toPlainText();

  final headCharIndex = plainText.lastIndexOf(character);

  // Determine if a 'Character' already exists in the node and only once.
  // 1. This is no 'Character' in the plainText: indexOf returns -1.
  // 2. More than one 'Character' in the plainText: the headCharIndex
  // and endCharIndex are supposed to be the same, if not, which means
  // plainText has more than one character. For example: when plainText is
  // '_abc', it will trigger formatting(remind:the last char is used to
  // trigger the formatting,so it won't be counted in the plainText.).
  // But adding '_' after 'a__ab' won't trigger formatting.
  // 3. there are two characters connecting together,
  // like adding '_' after 'abc_' won't trigger formatting.
  if (headCharIndex == -1 || headCharIndex == selection.end.offset - 1) {
    return false;
  }

  // To minimize errors, retrieve the format style from an enum
  // that is specific to single characters.
  const style = 'href';

  // if the text is already formatted, we should remove the format.
  final sliced = delta.slice(
    headCharIndex,
    selection.end.offset,
  );

  var hrefText = '';
  var shouldFormating = true;

  for (final texts in sliced) {
    final textJson = texts.toJson();
    if (textJson.containsKey('attributes')) {
      final attributes = textJson['attributes'] as Map<String, dynamic>;
      if (attributes.containsKey('href')) {
        shouldFormating = false;
        break;
      }
    }

    hrefText = textJson['insert'] as String;
    break;
  }

  if (!shouldFormating) {
    return false;
  }

  if (hrefText == '') {
    return false;
  }

  final format = editorState.transaction
    ..formatText(
      node,
      headCharIndex,
      selection.end.offset - headCharIndex,
      {
        style: hrefText,
      },
    )
    ..afterSelection = Selection.collapsed(
      Position(
        path: path,
        offset: selection.end.offset,
      ),
    );
  await editorState.apply(format);

  if (shouldNewLine) {
    // delete the selection
    await editorState.deleteSelection(selection);
    // insert a new line
    await editorState.insertNewLine(position: selection.start);
  } else {
    // insert space after # or @
    await editorState.insertTextAtPosition(' ');
  }
  return true;
}
