# kimi-otty

[中文文档](./README-zh.md)

Otty terminal integration plugin — shows processing / idle / awaiting status badges in the Otty terminal pane for Kimi Code CLI sessions.

## Features

- **Real-time status badges**: Displays Kimi's current state (processing / idle / awaiting input) in the Otty terminal panel title bar.
- **Multi-instance support**: Matches by process PID, allowing multiple Kimi instances in the same working directory to show independent statuses.
- **Subagent-aware**: Won't incorrectly report idle when a background subagent is still running.
- **Interactive tool-aware**: Automatically switches to "awaiting input" when `AskUserQuestion` or `ExitPlanMode` is triggered.

## Installation

Clone this repository locally, then register the plugin in your Kimi Code CLI config:

```json
{
  "plugins": ["/path/to/kimi-plugins"]
}
```

Make sure [Otty](https://otty.app) is installed.

## How It Works

The plugin listens to the following Kimi Code CLI Hook events:

| Hook Event           | Reported State |
| -------------------- | -------------- |
| `SessionStart`       | idle           |
| `PreToolUse`         | processing     |
| `PostToolUse`        | processing     |
| `PermissionRequest`  | awaiting       |
| `UserPromptSubmit`   | processing     |
| `Stop`               | idle           |

The `otty-hook.sh` script sends state and session metadata to the Otty app via IPC. Otty then displays the corresponding status badge in the relevant terminal panel.

### Smart State Detection

The script includes the following special handling logic:

- **Subagent keep-alive**: When a Stop event arrives but a background subagent is still running, the state remains processing, preventing the badge from switching prematurely.
- **User input detection**: When `AskUserQuestion` or `ExitPlanMode` tools are detected, the state is corrected from processing to awaiting.

## File Structure

```
kimi-plugins/
├── kimi.plugin.json  # Plugin metadata and hook definitions
└── otty-hook.sh       # State reporting script
```

## Requirements

- [Kimi Code CLI](https://kimi.com)
- [Otty](https://otty.app) (macOS)

## License

MIT
