//
//  AppInfo.cs
//  Hangly
//
//  What this build is, read from the build rather than written twice.
//

using System.Reflection;

namespace Hangly.App.Services;

/// <summary>Identity and configuration, read out of the assembly.</summary>
/// <remarks>
/// Everything here is written once, in the project file, and read back at runtime. The
/// About page showing a version that disagrees with the binary is a small thing that
/// makes everything else on the page look untrustworthy.
/// </remarks>
public static class AppInfo
{
    private static readonly Assembly Self = typeof(AppInfo).Assembly;

    public static string Name => "Charm Hangly";

    /// <summary>Marketing version, e.g. "2.0.0".</summary>
    public static string Version { get; } =
        Self.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            is { } informational && informational.Length > 0
            ? informational.Split('+')[0]
            : Self.GetName().Version?.ToString(3) ?? "0.0.0";

    public static string BuildNumber { get; } = Metadata("HanglyBuildNumber") is { Length: > 0 } build
        ? build
        : "1";

    public static string Copyright { get; } =
        Self.GetCustomAttribute<AssemblyCopyrightAttribute>()?.Copyright
        ?? "Copyright © 2026 sharancreatedthis";

    /// <summary>Where analytics would be sent.</summary>
    public static string AnalyticsHost { get; } = Metadata("HanglyAnalyticsHost") ?? string.Empty;

    /// <summary>The PostHog project key, empty when this build has none.</summary>
    public static string AnalyticsKey { get; } = Metadata("HanglyAnalyticsKey") ?? string.Empty;

    /// <summary>Whether this build has anywhere to send events.</summary>
    public static bool HasAnalyticsDestination =>
        AnalyticsKey.Length > 0 && AnalyticsHost.Length > 0;

    public static string WindowsVersion { get; } = Environment.OSVersion.Version.ToString();

    public static string WebsiteUrl => "https://charm-hangly.vercel.app";

    public static string GitHubUrl => "https://github.com/Srishanth-023/Charm-Hangly";

    /// <summary>Where the update feed lives.</summary>
    /// <remarks>
    /// GitHub Releases, which is where the artefacts already go, and which serves them as
    /// plain static files over HTTPS — so an update check stays a GET with nothing
    /// attached to it, exactly as DISTRIBUTION.md promises. The per-architecture channel
    /// is chosen by the updater, not named here.
    /// </remarks>
    public static string UpdateFeedUrl => GitHubUrl;

    public static string InstagramUrl => "https://www.instagram.com/sri.23._/";

    /// <summary>The creator's UPI address, as the macOS build carries it.</summary>
    public static string UpiId => "8870786087@yescred";

    public static string CoffeeUrl => "https://www.sharancreatedthis.in/coffee";

    /// <summary>Where "Suggest a charm" writes to.</summary>
    public static string SuggestMailUrl =>
        "mailto:srishanth232007@gmail.com?subject=Hangly%20charm%20suggestion";

    private static string? Metadata(string key) => Self
        .GetCustomAttributes<AssemblyMetadataAttribute>()
        .FirstOrDefault(attribute => attribute.Key == key)
        ?.Value;
}
