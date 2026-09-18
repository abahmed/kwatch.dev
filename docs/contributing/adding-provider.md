---
title: Add a provider
description: How to add a safe and maintainable notification provider.
sidebar_position: 3
---

# Add a provider

Provider adapters live under `internal/alert/<provider>`. The directory name
is retained for provider ownership; the delivery manager and transport live in
`internal/delivery`.

## Provider boundary

A provider does four things:

1. Validate its configuration.
2. Render provider-specific payloads from the shared event or incident model.
3. Call `internal/delivery/transport` with the configured HTTP client.
4. Return provider errors without deciding retry or rate-limit policy.

The provider must not import `internal/controller`, `internal/handler`,
`internal/incident`, `internal/persistence`, or Kubernetes clients. It must not
create a process-wide HTTP client or log credentials, webhook URLs, or complete
payloads.

## Implementation checklist

1. Create `internal/alert/<provider>` with a package-level documentation
   comment.
2. Implement the existing delivery provider interface with a `New<Type>`
   constructor.
3. Use the configured outbound `http.Client` from the provider factory.
4. Use the shared transport sender for HTTP requests. Do not duplicate retry or
   status classification.
5. Add the provider factory to the static application catalog.
6. Add all configurable fields to the provider catalog source.
7. Add validation, secret-reference handling, and generated catalog tests.
8. Add success, network-error, retryable-status, permanent-status, malformed
   response, and payload tests.
9. Add the user-facing provider reference page on this site.
10. Add release notes when configuration or delivery behavior changes.

## Testing requirements

Use `httptest.Server` or an injected round tripper. Never call a live provider
from unit tests. Verify that:

- successful responses are accepted;
- 429 responses preserve retry information;
- retryable 5xx and transport errors are returned to delivery;
- permanent 4xx responses are not retried by the provider;
- malformed responses produce useful, secret-safe errors;
- credentials and complete payloads never appear in logs;
- payloads stay inside provider limits.

Run the focused provider tests, then `make verify` and the website validation
commands before opening a pull request.
