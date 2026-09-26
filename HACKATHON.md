# 3ASEKKA AI Transport Agent — Agents at Work 2026

This is the public hackathon entry point for **3ASEKKA (عالسكة)**.

## What it is

**3ASEKKA AI Transport Agent** converts a natural Arabic goods-transport request into a structured local transport job.

Example:

> عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3 ووزنهم حوالي 250 كيلو

The agent can:

1. Extract pickup, destination, cargo, weight, requested time and distance when provided.
2. Ask only for information that is still missing.
3. Recommend a suitable vehicle class.
4. Produce a demo fare estimate.
5. Turn the conversation into a structured transport request.
6. Prepare the request for driver matching / bidding.
7. Present safe simulated offers in the public demo while production integrations remain private.

## Why this is different from a chatbot

The agent does not stop at answering a message. It converts unstructured Arabic into **transport operations** and makes operational decisions.

## Important public-demo boundary

This repository intentionally does **not** contain the production mobile application, private Supabase schema, credentials, user data, signing keys, production pricing configuration, or private business logic.

The hackathon demo is isolated under:

**[hackathon-agent/](hackathon-agent/README.md)**

The wider 3ASEKKA production case study remains documented in the repository root.
