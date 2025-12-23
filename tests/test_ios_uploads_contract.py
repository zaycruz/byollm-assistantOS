from pathlib import Path


def test_ios_network_manager_mentions_uploads_and_attachments():
    """
    Lightweight contract/regression guard for the iOS client.

    This repo includes Swift source but pytest is our CI gate here; ensure the
    uploads endpoint and attachments field don't accidentally disappear.
    """
    swift = Path("byollm-assistantOS/NetworkManager.swift").read_text(encoding="utf-8")
    assert "/v1/uploads" in swift
    assert "attachments" in swift

