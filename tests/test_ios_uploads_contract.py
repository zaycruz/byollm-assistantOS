from pathlib import Path


def test_ios_network_manager_mentions_multipart_chat_attachments():
    """
    Lightweight contract/regression guard for the iOS client.

    This repo includes Swift source but pytest is our CI gate here; ensure the
    multipart chat attachments support doesn't accidentally disappear.
    """
    swift = Path("byollm-assistantOS/NetworkManager.swift").read_text(encoding="utf-8")
    assert "multipart/form-data" in swift
    assert "name=\\\"payload\\\"" in swift
    assert "name=\\\"files\\\"" in swift

