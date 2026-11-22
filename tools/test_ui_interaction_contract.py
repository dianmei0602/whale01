from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODO = (ROOT / "ios/WhaleAgent/UI/TodoView.swift").read_text(encoding="utf-8")


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


if __name__ == "__main__":
    test_todo_has_no_hidden_filter_machine()
    print("TODO_INTERACTION_CONTRACT_OK")
