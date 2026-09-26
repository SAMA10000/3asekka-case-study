# 3ASEKKA AI Transport Agent — 90 second demo script

## 0–15 sec — Problem

“Small Egyptian businesses still arrange many local goods-transport jobs manually. The hard part is not chatting — it is turning an Arabic request into an operational transport job.”

## 15–35 sec — Natural Arabic request

Paste:

> عايز أنقل 20 كرتونة من سموحة إلى المنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم

Press **شغّل الوكيل**.

Point out:

- pickup / destination extraction
- cargo and weight
- vehicle recommendation
- action trace

## 35–55 sec — Agent behavior

Explain that the LLM handles natural-language understanding while business tools remain deterministic.

Show these stages in the action trace:

1. extract transport request
2. recommend vehicle
3. calculate route
4. estimate fare
5. prepare transport request
6. driver matching / bidding

## 55–70 sec — Missing-information behavior

Try:

> عايز أنقل أثاث من رشدي إلى سموحة

The agent should ask for the missing approximate weight instead of inventing it.

## 70–90 sec — Production boundary

Explain that the public hackathon repository is deliberately isolated. 3ASEKKA production already has transport requests, vehicle classes, route-based pricing, bidding and trip lifecycle workflows, while production keys, user data and private backend code remain private.
