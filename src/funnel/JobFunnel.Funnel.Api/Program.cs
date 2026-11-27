using JobFunnel.Funnel.Api.Health;
using Serilog;
using Serilog.Formatting.Compact;

var builder = WebApplication.CreateBuilder(args);

// The logger lives in the container rather than in the static Log.Logger, so each host has its own.
builder.Services.AddSerilog(
    (services, logger) => logger
        .ReadFrom.Configuration(builder.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .WriteTo.Console(new RenderedCompactJsonFormatter()),
    preserveStaticLogger: true);

builder.Services.AddFunnelHealthChecks();

var app = builder.Build();

app.UseSerilogRequestLogging(options => options.Logger = app.Services.GetRequiredService<Serilog.ILogger>());

app.MapFunnelHealthChecks();

await app.RunAsync();
