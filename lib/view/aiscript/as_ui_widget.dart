import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/view/note_create_page/note_create_page.dart";
import "package:dmsky_client/rust/api/aiscript/ui.dart";

class AsUiWidget extends StatelessWidget {
  const AsUiWidget({
    required this.account,
    required this.components,
    this.componentId = "___root___",
    this.onError,
    super.key,
  });

  final Account account;
  final Map<String, AsUiComponent> components;
  final String componentId;
  final void Function(Object error)? onError;

  Future<void> _invoke(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      onError?.call(error);
    }
  }

  Color? _color(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.replaceFirst("#", "");
    try {
      final parsed = int.parse(normalized, radix: 16);
      return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
    } catch (_) {
      return null;
    }
  }

  Widget _child(String id) => AsUiWidget(
    key: ValueKey(id),
    account: account,
    components: components,
    componentId: id,
    onError: onError,
  );

  void _openPostForm(BuildContext context, PostFormPropsForAsUi? form) {
    if (form == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => NoteCreatePage(
          initialAccount: account,
          initialText: form.text,
          initialCw: form.cw,
          initialVisibility: form.visibility == null
              ? null
              : NoteVisibility.values.firstWhere(
                  (value) => value.name == form.visibility,
                  orElse: () => NoteVisibility.public,
                ),
          initialLocalOnly: form.localOnly,
        ).wrappedRoute(routeContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final component = components[componentId];
    if (component == null) return const SizedBox.shrink();

    return switch (component) {
      AsUiComponent_Root(field0: final root) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: root.children.map(_child).toList(),
      ),
      AsUiComponent_Container(field0: final box) =>
        box.hidden == true
            ? const SizedBox.shrink()
            : Container(
                padding: EdgeInsets.all(box.padding ?? 0),
                decoration: BoxDecoration(
                  color: _color(box.bgColor),
                  borderRadius: BorderRadius.circular(
                    box.borderRadius ?? (box.rounded == true ? 12 : 0),
                  ),
                  border: box.borderWidth == null
                      ? null
                      : Border.all(
                          color: _color(box.borderColor) ?? theme.dividerColor,
                          width: box.borderWidth!,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: switch (box.align) {
                    "center" => CrossAxisAlignment.center,
                    "right" || "end" => CrossAxisAlignment.end,
                    _ => CrossAxisAlignment.start,
                  },
                  children: (box.children ?? const []).map(_child).toList(),
                ),
              ),
      AsUiComponent_Text(field0: final value) => Text(
        value.text ?? "",
        style: TextStyle(
          color: _color(value.color),
          fontSize: value.size,
          fontWeight: value.bold == true ? FontWeight.bold : null,
          fontFamily: value.font,
        ),
      ),
      AsUiComponent_Mfm(field0: final value) => InkWell(
        onTap: value.onClickEv == null
            ? null
            : () =>
                  _invoke(() => value.onClickEv!.call(value: value.text ?? "")),
        child: MfmText(
          mfmText: value.text ?? "",
          style: TextStyle(
            color: _color(value.color),
            fontSize: value.size,
            fontWeight: value.bold == true ? FontWeight.bold : null,
            fontFamily: value.font,
          ),
        ),
      ),
      AsUiComponent_Button(field0: final value) => Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: value.disabled == true || value.onClick == null
              ? null
              : () => _invoke(value.onClick!.call),
          child: Text(value.text ?? "実行"),
        ),
      ),
      AsUiComponent_Buttons(field0: final value) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (value.buttons ?? const [])
            .map(
              (button) => FilledButton(
                onPressed: button.disabled == true || button.onClick == null
                    ? null
                    : () => _invoke(button.onClick!.call),
                child: Text(button.text ?? "実行"),
              ),
            )
            .toList(),
      ),
      AsUiComponent_ToggleSwitch(field0: final value) => HookBuilder(
        builder: (context) {
          final enabled = useState(value.defaultValue ?? false);
          useEffect(() {
            enabled.value = value.defaultValue ?? false;
            return null;
          }, [value.defaultValue]);
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(value.label ?? ""),
            subtitle: value.caption == null ? null : Text(value.caption!),
            value: enabled.value,
            onChanged: value.onChange == null
                ? null
                : (next) {
                    enabled.value = next;
                    _invoke(() => value.onChange!.call(value: next));
                  },
          );
        },
      ),
      AsUiComponent_TextInput(field0: final value) => TextFormField(
        key: ValueKey((componentId, value.defaultValue)),
        initialValue: value.defaultValue,
        decoration: InputDecoration(
          labelText: value.label,
          helperText: value.caption,
        ),
        onChanged: (text) => value.onInput == null
            ? null
            : _invoke(() => value.onInput!.call(value: text)),
      ),
      AsUiComponent_Textarea(field0: final value) => TextFormField(
        key: ValueKey((componentId, value.defaultValue)),
        initialValue: value.defaultValue,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: value.label,
          helperText: value.caption,
          alignLabelWithHint: true,
        ),
        onChanged: (text) => value.onInput == null
            ? null
            : _invoke(() => value.onInput!.call(value: text)),
      ),
      AsUiComponent_NumberInput(field0: final value) => TextFormField(
        key: ValueKey((componentId, value.defaultValue)),
        initialValue: value.defaultValue?.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: value.label,
          helperText: value.caption,
        ),
        onChanged: (text) {
          final number = double.tryParse(text);
          if (number != null && value.onInput != null) {
            _invoke(() => value.onInput!.call(value: number));
          }
        },
      ),
      AsUiComponent_Select(field0: final value) =>
        DropdownButtonFormField<String>(
          initialValue: value.defaultValue,
          decoration: InputDecoration(
            labelText: value.label,
            helperText: value.caption,
          ),
          items: (value.items ?? const [])
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.$1,
                  child: Text(item.$2),
                ),
              )
              .toList(),
          onChanged: value.onChange == null
              ? null
              : (selected) {
                  if (selected != null) {
                    _invoke(() => value.onChange!.call(value: selected));
                  }
                },
        ),
      AsUiComponent_Folder(field0: final value) => ExpansionTile(
        title: Text(value.title ?? "詳細"),
        initiallyExpanded: value.opened ?? false,
        children: (value.children ?? const []).map(_child).toList(),
      ),
      AsUiComponent_PostForm(field0: final value) => Card(
        child: ListTile(
          title: const Text("投稿フォーム"),
          subtitle: Text(value.form?.text ?? ""),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _openPostForm(context, value.form),
        ),
      ),
      AsUiComponent_PostFormButton(field0: final value) => FilledButton.icon(
        onPressed: () => _openPostForm(context, value.form),
        icon: const Icon(Icons.edit),
        label: Text(value.text ?? "投稿する"),
      ),
    };
  }
}
