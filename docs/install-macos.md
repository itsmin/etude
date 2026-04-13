# Install on macOS

Tested on: MacBook Air M3, 24GB unified. Should work on any Apple Silicon Mac with 16GB or more.

## Prerequisites

```bash
xcode-select --install
```

A dialog appears — click Install. If it says "already installed," you're good.

Homebrew is optional but recommended:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Step 1 — Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Or `brew install ollama`. Either works. Launch it from Applications — the Ollama menu bar icon should appear.

Verify:
```bash
ollama --version
```

Require **v0.20.2 or later**. Earlier versions have tool-calling bugs with current-gen models.

## Step 2 — Pull models

For a 24GB Air (the author's reference machine), pull both:

```bash
ollama pull qwen3:8b         # daily driver, ~5.2GB
ollama pull qwen3-coder:30b  # heavy mode, ~19GB
```

For a 16GB Mac, skip the 30B — pull `qwen3:8b` only.

For a 32GB+ Mac (MLX backend activates), you can make `qwen3-coder:30b` your daily driver instead.

## Step 3 — Keep models loaded (optional)

Ollama unloads models after 5 minutes of inactivity. For coding sessions, that causes cold-start delays. To keep them loaded:

```bash
echo 'export OLLAMA_KEEP_ALIVE="-1"' >> ~/.zshrc
source ~/.zshrc
```

**Warning for 24GB and under.** Keeping `qwen3-coder:30b` pinned holds ~19GB. That's most of your machine. If you're doing anything else — browser, Xcode, screen share — let it unload. Only pin the 8B.

To pin only the 8B, skip the env var and keep `qwen3:8b` warm via `ollama run qwen3:8b` between sessions.

## Step 4 — Install opencode

```bash
curl -fsSL https://opencode.ai/install | bash
```

If `opencode` isn't on your PATH after install:
```bash
echo 'export PATH="$HOME/.opencode/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:
```bash
opencode --version
```

## Step 5 — The easy path: `ollama launch`

Ollama 0.20+ ships `ollama launch`, which starts a coding tool with a model pre-wired. No config file required.

```bash
cd your-project
ollama launch opencode --model qwen3:8b
```

opencode starts with Qwen3 8B selected. Tab switches between Build mode (full tool access) and Plan mode (read-only analysis).

For heavy mode:
```bash
ollama launch opencode --model qwen3-coder:30b
```

**This is the daily happy path.** Steps 6 and 7 are only if you want the multi-provider config for fast switching, LAN routing, or Ollama Cloud.

## Step 6 — Optional: multi-provider config

If you want `/models` inside opencode to flip between local, LAN, and cloud without restarting:

```bash
mkdir -p ~/.config/opencode
cp config/opencode/mac-air-24gb.json ~/.config/opencode/opencode.json
```

Edit it to match your setup. The template uses:
- `ollama-local` → `http://localhost:11434/v1` (this Mac)
- `ollama-desktop` → `http://desktop.local:11434/v1` (your LAN peer, optional)

Both providers can list local models *and* `:cloud`-suffixed hosted models.

## Step 7 — Optional: Ollama Cloud

Ollama Cloud proxies through your local Ollama instance. No separate provider block, no extra `baseURL`. You pull a `:cloud`-suffixed model:

```bash
ollama pull glm-5:cloud
```

Reference it in opencode like any other model. Authentication is handled by the Ollama client — see [ollama.com/cloud](https://ollama.com/cloud) for signup and keys.

## Troubleshooting

**"I cannot execute commands" in opencode.** Your context window is probably 4K (Ollama's default). System prompts alone chew through that. When using `ollama launch`, this shouldn't happen. If you're running from your own config, ensure the model has `"tools": true` and `"limit.context": 32768` or higher.

**Slow responses.** Close memory-hungry apps. Check GPU use with `ollama ps` — you should see a GPU percentage. If it's 100% CPU, update Ollama and restart.

**Thermal throttling during heavy mode on the Air.** Expected. The 30B-A3B pushes the chip and there's no fan. Short focused sessions work fine. For longer ones, route to a LAN peer instead — see `docs/install-windows.md` for the serving side.

**Model not found.** Run `ollama list` to confirm exact names. Case-sensitive.

## What to do next

- `docs/usage.md` — day-to-day patterns, mode switching
- `docs/hardware-tiers.md` — if you're on a different Mac profile
- `docs/models.md` — swap a model when a better one shows up
