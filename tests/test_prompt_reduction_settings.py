"""Coverage for the WebUI controls that configure provider prompt reduction."""

from pathlib import Path

from api.config import agent_context_switches


def test_context_switches_cover_all_eight_combinations():
    """Each UI combination maps to the shared Agent's three wire switches."""
    for value in range(8):
        local_context = bool(value & 0b100)
        send_system_prompt = bool(value & 0b010)
        send_tool_definitions = bool(value & 0b001)
        actual = agent_context_switches({
            "context": {
                "send_full_history": not local_context,
                "send_system_prompt": send_system_prompt,
                "send_tool_definitions": send_tool_definitions,
            }
        })
        assert actual == {
            "send_full_history": not local_context,
            "send_system_prompt": send_system_prompt,
            "send_tool_definitions": send_tool_definitions,
            "local_context": local_context,
        }


def test_context_controls_are_persisted_through_preferences_flow():
    panels = (Path(__file__).parents[1] / "static" / "panels.js").read_text(encoding="utf-8")
    index = (Path(__file__).parents[1] / "static" / "index.html").read_text(encoding="utf-8")

    for dom_id, payload_key in (
        ("settingsLocalContext", "local_context"),
        ("settingsSendSystemPrompt", "send_system_prompt"),
        ("settingsSendToolDefinitions", "send_tool_definitions"),
    ):
        assert dom_id in index
        assert f"payload.{payload_key}=" in panels
        assert f"settings.{payload_key}" in panels
        assert "_schedulePreferencesAutosave" in panels
