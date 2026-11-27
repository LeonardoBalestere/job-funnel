# Quality gate

A pull request into `main` merges only when three checks pass:

| Check | Workflow | What it does |
|---|---|---|
| `Build, style and tests` | `ci.yml` | Restore, build with warnings as errors, `dotnet format --verify-no-changes`, all tests |
| `SonarQube Cloud` | `ci.yml` | Builds and tests again with Coverlet coverage, sends both to SonarQube Cloud and fails when its quality gate fails |
| `Analyze (csharp)` | `codeql.yml` | CodeQL data-flow analysis with the `security-extended` queries; also runs weekly |

`SonarQube Cloud` is a job of its own because the SonarQube scanner turns off warnings-as-errors for the build it wraps.

Dependabot (`.github/dependabot.yml`) opens weekly pull requests for NuGet packages, the local tools in `.config/dotnet-tools.json`, and GitHub Actions. Secret scanning and push protection guard the repository itself.

## Coverage locally

```sh
dotnet test --results-directory TestResults/coverage --coverlet --coverlet-output-format opencover --coverlet-include "[JobFunnel.*]*"
```

One OpenCover report per test project lands in `TestResults/coverage`, which git ignores.

## Owner setup

Done once, in this order. Steps 1 to 3 need the owner's SonarQube Cloud and GitHub accounts.

1. **SonarQube Cloud organization and project.** Sign in at <https://sonarcloud.io> with GitHub. Import the `LeonardoBalestere` account as an organization (free plan, since the repository is public), and analyse the `job-funnel` repository.
   - The workflow expects the organization key `leonardobalestere` and the project key `LeonardoBalestere_job-funnel`. If SonarQube Cloud gives different keys, change `SONAR_ORGANIZATION` and `SONAR_PROJECT_KEY` in `.github/workflows/ci.yml`.
   - Under the project's **Administration → Analysis Method**, turn **Automatic Analysis** off. The CI analysis replaces it, and the two cannot run together.
   - Keep the default quality gate (`Sonar way`). For **New Code**, choose "Previous version" or a number of days.
2. **Token.** Under **My Account → Security**, generate a token. In the GitHub repository, store it as `SONAR_TOKEN` in two places:
   - **Settings → Secrets and variables → Actions**
   - **Settings → Secrets and variables → Dependabot**, because pull requests opened by Dependabot cannot read Actions secrets

   Without the token the `SonarQube Cloud` job fails on purpose instead of skipping, so a missing token never lets a pull request through. Pull requests from forks never receive the token, so they cannot pass the gate; changes come from branches of this repository.
3. **CodeQL.** Under **Settings → Code security → Code scanning**, leave CodeQL's *default setup* off; `codeql.yml` is the advanced setup and the two conflict.
4. **Secret scanning and push protection.** Under **Settings → Code security**, enable **Secret Protection** and **Push protection**.
5. **Branch rule for `main`.** Under **Settings → Rules → Rulesets**, add a branch ruleset that targets the default branch and `main`, with:
   - Require a pull request before merging
   - Require status checks to pass, with these checks: `Build, style and tests`, `SonarQube Cloud`, `Analyze (csharp)`
   - Block force pushes

   Once the rule is on, changes reach `main` only through pull requests.

Steps 4 and 5 can also be done from the command line with `gh api` by someone with admin rights on the repository.
