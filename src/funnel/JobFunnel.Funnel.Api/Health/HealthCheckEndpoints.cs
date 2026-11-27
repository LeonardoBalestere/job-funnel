using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace JobFunnel.Funnel.Api.Health;

/// <summary>
/// Liveness and readiness endpoints for the Kubernetes probes.
/// </summary>
/// <remarks>
/// Liveness only says the process answers. Readiness runs every check tagged
/// <see cref="ReadinessTag"/>, so dependencies such as SQL Server join it by tagging their check.
/// </remarks>
internal static class HealthCheckEndpoints
{
    public const string LivenessPath = "/health/live";
    public const string ReadinessPath = "/health/ready";
    public const string ReadinessTag = "ready";

    public static IServiceCollection AddFunnelHealthChecks(this IServiceCollection services)
    {
        services.AddHealthChecks();
        return services;
    }

    public static IEndpointRouteBuilder MapFunnelHealthChecks(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapHealthChecks(LivenessPath, new HealthCheckOptions { Predicate = _ => false });
        endpoints.MapHealthChecks(ReadinessPath, new HealthCheckOptions { Predicate = IsReadinessCheck });
        return endpoints;
    }

    private static bool IsReadinessCheck(HealthCheckRegistration registration) =>
        registration.Tags.Contains(ReadinessTag);
}
