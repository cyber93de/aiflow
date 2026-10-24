---
name: messaging-events
description: Asynchronous integration — when a message queue or event stream is the right answer instead of a synchronous call, choosing between Kafka, RabbitMQ, NATS, SQS/SNS and a database-backed queue, and the patterns that make it survive production — delivery semantics, idempotent consumers, the transactional outbox, ordering and partitioning, schema evolution, dead-letter handling, sagas. Invoke when a change introduces or touches a queue, topic, broker, event, or background job, when synchronous coupling is causing timeouts, or on explicit request — "queue", "message", "event-driven", "Kafka", "RabbitMQ", "NATS", "SQS", "outbox", "saga", "pub/sub".
---

# Messaging & event-driven integration

Implements §3a's "modern brokers/cloud-native eventing over 1980s-style MQ patterns" and the §2a
rule that what crosses a process boundary is a DTO with an explicit contract.

## First: do you need it?

Async messaging buys decoupling and load absorption, and charges you eventual consistency,
duplicate delivery, ordering questions, and a debugging story that spans processes. Use it when:

- the caller genuinely does not need the result now (email, indexing, reporting, thumbnails);
- one event has several independent consumers, and you refuse to hard-code them into the producer;
- load is spiky and the consumer must absorb it at its own pace;
- the systems must be independently deployable and survive each other's downtime.

Do **not** reach for it to hide a slow synchronous call you could just make fast, or to fake a
transaction across services. A synchronous call with a timeout and a circuit breaker is simpler and
often correct — and simplicity is a §2a rule.

## Choosing a broker

| | Fits | Watch out |
|---|---|---|
| **Kafka / Redpanda** | high-volume event streams, replay, log-as-source-of-truth, many consumer groups | operational weight; partitions are your ordering *and* scaling unit — pick the key carefully |
| **RabbitMQ** | classic work queues, routing/fan-out, per-message ack, priorities, delays | not a log — once acked, it's gone; no replay |
| **NATS / JetStream** | lightweight pub-sub, request-reply, edge and K8s-native | smaller ecosystem than Kafka |
| **SQS/SNS, Pub/Sub, Service Bus** | managed, no ops, cloud-native | vendor coupling; regional/quota limits shape the design |
| **DB-backed queue** (outbox table, `SKIP LOCKED`) | modest volume, one service, you already have the DB | don't grow it into a broker — that road is well travelled and ends badly |

Record the decision (§3a) — including "we stayed synchronous".

## Non-negotiable patterns

- **At-least-once is the default.** Exactly-once end-to-end does not exist across a network. So
  **every consumer is idempotent**: dedupe on a message id / business key, or make the operation
  naturally idempotent (`SET status='paid'` beats `balance = balance - 10`).
- **Transactional outbox.** Never "write to the DB, then publish" — the process dies between the
  two and you have silently diverged. Write the event to an outbox table *in the same transaction*
  as the state change, and let a relay (or CDC/Debezium) publish it.
- **Ordering is per partition/queue, not global.** If order matters, derive the partition key from
  the entity whose order matters (customer id, aggregate id) — and accept that this caps your
  parallelism for that entity. If it doesn't matter, say so explicitly.
- **Poison messages need a home.** Bounded retries with exponential backoff, then a **dead-letter
  queue** — plus an alert and a documented way to inspect and replay it. A DLQ nobody watches is a
  silent data-loss channel.
- **Schemas are contracts** (like §3b for REST). Use a schema registry (Avro/Protobuf/JSON Schema)
  with a compatibility mode set to BACKWARD or FULL, enforced in CI. Additive, optional fields
  only; never reuse or repurpose a field. Version the event type in its name when you must break.
- **Events carry meaning, not rows.** `OrderPlaced { orderId, customerId, total, placedAt }`, not a
  dump of the `orders` table. Choose deliberately between a thin event (id only, consumer fetches)
  and a fat one (self-contained) — thin means coupling to your API, fat means stale data; both are
  valid, but pick on purpose.
- **Correlation/trace id on every message**, propagated from the triggering request, so one request
  can be followed across five services (see the **stack-backend** skill's observability section).
- **Sagas over distributed transactions.** A multi-service business operation is a sequence of
  local transactions with explicit compensating actions. Model the failure path first — the
  compensation *is* the design.
- **Consumer lag is a first-class metric**, with an alert. So is DLQ depth, redelivery rate, and
  age of the oldest unprocessed message.

## Layering (§2a)

The broker client belongs in an **outbound/inbound adapter**, behind a port declared in the domain
(`EventPublisher`, or a use case invoked by the consumer). The domain must not import a Kafka
producer or an AMQP channel, and an inbound message maps to a DTO → domain object like any other
edge. A consumer that contains business logic *and* deserialisation *and* a DB call is three
responsibilities in one file.

## Testing (§3a)

- **Unit** — the handler with the port faked; assert the effect, not the framework.
- **Integration** — a real broker in Testcontainers (Kafka/RabbitMQ/NATS). Embedded/in-memory
  doubles hide exactly the redelivery and rebalance behaviour you need to test.
- **Explicitly test:** duplicate delivery (send the same message twice — state must be identical),
  out-of-order arrival, a handler that throws (does it retry, then DLQ?), consumer restart
  mid-batch, and schema evolution (old consumer + new message, new consumer + old message).
- **BDD E2E** (§3a mandatory): Given an order exists, When `OrderPlaced` is published, Then the
  invoice service has created exactly one invoice — including on redelivery.

## Typical findings to raise

Publish outside the transaction that changed the state · non-idempotent consumer · unbounded
retries with no DLQ · ordering assumed across partitions · event carrying a raw DB row · no schema
compatibility check · no correlation id · DLQ with no alert or replay path · a distributed
transaction where a saga belongs · broker client imported in the domain layer.
