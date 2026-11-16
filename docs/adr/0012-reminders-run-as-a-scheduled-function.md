---
status: accepted
---

# Reminders run as a scheduled function that holds no rules

The reminder email is sent by a serverless function triggered on the owner's chosen schedule. The function calls Funnel to process deadlines and to list the opportunities due for a follow-up, and sends the email only when the list is not empty. The rules for what is due, and for discarding an opportunity that got no response, live in Funnel.

## Considered options

- **A Kubernetes CronJob.** The simpler choice on this infrastructure. The function was chosen to exercise a serverless component on a task that suits one: short, scheduled and stateless.
- **Rules inside the function.** Rejected: the same rules drive the alerts on screen, and would exist twice.

## Consequences

- The function reaches Funnel over the public API with its own credentials.
- If the cluster is down at the scheduled time, the scheduler's retries cover it.
