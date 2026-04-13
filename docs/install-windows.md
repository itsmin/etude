# Install on Windows

Tested on: Ryzen 7 5800X / 32GB RAM / RTX 5080 16GB VRAM. Should work on any Windows 11 machine with a modern NVIDIA or AMD GPU.

Two paths: **native Windows Ollama** (simpler, recommended) or **WSL2 + Ollama** (more flexible, more setup). Default to native.

## Native Windows path

### Step 1 — Install Ollama

Download the Windows installer from [ollama.com/download](https://ollama.com/download) and run it. Ollama appears in the system tray.

Verify from PowerShell:
```powershell
ollama --version
```

Require **v0.20.2 or later**.

### Step 2 — Pull models

For a 16GB VRAM GPU (RTX 5080, 4080, 4070 Ti Super):

```powershell
ollama pull qwen3-coder:30b-a3b    # daily driver, ~17GB, partial offload
ollama pull qwen3:8b               # speed mode, fits entirely in VRAM
```

For 12GB VRAM (RTX 4070, 3080 Ti): skip the 30B, use `qwen3:8b` only.

For 24GB VRAM (RTX 4090, 3090): `qwen3-coder:30b-a3b` fits entirely in VRAM with room for context.

### Step 3 — Install opencode

Direct install isn't always available on Windows. Options:
- **Scoop**: `scoop install opencode`
- **npm** (requires Node.js): `npm install -g opencode-ai`
- **Manual**: download from the [opencode releases page](https://github.com/anomalyco/opencode/releases)

Or — the path I'd recommend if you plan to use this PC as both a client and a LAN server — run **opencode inside WSL2** while keeping Ollama native on Windows. opencode calls the host Ollama over `http://host.docker.internal:11434/v1` (or the host IP). See the WSL2 section below.

### Step 4 — The easy path: `ollama launch`

```powershell
cd your-project
ollama launch opencode --model qwen3-coder:30b-a3b
```

### Step 5 — Optional: multi-provider config

Copy the template:
```powershell
mkdir $env:APPDATA\opencode -Force
copy config\opencode\gpu-rtx5080-16gb.json $env:APPDATA\opencode\opencode.json
```

(If opencode uses a different config path on Windows, check `opencode --help` for the location.)

## LAN-serve mode — make this PC an inference server

If you want your MacBook Air (or any other machine on your home network) to route coding sessions to this PC's Ollama:

### On the Windows PC

Stop the Ollama system tray instance. Set the env var and restart:

```powershell
setx OLLAMA_HOST "0.0.0.0:11434"
```

Log out and back in (so the env var takes effect) and relaunch Ollama. It now listens on all interfaces instead of just localhost.

Find the PC's LAN IP:
```powershell
ipconfig
```

Look for IPv4 Address under your active adapter (e.g., `192.168.1.42`). Optionally set a stable hostname via your router's DHCP reservations.

### On a LAN client (e.g., the Air)

Edit `~/.config/opencode/opencode.json` and add a provider entry:

```json
"ollama-desktop": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Desktop (LAN)",
  "options": {
    "baseURL": "http://192.168.1.42:11434/v1"
  },
  "models": {
    "qwen3-coder:30b-a3b": {
      "name": "Qwen3-Coder 30B (desktop)",
      "tools": true,
      "limit": { "context": 32768, "output": 8192 }
    }
  }
}
```

Inside opencode, `/models` now lists desktop-served models. The Air doesn't hold weights — it's a thin client.

### Firewall

Windows Defender Firewall will ask on first connection — allow Ollama on **private** networks (not public). If it doesn't prompt, open TCP 11434 for the private profile manually.

## WSL2 path (advanced, not fully verified)

Summary: install WSL2 + Ubuntu, install Ollama inside WSL (it picks up CUDA from the host driver), install opencode inside WSL, run from there. More setup, but gives you a unixy dev environment end-to-end.

Note: host Windows Ollama and WSL Ollama don't share model caches — you'll pull models twice if you use both. Pick one.

If you try this path, update this section with what worked.

## Troubleshooting

**opencode can't reach the Ollama endpoint.** Check Windows Defender Firewall. Test from the client with `curl http://<server-ip>:11434/api/tags` — if it 404s or times out, it's network, not opencode.

**Partial offload slow on 30B-A3B.** Expected — Ollama offloads layers to system RAM when VRAM is full. MoE mitigates this but doesn't eliminate it. If it's unusable, drop to `qwen3:8b` for that session.

**RTX 5080 / Blackwell driver issues.** If `ollama ps` shows CPU-only on a Blackwell card, update the NVIDIA driver. Newer CUDA support needs recent drivers; Ollama picks up whatever the host driver exposes.

## What to do next

- `docs/usage.md` — day-to-day patterns
- `docs/hardware-tiers.md` — if you're on a different GPU profile
