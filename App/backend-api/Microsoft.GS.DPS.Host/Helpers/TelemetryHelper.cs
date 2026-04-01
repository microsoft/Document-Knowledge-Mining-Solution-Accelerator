using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using System.Diagnostics;

namespace Microsoft.GS.DPSHost.Helpers
{
    /// <summary>
    /// Helper class for Application Insights telemetry tracking
    /// </summary>
    public class TelemetryHelper
    {
        private readonly TelemetryClient? _telemetryClient;
        private readonly ILogger<TelemetryHelper> _logger;
        private readonly bool _isConfigured;

        public TelemetryHelper(TelemetryClient? telemetryClient, ILogger<TelemetryHelper> logger)
        {
            _telemetryClient = telemetryClient;
            _logger = logger;
            _isConfigured = !string.IsNullOrEmpty(_telemetryClient?.InstrumentationKey);

            if (!_isConfigured)
            {
                _logger.LogWarning("Application Insights is not configured. Telemetry tracking will be disabled.");
            }
        }

        /// <summary>
        /// Track a custom event in Application Insights
        /// </summary>
        /// <param name="eventName">Name of the event</param>
        /// <param name="properties">Custom properties to track</param>
        /// <param name="metrics">Custom metrics to track</param>
        public void TrackEvent(string eventName, Dictionary<string, string>? properties = null, Dictionary<string, double>? metrics = null)
        {
            if (!_isConfigured || _telemetryClient == null)
            {
                return;
            }

            try
            {
                _telemetryClient.TrackEvent(eventName, properties, metrics);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track event: {EventName}", eventName);
            }
        }

        /// <summary>
        /// Track an exception in Application Insights
        /// </summary>
        /// <param name="exception">The exception to track</param>
        /// <param name="properties">Custom properties to track</param>
        /// <param name="metrics">Custom metrics to track</param>
        public void TrackException(Exception exception, Dictionary<string, string>? properties = null, Dictionary<string, double>? metrics = null)
        {
            if (!_isConfigured || _telemetryClient == null)
            {
                return;
            }

            try
            {
                _telemetryClient.TrackException(exception, properties, metrics);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track exception");
            }
        }

        /// <summary>
        /// Track a dependency call in Application Insights
        /// </summary>
        /// <param name="dependencyName">Name of the dependency</param>
        /// <param name="commandName">Command or operation name</param>
        /// <param name="startTime">Start time of the operation</param>
        /// <param name="duration">Duration of the operation</param>
        /// <param name="success">Whether the operation was successful</param>
        public void TrackDependency(string dependencyName, string commandName, DateTimeOffset startTime, TimeSpan duration, bool success)
        {
            if (!_isConfigured || _telemetryClient == null)
            {
                return;
            }

            try
            {
                _telemetryClient.TrackDependency(dependencyName, commandName, startTime, duration, success);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track dependency: {DependencyName}", dependencyName);
            }
        }

        /// <summary>
        /// Track a metric in Application Insights
        /// </summary>
        /// <param name="metricName">Name of the metric</param>
        /// <param name="value">Metric value</param>
        /// <param name="properties">Custom properties to track</param>
        public void TrackMetric(string metricName, double value, Dictionary<string, string>? properties = null)
        {
            if (!_isConfigured || _telemetryClient == null)
            {
                return;
            }

            try
            {
                _telemetryClient.TrackMetric(metricName, value, properties);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to track metric: {MetricName}", metricName);
            }
        }

        /// <summary>
        /// Sets a custom property on the current activity for correlation
        /// </summary>
        /// <param name="key">Property key</param>
        /// <param name="value">Property value</param>
        public void SetActivityTag(string key, string value)
        {
            if (!_isConfigured)
            {
                return;
            }

            try
            {
                Activity.Current?.SetTag(key, value);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to set activity tag: {Key}", key);
            }
        }

        /// <summary>
        /// Flush the telemetry client to ensure all telemetry is sent
        /// </summary>
        public void Flush()
        {
            if (!_isConfigured || _telemetryClient == null)
            {
                return;
            }

            try
            {
                _telemetryClient.Flush();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to flush telemetry client");
            }
        }
    }
}
