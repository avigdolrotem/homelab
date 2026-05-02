# LibreChat

**Role:** Optional. AI chat interface supporting multiple providers + local models.

LibreChat is not protected by Authentik — it has its own user accounts. Access at `https://ai.yourdomain.com`.

---

## Components

| Container | Purpose |
|-----------|---------|
| `librechat` | Web application |
| `librechat-mongodb` | MongoDB database |
| `ollama` | Local LLM runner (optional — remove if not needed) |

---

## Supported AI providers

LibreChat can connect to multiple providers simultaneously:
- **OpenAI** (GPT-4, etc.) — requires API key
- **Anthropic** (Claude) — requires API key
- **Ollama** — local models, no API key needed
- **Any OpenAI-compatible API** — custom endpoint support

API keys are stored encrypted in MongoDB using the `CREDS_KEY`/`CREDS_IV` values from `librechat.env`. Each user can add their own keys in the UI.

---

## Ollama (local models)

Ollama runs models locally on your hardware. No internet required after model download.

To pull a model after starting the stack:
```bash
docker exec -it ollama ollama pull llama3.1:8b
```

Available models: [ollama.com/library](https://ollama.com/library)

Performance note: LLMs require significant RAM. A 7–8B parameter model needs ~8 GB RAM. Running larger models on a server without a GPU will be slow. For GPU acceleration, add a `deploy.resources.reservations.devices` block to the Ollama service.

If you don't need local models, remove the `ollama` service from the compose file and remove it from `librechat.yaml`.

---

## Registration settings

In `librechat.env`:
```env
ALLOW_REGISTRATION=false    # Disable open registration after initial setup
ALLOW_EMAIL_LOGIN=true
ALLOW_SOCIAL_LOGIN=false
```

Set `ALLOW_REGISTRATION=true` only when creating your initial account, then set it back to `false`.

---

## `librechat.yaml`

This file configures Ollama endpoints, file upload limits, and agent capabilities. It's mounted read-only into the container. Edit and restart to apply changes:
```bash
docker compose -f services/librechat/compose.yml restart librechat
```
