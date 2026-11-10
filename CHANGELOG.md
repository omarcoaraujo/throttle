# Changelog

## 0.1.0 - 2026-11-10

- Share one request budget between several queues, so server limits hold across everything that sends
- A queue that sends one entry at a time, in order, with retries and growing waits between tries
- Entries with the same key merge into one, and a size limit drops the oldest when the queue is full
- Send and forget, or wait for the result
- Queues keep sending for up to 25 seconds when the server shuts down
- Ignore repeated player actions for a while, or wait until they stop and run once, with one timer per player
