# 3ASEKKA AI Transport Agent — Agents at Work 2026

Public hackathon entry point for **3ASEKKA (عالسكة)**.

## One-line pitch

**An Arabic AI operations agent that converts a simple goods-transport request into an actionable local transport job, then orchestrates vehicle selection, routing, fare estimation and driver-matching stages.**

## Example

> عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو

The agent can:

1. Understand a natural Arabic transport request.
2. Extract pickup, destination, cargo, weight and requested time.
3. Ask only for information that is actually missing.
4. Recommend a suitable vehicle class.
5. Decide whether route calculation is required next.
6. Produce a demo fare when route distance is available.
7. Prepare a structured transport request for driver matching/bidding.

## AI design

Natural-language extraction can run through a configured Gemini, OpenAI or OpenAI-compatible model. The LLM is deliberately separated from business tools: vehicle limits, pricing and workflow decisions remain deterministic and inspectable.

If no AI key is configured, the public demo safely falls back to an Arabic parser rather than failing.

## Why this is not a customer-support chatbot

The output is not merely a reply. The agent creates a transport operation and emits an action trace showing which operational tool/stage should run next.

## Public-demo boundary

Production 3ASEKKA source code, Supabase secrets, user data, private schema, signing keys and production business logic remain private.

The isolated hackathon implementation is here:

**[hackathon-agent/](hackathon-agent/README.md)**

The wider production case study remains documented in the repository root.
