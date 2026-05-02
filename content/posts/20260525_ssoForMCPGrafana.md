+++
title = "Adding SSO to MCP Grafana Server"
description = "Adding OAuth/SSO support to MCP Grafana server with Keycloak and a Docker Compose setup for end-to-end testing"
tags = [
    "golang",
    "grafana",
    "mcp",
]
date = "2026-05-25"
categories = [
    "golang",
    "grafana",
]
+++

The MCP Grafana server previously relied on static API keys or basic auth for authenticating requests to Grafana. This works fine for local development or single-user setups, but falls apart once you have multiple users who each need their own Grafana permissions. Passing around shared API keys is a security concern and means everyone operates with the same access level regardless of their actual role.

The solution is to integrate OAuth/SSO so that each user authenticates with their own identity, and the MCP server forwards their access token to Grafana. Grafana already supports JWT auth, so the tokens issued by an OIDC provider can be validated directly by Grafana to determine the user's role.

## Architecture

The flow works like this:

1. A client (e.g. Claude Code) obtains an OAuth access token from the identity provider (Keycloak in the dev setup)
2. The client sends requests to the MCP Grafana server with `Authorization: Bearer <token>`
3. The MCP server validates the token against the OIDC provider's JWKS endpoint
4. If valid, the token is forwarded to Grafana as the API key
5. Grafana validates the JWT independently and maps the user to the correct org role based on claims

This means the MCP server never sees or stores credentials. It acts as a transparent relay that validates tokens and passes them through.

## OAuth Middleware

The core of the implementation is an HTTP middleware that intercepts requests before they reach the MCP handler. It uses `github.com/coreos/go-oidc/v3` to perform OIDC discovery and JWT verification.

```go
func OAuthProtectMiddleware(cfg OAuthServerConfig) (func(http.Handler) http.Handler, error) {
    ctx := context.Background()
    provider, err := oidc.NewProvider(ctx, cfg.Issuer)
    if err != nil {
        return nil, fmt.Errorf("oauth: failed to discover OIDC provider at %s: %w", cfg.Issuer, err)
    }

    verifierConfig := &oidc.Config{
        SkipClientIDCheck: cfg.Audience == "",
    }
    if cfg.Audience != "" {
        verifierConfig.ClientID = cfg.Audience
    }
    verifier := provider.Verifier(verifierConfig)

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            rawToken := extractBearerToken(r)
            if rawToken == "" {
                w.Header().Set("WWW-Authenticate", `Bearer`)
                http.Error(w, "authorization required", http.StatusUnauthorized)
                return
            }

            idToken, err := verifier.Verify(r.Context(), rawToken)
            if err != nil {
                w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
                http.Error(w, "invalid or expired token", http.StatusUnauthorized)
                return
            }

            // Extract claims, check scopes, build user info, forward to next handler
            // ...
        })
    }, nil
}
```

The provider discovery happens once at startup. The middleware fetches the JWKS from the issuer's `/.well-known/openid-configuration` endpoint and caches the keys for subsequent validations.

## Token Forwarding to Grafana

Once the middleware validates a token, it stores the user info (including the raw token) in the request context. A bridge function then picks up this token and sets it as the Grafana API key so that downstream client creation uses it.

```go
func OAuthTokenForwardContextFunc(ctx context.Context, _ *http.Request) context.Context {
    userInfo, ok := OAuthUserInfoFromContext(ctx)
    if !ok || userInfo.Token == "" {
        return ctx
    }
    config := GrafanaConfigFromContext(ctx)
    config.APIKey = userInfo.Token
    return WithGrafanaConfig(ctx, config)
}
```

This is inserted into the composed context function chain between header extraction and client creation. It means if a user authenticates via OAuth, their token takes precedence over any env-based API key.

## RFC 9728 Discovery

MCP clients need a way to discover that the server requires OAuth and where to obtain tokens. The server exposes a `/.well-known/oauth-protected-resource` endpoint following RFC 9728 that returns metadata pointing to the authorization server.

```json
{
  "resource": "http://localhost:8000/mcp",
  "authorization_servers": ["http://keycloak:8080/realms/grafana"]
}
```

## Docker Compose Dev Environment

To test the full flow end-to-end locally, I created a Docker Compose setup under `dev/` with three services:

- **Keycloak** — the identity provider, pre-configured with a `grafana` realm containing test users with different roles (admin, editor, viewer)
- **Grafana** — configured with both Generic OAuth (for browser login) and JWT auth (for API token validation)
- **MCP Grafana** — the MCP server with OAuth enabled, pointing at Keycloak as the issuer

The Keycloak realm is imported from a JSON file that defines:

- A `grafana` client (confidential) for Grafana's browser-based OAuth login
- An `mcp-claude` client (public, PKCE) for CLI tools to obtain tokens via authorization code flow
- Three test users: alice (admin), bob (editor), carol (viewer)
- Role mappings that Grafana uses to determine org roles from the `roles` claim

### Grafana JWT Auth Configuration

The tricky part is getting Grafana to accept the tokens that Keycloak issues. Grafana's JWT auth needs the JWKS keys to verify signatures. Since Keycloak generates keys on startup, the Grafana container runs an init script that fetches the JWKS from Keycloak before starting Grafana.

```bash
#!/bin/sh
KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
REALM="${KEYCLOAK_REALM:-grafana}"

echo "Waiting for Keycloak OIDC endpoint..."
until wget -q -O /dev/null "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" 2>/dev/null; do
  sleep 2
done

echo "Fetching JWKS from Keycloak..."
wget -q -O /etc/grafana/jwks.json "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/certs"

exec /run.sh
```

The `GF_AUTH_JWT_JWK_SET_FILE` env var points Grafana at this downloaded JWKS file.

### Running It

```bash
cd dev
cp .env.example .env
docker compose up -d
```

After services are healthy, Keycloak is at `localhost:8080`, Grafana at `localhost:3000`, and the MCP server at `localhost:8000`. You can obtain a token from Keycloak using the password grant for testing:

```bash
curl -s -X POST http://localhost:8080/realms/grafana/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=mcp-claude" \
  -d "username=alice" \
  -d "password=alice123" \
  -d "scope=openid email profile" | jq -r '.access_token'
```

Then use that token against the MCP server:

```bash
TOKEN=$(curl -s ... | jq -r '.access_token')
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/mcp
```

## Server Flags

The OAuth support is opt-in via command line flags:

- `--oauth-enabled` — enable OAuth token validation
- `--oauth-issuer` — OIDC issuer URL for discovery
- `--oauth-audience` — expected audience claim (optional)
- `--oauth-scopes-required` — comma-separated required scopes (optional)
- `--oauth-username-claim` — which claim to extract as username (defaults to `email`)

Without `--oauth-enabled`, the server behaves exactly as before. The same configuration can also be provided via environment variables (`OAUTH_ENABLED`, `OAUTH_ISSUER`, etc.).

## What's Next

The current implementation covers the resource server side — validating tokens that clients have already obtained. The next step would be implementing the full MCP OAuth 2.1 client flow so that tools like Claude Code can automatically handle the authorization code + PKCE flow when they encounter a protected MCP server.
