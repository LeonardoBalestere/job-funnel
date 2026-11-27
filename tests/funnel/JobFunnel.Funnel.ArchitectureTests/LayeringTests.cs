using System.Reflection;
using NetArchTest.Rules;

namespace JobFunnel.Funnel.ArchitectureTests;

public class LayeringTests
{
    private const string DomainNamespace = "JobFunnel.Funnel.Domain";
    private const string ApplicationNamespace = "JobFunnel.Funnel.Application";
    private const string InfrastructureNamespace = "JobFunnel.Funnel.Infrastructure";
    private const string ApiNamespace = "JobFunnel.Funnel.Api";

    private static readonly Assembly DomainAssembly = typeof(Domain.AssemblyReference).Assembly;
    private static readonly Assembly ApplicationAssembly = typeof(Application.AssemblyReference).Assembly;
    private static readonly Assembly InfrastructureAssembly = typeof(Infrastructure.AssemblyReference).Assembly;

    [Fact]
    public void Domain_does_not_depend_on_any_other_layer()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(ApplicationNamespace, InfrastructureNamespace, ApiNamespace)
            .GetResult();

        result.IsSuccessful.ShouldBeTrue(Describe(result));
    }

    [Fact]
    public void Domain_does_not_depend_on_infrastructure_frameworks()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(
                "Microsoft.AspNetCore",
                "Microsoft.EntityFrameworkCore",
                "Microsoft.Data.SqlClient",
                "Dapper",
                "RabbitMQ",
                "Serilog")
            .GetResult();

        result.IsSuccessful.ShouldBeTrue(Describe(result));
    }

    [Fact]
    public void Application_does_not_depend_on_infrastructure_or_api()
    {
        var result = Types.InAssembly(ApplicationAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(InfrastructureNamespace, ApiNamespace)
            .GetResult();

        result.IsSuccessful.ShouldBeTrue(Describe(result));
    }

    [Fact]
    public void Infrastructure_does_not_depend_on_api()
    {
        var result = Types.InAssembly(InfrastructureAssembly)
            .ShouldNot()
            .HaveDependencyOn(ApiNamespace)
            .GetResult();

        result.IsSuccessful.ShouldBeTrue(Describe(result));
    }

    // Catches a project reference added to the domain before any type uses it.
    [Fact]
    public void Domain_project_references_no_other_layer()
    {
        var referenced = DomainAssembly.GetReferencedAssemblies().Select(a => a.Name);

        referenced.ShouldNotContain(name => name == ApplicationNamespace || name == InfrastructureNamespace || name == ApiNamespace);
    }

    private static string Describe(NetArchTest.Rules.TestResult result) =>
        "Offending types: " + string.Join(", ", result.FailingTypeNames ?? []);
}
