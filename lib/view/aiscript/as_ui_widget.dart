import "package:flutter/material.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/view/note_create_page/note_create_page.dart";
import "package:dmsky_client/rust/api/aiscript/ui.dart";

class AsUiWidget extends StatelessWidget {
  const AsUiWidget({
    required this.account,
    required this.components,
    this.componentId = "___root___",
    super.key,
  });

  final Account account;
  final Map<String, AsUiComponent> components;
  final String componentId;

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
    account: account,
    components: components,
    componentId: id,
  );

  void _openPostForm(BuildContext context, PostFormPropsForAsUi? form) {
    if (form == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => NoteCreatePage(
          initialAccount: account,
          initialText: form.text,
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
            : () => value.onClickEv!.call(value: value.text ?? ""),
        child: Text(
          value.text ?? "",
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
          onPressed: value.disabled == true ? null : value.onClick?.call,
          child: Text(value.text ?? "実行"),
        ),
      ),
      AsUiComponent_Buttons(field0: final value) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (value.buttons ?? const [])
            .map(
              (button) => FilledButton(
                onPressed: button.disabled == true
                    ? null
                    : button.onClick?.call,
                child: Text(button.text ?? "実行"),
              ),
            )
            .toList(),
      ),
      AsUiComponent_ToggleSwitch(field0: final value) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(value.label ?? ""),
        subtitle: value.caption == null ? null : Text(value.caption!),
        value: value.defaultValue ?? false,
        onChanged: value.onChange?.call,
      ),
      AsUiComponent_TextInput(field0: final value) => TextFormField(
        initialValue: value.defaultValue,
        decoration: InputDecoration(
          labelText: value.label,
          helperText: value.caption,
        ),
        onChanged: (text) => value.onInput?.call(value: text),
      ),
      AsUiComponent_Textarea(field0: final value) => TextFormField(
        initialValue: value.defaultValue,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: value.label,
          helperText: value.caption,
          alignLabelWithHint: true,
        ),
        onChanged: (text) => value.onInput?.call(value: text),
      ),
      AsUiComponent_NumberInput(field0: final value) => TextFormField(
        initialValue: value.defaultValue?.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: value.label,
          helperText: value.caption,
        ),
        onChanged: (text) {
          final number = double.tryParse(text);
          if (number != null) value.onInput?.call(value: number);
        },
      ),
      AsUiComponent_Select(field0: final value) => DropdownButtonFormField<String>(
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
                if (selected != null) value.onChange!.call(value: selected);
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
