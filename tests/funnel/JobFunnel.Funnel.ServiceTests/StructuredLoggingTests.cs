using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Serilog.Core;
using Serilog.Events;

namespace JobFunnel.Funnel.ServiceTests;

public class StructuredLoggingTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Each_request_is_logged_as_a_structured_event()
    {
        var sink = new RequestLogSink();
        using var client = factory
            .WithWebHostBuilder(builder => builder.ConfigureTestServices(services => services.AddSingleton<ILogEventSink>(sink)))
            .CreateClient();

        using var _ = await client.GetAsync(new Uri("/health/live", UriKind.Relative), TestContext.Current.CancellationToken);

        // The request log is written once the response has completed, which can be after the client has it.
        var request = await sink.FirstRequestLog.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);
        request.Properties["RequestMethod"].ShouldBe(new ScalarValue("GET"));
        request.Properties["RequestPath"].ShouldBe(new ScalarValue("/health/live"));
        request.Properties["StatusCode"].ShouldBe(new ScalarValue(200));
        request.TraceId.ShouldNotBeNull();
    }

    private sealed class RequestLogSink : ILogEventSink
    {
        private readonly TaskCompletionSource<LogEvent> _firstRequestLog = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public Task<LogEvent> FirstRequestLog => _firstRequestLog.Task;

        public void Emit(LogEvent logEvent)
        {
            if (logEvent.Properties.ContainsKey("RequestPath") && logEvent.Properties.ContainsKey("StatusCode"))
            {
                _firstRequestLog.TrySetResult(logEvent);
            }
        }
    }
}
