//
//  App.xaml.cs
//  Hangly
//

using Hangly.App.Interop;
using Hangly.App.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;

namespace Hangly.App;

/// <summary>The application, which owns exactly one thing: the composition root.</summary>
/// <remarks>
/// There is no main window and no <c>Window</c> created here, which is why nothing appears
/// at launch. The overlay is built by <see cref="AppEnvironment"/> when the settings say
/// it is enabled, and the tray icon is the only thing that always exists.
///
/// <para>That also means a failure here is invisible — no window closes, because none was
/// ever opened. <see cref="Diagnostics"/> is installed before anything else runs, so the
/// app can say what happened even when there is nothing on screen to say it with.</para>
/// </remarks>
public partial class App : Application
{
    private AppEnvironment? environment;

    public App()
    {
        Diagnostics.Install();
        Diagnostics.Log("App constructed");

        // XAML swallows exceptions raised inside its own dispatch and shuts the process
        // down. This is the only place they can be seen.
        UnhandledException += (_, args) =>
        {
            Diagnostics.Failure("xaml", args.Exception);
            args.Handled = true;
        };

        RegisterBrandFont();
        InitializeComponent();
    }

    /// <summary>
    /// Points the app's default font at Cinzel, mobile's headline font (there fetched at
    /// runtime by the google_fonts package; here shipped as a file since this build has no
    /// such fetch step).
    ///
    /// <para><b>Two things had to be true, not one.</b> The first attempt at this set a
    /// <c>file:///…#Cinzel</c> URI as the <see cref="FontFamily"/> and it silently did not
    /// take — that URI form is documented for a packaged app's <c>ms-appx:///</c> path,
    /// and this app has no package for it to resolve against. <c>AddFontResourceEx</c>
    /// (FR_PRIVATE, in <see cref="NativeMethods"/>) sidesteps that entirely by registering
    /// the file with Windows' own font stack for this process only, so the font can then
    /// be asked for by its plain name "Cinzel" exactly the way "Segoe UI" would be — no
    /// separate URI-resolution path inside WinUI left to disagree with. Windows removes a
    /// FR_PRIVATE registration itself when the process exits, so there is deliberately no
    /// matching cleanup call here.</para>
    ///
    /// <para>Overriding <c>ContentControlThemeFontFamily</c> is what makes this a one-line
    /// change rather than a restatement on every TextBlock and Control: it is the single
    /// resource key Fluent's own control templates and typographic ramp styles
    /// (BodyTextBlockStyle, CaptionTextBlockStyle, and so on) already read their
    /// FontFamily from. It has to be written into <c>Resources.ThemeDictionaries["Dark"]</c>
    /// rather than into <c>Resources</c> directly, because Fluent itself declares that key
    /// inside its own per-theme dictionaries — a <c>ThemeResource</c> lookup that finds a
    /// themed definition never falls through to a flat one, so a flat override loses to
    /// Fluent's value every time regardless of merge order.</para>
    ///
    /// <para>Never fatal: a missing font file, or a registration Windows refuses, leaves
    /// the app on the default Windows font rather than crashing, the same tolerance the
    /// Mica/Acrylic backdrop fallback elsewhere in this app gives a missing visual
    /// nicety.</para>
    /// </summary>
    private static void RegisterBrandFont()
    {
        try
        {
            string path = Path.Combine(AppContext.BaseDirectory, "Assets", "Fonts", "Cinzel-Regular.ttf");
            if (!File.Exists(path))
            {
                Diagnostics.Log($"brand font missing at {path}; keeping the default Windows font");
                return;
            }

            int added = NativeMethods.AddFontResourceEx(
                path,
                NativeMethods.FrPrivate,
                IntPtr.Zero);

            Diagnostics.Log($"Cinzel registration result: {added}");
            
            if (added <= 0)
            {
                Diagnostics.Log($"AddFontResourceEx declined {path}; keeping the default Windows font");
                return;
            }
        }
        catch (Exception exception)
        {
            Diagnostics.Failure("brand-font-registration", exception);
        }
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        Diagnostics.Log("OnLaunched");
        ApplyBrandFont();

        try
        {
            environment = new AppEnvironment();
            environment.Bootstrap();
            Diagnostics.Log("Bootstrap returned");
            environment.ShowWelcomeIfNeeded();
        }
        catch (Exception exception)
        {
            Diagnostics.Failure("bootstrap", exception);
            throw;
        }
    }

    private void ApplyBrandFont()
    {
        try
        {
            var font = new FontFamily("Cinzel");

            if (this.Resources.ThemeDictionaries.TryGetValue("Dark", out object darkThemeObject)
                && darkThemeObject is ResourceDictionary dark)
            {
                dark["ContentControlThemeFontFamily"] = font;
                dark["CaptionTextBlockFontFamily"] = font;
                dark["BodyTextBlockFontFamily"] = font;
                dark["SubtitleTextBlockFontFamily"] = font;
                dark["TitleTextBlockFontFamily"] = font;
                dark["TitleLargeTextBlockFontFamily"] = font;
                dark["DisplayTextBlockFontFamily"] = font;
            }
            else
            {
                this.Resources["ContentControlThemeFontFamily"] = font;
                this.Resources["CaptionTextBlockFontFamily"] = font;
                this.Resources["BodyTextBlockFontFamily"] = font;
                this.Resources["SubtitleTextBlockFontFamily"] = font;
                this.Resources["TitleTextBlockFontFamily"] = font;
                this.Resources["TitleLargeTextBlockFontFamily"] = font;
                this.Resources["DisplayTextBlockFontFamily"] = font;
            }

            Diagnostics.Log("Cinzel applied via C# dictionary override");
        }
        catch (Exception exception)
        {
            Diagnostics.Failure("brand-font-application", exception);
        }
    }
}
