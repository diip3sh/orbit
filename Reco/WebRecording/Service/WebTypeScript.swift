//
//  WebTypeScript.swift
//  Reco
//

/// Types one character into a field of a take's page, as a key press would: the page sees
/// `keydown`, the text inserted with its `beforeinput` and `input` events, and `keyup`.
///
/// Called with `selector`, the field, and `text`, one character. A new line in a single-line
/// field is Enter: it submits the field's form.
nonisolated enum WebTypeScript {

    static let source = #"""
        const field = document.querySelector(selector);
        if (!field) return false;
        if (document.activeElement !== field) field.focus();
        const isEnter = text === "\n";
        const init = { key: isEnter ? "Enter" : text, bubbles: true, cancelable: true };
        if (isEnter) Object.assign(init, { code: "Enter", keyCode: 13, which: 13 });
        if (field.dispatchEvent(new KeyboardEvent("keydown", init))) {
            if (isEnter && field instanceof HTMLInputElement) {
                field.form?.requestSubmit();
            } else if (!document.execCommand("insertText", false, text) && "value" in field) {
                // Not editable through the editor, e.g. a number field: its value, as frameworks watch it
                const prototype = field instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
                Object.getOwnPropertyDescriptor(prototype, "value").set.call(field, field.value + text);
                field.dispatchEvent(new InputEvent("input", { bubbles: true, data: text, inputType: "insertText" }));
            }
        }
        field.dispatchEvent(new KeyboardEvent("keyup", init));
        return true;
        """#
}
