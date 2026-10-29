# Smart CPU AI — Windows local MoE runner (prototype v0.1.2)

A batch-file entry point for installing a CPU-only `llama.cpp` runtime, detecting Windows hardware, selecting a curated GGUF Mixture-of-Experts model, downloading and verifying it, and launching the local web chat UI. Version 0.1.2 adds a GitHub release-page fallback for environments where the GitHub REST API returns `403 Forbidden`.

## Important limits

- This is a **first runnable prototype**, not a promise that every Windows PC or model will work. Please test it on the target machine before public distribution.
- Large models can take a very long time to load and can make Windows unresponsive if the page file is used excessively. Memory mapping / SSD streaming does not make disk equivalent to RAM.
- Balanced mode only selects variants that fit a conservative working-memory estimate. Experimental mode may intentionally select a model that exceeds the RAM budget and requires a typed confirmation.
- The model catalog contains only selected MoE models and known GGUF file variants. If a repository changes or a model file disappears, that entry is skipped. The tool does not execute arbitrary Hugging Face code.
- CPU-only is forced with `-ngl 0`; the local server binds to `127.0.0.1`, not the whole network.
- Windows 10 standard support ended on October 14, 2025. Use an applicable extended security update program where available.
- Model licenses, the upstream model card and the quantization publisher should be reviewed before redistribution or commercial use. Models are downloaded separately from their owners/quantizers and are not bundled here.

## How to run

1. Extract this folder to a normal writable directory.
2. Double-click `SmartCPUAI.bat`.
3. Choose **1. Install / select the largest suitable MoE model and launch it**.
4. On the first run, the launcher checks hardware, downloads the compatible Windows CPU release of `llama.cpp`, queries Hugging Face for the pinned model revision, and displays candidates before downloading the selected model.
5. The chat UI normally opens at `http://127.0.0.1:8080` (or the next available local port).

No administrator access is required for normal operation. Page-file repair is optional, requires the user to type `YES`, and invokes the Windows UAC prompt only when needed.

## Settings

- **RAM reserve:** 10–40%, default 20%.
- **Mode:** Balanced (default) or Experimental.
- **Context:** 2,048 / 4,096 / 8,192 / 16,384 tokens. Larger context may use more memory.
- **Threads:** 0 means auto; otherwise manually select a number.
- **Model storage:** can be moved to a different drive.
- **SHA-256:** enabled by default when Hugging Face / GitHub exposes a usable digest. Hashing very large model files takes additional disk I/O and time.

Settings, logs, runtime downloads and the hardware report are stored under `%LOCALAPPDATA%\SmartCPUAI`. Model files are stored in the configured model directory, by default `%LOCALAPPDATA%\SmartCPUAI\models`.

## GitHub release API fallback (v0.1.2)

The preferred runtime discovery path uses GitHub's REST API for asset names, sizes, and published SHA-256 digests. If that API request fails (including `403 Forbidden`, which can occur when an unauthenticated API rate limit is reached), the installer now tries the public `llama.cpp` releases webpage and the selected release's asset page. This failure is not caused by an AMD CPU; the Windows 10 end-of-support notice is an independent warning.

The webpage fallback attempts to obtain the asset's content length with an HTTP HEAD request. If GitHub does not expose the length or digest on that path, the installer warns that exact size/SHA-256 verification is unavailable, then validates the ZIP by extracting it and requires `llama-server.exe --version` to succeed before reporting installation success. The primary REST API path still uses published file size and digest where available.

## CPU-only behavior

The runtime is fetched from the official `ggml-org/llama.cpp` GitHub release assets and the Windows architecture is detected before selecting the x64 or ARM64 CPU archive. Model launch arguments include `-ngl 0`, which disables GPU layer offload even when a GPU is present.

The script does not install GPU drivers, CUDA or ROCm, does not make permanent execution-policy changes, does not edit PATH globally, and does not disable Windows security controls.

## Catalog design

The catalog currently checks these repositories and exact files against live Hugging Face metadata:

- `unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF` — 80B total / 3B active, multiple quantizations.
- `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF` — 30B total / 3B active, multiple quantizations; coding-oriented.
- `ggml-org/gpt-oss-20b-GGUF` — 20B-class MoE model, MXFP4 file (`gpt-oss-20b-mxfp4.gguf`).

Downloads are pinned to the repository commit SHA returned by the Hub API. Only the GGUF weight file is downloaded. The script verifies exact byte size and, when available and enabled, SHA-256. Metadata and file manifests are checked before model selection.


## Hotfix note

If you received the first v0.1 package and saw `Argument types do not match` immediately after the Hugging Face catalog check, replace it with this updated package. The catalog now converts its generic list with `.ToArray()` to avoid a PowerShell array-conversion bug.

## Diagnostics

Use menu option **3** for a hardware report and **6** to open the log folder. Relevant files include:

- `logs\hardware-report.json`
- `logs\smartcpuai-YYYYMMDD.log`
- `logs\server-out-PORT.log`
- `logs\server-err-PORT.log`

If a download is interrupted, a `.partial` file may remain so curl can resume it on the next attempt. If the runtime fails to start, inspect `server-err-PORT.log` and the runtime version-check logs.

## First-version validation status

The scripts are authored for Windows PowerShell 5.1 and Windows 10/11, but they have **not been executed on a real Windows x64 or ARM64 machine in this build environment**. Before treating this as release-ready, test at least: a modern Intel x64 PC, AMD x64 PC, Windows ARM64, 8/16/32/64+ GB RAM, interrupted downloads, low disk space, bad model metadata, port conflicts, and runtime load failure. The next production pass should also perform real hardware feature checks for older CPU instruction sets and test the exact runtime asset naming across release changes.
