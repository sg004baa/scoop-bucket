# scoop-bucket

[![Tests](https://github.com/sg004baa/scoop-bucket/actions/workflows/ci.yml/badge.svg)](https://github.com/sg004baa/scoop-bucket/actions/workflows/ci.yml) [![Excavator](https://github.com/sg004baa/scoop-bucket/actions/workflows/excavator.yml/badge.svg)](https://github.com/sg004baa/scoop-bucket/actions/workflows/excavator.yml)

Personal bucket for [Scoop](https://scoop.sh), the Windows command-line installer.

## Installation

```pwsh
scoop bucket add sg004baa https://github.com/sg004baa/scoop-bucket
scoop install sg004baa/<manifestname>
```

## Manifests

| App | Description |
| --- | --- |
| [`anvi`](bucket/anvi.json) | Tray-resident tool that edits the focused input field of any Windows app in an embedded Neovim ([upstream](https://github.com/sg004baa/anvi)) |
| [`fyler`](bucket/fyler.json) | GUI file manager for Windows that edits the filesystem tree like a Neovim buffer ([upstream](https://github.com/sg004baa/fyler.windows)) |

Manifests are kept current by the [Excavator](.github/workflows/excavator.yml)
workflow, which runs `checkver`/`autoupdate` every 4 hours.
