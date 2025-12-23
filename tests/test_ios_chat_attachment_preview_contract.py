from pathlib import Path


def test_ios_chat_view_has_attachment_preview_strip():
    """
    Regression guard: the chat composer should render inline attachment previews
    (thumbnail tiles with an X remove button) when attachments are staged.
    """
    swift = Path("byollm-assistantOS/ChatView.swift").read_text(encoding="utf-8")
    assert "attachmentPreviewStrip" in swift
    assert "xmark.circle.fill" in swift
    assert "userMessageAttachmentsView" in swift

