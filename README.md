# Job Funnel

A system for running a job search: postings found by a daily automated search or added by hand, the progress on each one, the skills those postings ask for, and how the search is performing.

It has one real user and a public, read-only demonstration mode with fictitious data.

## Documentation

- [Architecture](./docs/architecture.md): services, events, infrastructure and technology
- [Domain model](./docs/domain-model.md): fields, rules and scenarios
- [Context map](./CONTEXT-MAP.md): the vocabulary of each service
- [Decisions](./docs/adr/): why the system is built this way
- [Roadmap](./docs/roadmap.md): the order in which it is built
- [Quality gate](./docs/quality-gate.md): the checks a pull request must pass, and their setup
- [Infrastructure](./infra/README.md): the Terraform for the permanent environment, and how to apply it

## Running locally

Requires the .NET 10 SDK. The service-boundary tests use Docker through Testcontainers once they touch a data store.

```sh
dotnet build
dotnet test
dotnet run --project src/funnel/JobFunnel.Funnel.Api
```

Funnel answers `/health/live` and `/health/ready`.

## Status

Phase 1 has started: the Funnel walking skeleton and its CI are in place. See the [roadmap](./docs/roadmap.md).
