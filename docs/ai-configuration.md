---
sidebar_position: 21
title: AI Troubleshooting
description: AI-powered log analysis for crash troubleshooting
keywords: [kwatch, kubernetes, ai, llm, troubleshooting, logs]
pagination_next: null
pagination_prev: null
---

# 🤖 AI-powered troubleshooting

kwatch ships with a **built-in AI sidecar** that runs inside your cluster —
zero data leaves your environment.

When a crash happens, the AI reads the logs and tells you the **most likely
cause** and **what to do next**. Like having a senior SRE on-call with you.

> **📌 Architecture note:** The AI sidecar is available for **linux/amd64** and **linux/arm64** only. It does not support `arm/v6` or `arm/v7` (the main kwatch image supports all four).

## How it works

The AI runs as a separate container (`kwatch-llm`) in the same pod as kwatch,
using a local llama.cpp server with a MiniCPM5-1B Q4_K_M GGUF model. kwatch
sends container logs and events to `http://localhost:8080` (loopback only —
completely isolated from the cluster network).

## Configuration

```yaml
llm:
  enabled: true     # ✅ on by default
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `llm.enabled` | `bool` | `true` | Enable AI enrichment. When true, kwatch sends crash context to the sidecar and includes analysis in alerts. |

**That's it.** The model (`kwatch-triage`), endpoint (`localhost:8080`),
redaction patterns, prompt, timeouts (30s), and output limits (600 chars) are
all baked into the sidecar image and code — there are no other user-facing
knobs.

## Privacy

The AI runs inside your cluster — `localhost:8080`. **Zero data leaves your
infrastructure.** No cloud API keys needed. No third-party model calls.
