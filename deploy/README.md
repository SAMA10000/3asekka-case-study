# Deploy the AI agent under 3ASEKKA

Target URL:

```
https://3asekka.com/ai/
```

Architecture:

```
3asekka.com/ai/
      ↓
Nginx reverse proxy
      ↓
127.0.0.1:3300
      ↓
3ASEKKA AI Transport Agent (Node.js)
```

The deploy script:
- downloads the current hackathon-agent from the public case-study repository;
- stores the Gemini key only in `/etc/3asekka-ai-agent.env`;
- creates a systemd service;
- adds an isolated `/ai/` Nginx reverse-proxy location;
- backs up the current Nginx vhost first;
- validates Nginx before reload;
- does not replace the main 3asekka.com application.

Deployment script:

`deploy/3asekka-ai-agent-vps.sh`

Production application code and secrets remain separate.
