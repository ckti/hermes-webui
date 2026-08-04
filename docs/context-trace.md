# Context Trace Workspace

Use `scripts/context-trace.sh` to boot a tiny local repro of the browser chat
path and watch both sides of the request:

- WebUI outbound payload logging from `api/streaming.py` and
  `api/gateway_chat.py`
- agent prompt assembly from `agent/system_prompt.py`,
  `agent/prompt_builder.py`, and `agent/context_breakdown.py`

The launcher uses an isolated temp `HERMES_HOME` and WebUI state directory by
default so you can inspect prompt injection without touching your live state.

The same data path is also exposed in the agent UI as `session.context_breakdown`
and in the CLI as `/context` and `/context all`.
