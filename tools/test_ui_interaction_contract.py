from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODO = (ROOT / "ios/WhaleAgent/UI/TodoView.swift").read_text(encoding="utf-8")
WORKSPACE = (ROOT / "ios/WhaleAgent/UI/WhaleWorkspaceView.swift").read_text(
    encoding="utf-8"
)
WORKSPACE_BRIEF = (
    ROOT / "ios/WhaleAgent/UI/WorkspaceBriefSection.swift"
).read_text(encoding="utf-8")
VOICE = (
    ROOT / "ios/WhaleAgent/UI/WhaleVoiceCaptureSheet.swift"
).read_text(encoding="utf-8")


def test_todo_has_no_hidden_filter_machine():
    forbidden = [
        "private var filterBar",
        "private var statsCard",
        "private func stepFilter",
        ".onChange(of: filter)",
        ".horizontalTabSwipe(",
        "@AppStorage(\"whale.todo.filter\")",
    ]
    for token in forbidden:
        assert token not in TODO, token


def test_complete_todo_list_is_not_presented_as_a_sheet():
    assert "showTodoManager" not in WORKSPACE
    assert "workspace-todo-list" not in WORKSPACE


def test_voice_is_centralized_in_one_component():
    assert not (ROOT / "ios/WhaleAgent/UI/VoiceView.swift").exists()
    assert "VoiceInputController" not in TODO
    assert "whale-voice-capture-sheet" in VOICE
    assert "whale-voice-cancel" in VOICE


def test_workspace_brief_exposes_keyboard_dismissal():
    required = [
        "@FocusState private var focusedField",
        ".focused($focusedField, equals: .morningFocus)",
        ".focused($focusedField, equals: .eveningNote)",
        "ToolbarItemGroup(placement: .keyboard)",
        "workspace-brief-keyboard-done",
        "focusedField = nil",
    ]
    for token in required:
        assert token in WORKSPACE_BRIEF, token
    assert ".scrollDismissesKeyboard(.interactively)" in WORKSPACE


if __name__ == "__main__":
    test_todo_has_no_hidden_filter_machine()
    test_complete_todo_list_is_not_presented_as_a_sheet()
    test_voice_is_centralized_in_one_component()
    test_workspace_brief_exposes_keyboard_dismissal()
    print("TODO_INTERACTION_CONTRACT_OK")
