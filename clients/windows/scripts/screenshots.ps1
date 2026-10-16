<#
.SYNOPSIS
    Launches the built Native Steam WinUI client once per screen and captures the window to PNG.

.DESCRIPTION
    Used by .github/workflows/windows.yml on windows-latest, but works on any Windows 10/11 desktop:

        dotnet build clients/windows/NativeSteam/NativeSteam.csproj -c Release -p:Platform=x64
        powershell -ExecutionPolicy Bypass -File clients/windows/scripts/screenshots.ps1

    For every shot the script starts NativeSteam.exe with deterministic command-line switches
    (--tab/--game/--input/--size), waits for the window and for Steam CDN artwork to load, brings
    the window to the front, captures it (screen copy of the DWM frame bounds, falling back to
    PrintWindow with PW_RENDERFULLCONTENT), saves docs/screenshots/windows/<name>.png and kills
    the process.

    Written for Windows PowerShell 5.1 (the inline C# is C# 5) so it also runs under pwsh.
#>
[CmdletBinding()]
param(
    [string] $Configuration = 'Release',
    [string] $Platform = 'x64',
    [string] $OutDir = '',
    [string] $Size = '1440x900',
    [int] $WaitSeconds = 10,
    [string[]] $Only = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$clientRoot = Split-Path -Parent $PSScriptRoot                 # clients/windows
$repoRoot = Split-Path -Parent (Split-Path -Parent $clientRoot)  # repo root
if ([string]::IsNullOrEmpty($OutDir)) { $OutDir = Join-Path $repoRoot 'docs\screenshots\windows' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

$binRoot = Join-Path $clientRoot "NativeSteam\bin\$Platform\$Configuration"
$exe = Get-ChildItem -Path $binRoot -Filter 'NativeSteam.exe' -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $exe) { throw "NativeSteam.exe not found under $binRoot. Build first: dotnet build clients/windows/NativeSteam/NativeSteam.csproj -c $Configuration -p:Platform=$Platform" }
Write-Host "Using $($exe.FullName)"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class NsCapture
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
        public int dmDisplayFlags; public int dmDisplayFrequency;
        public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
        public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
    }

    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr processId);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attach, uint attachTo, bool fAttach);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out RECT rect, int size);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
    [DllImport("user32.dll", CharSet = CharSet.Ansi)] public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    const uint SWP_NOMOVE = 0x0002, SWP_NOSIZE = 0x0001, SWP_SHOWWINDOW = 0x0040;

    /// <summary>Best effort: makes the window visible, topmost and foreground.</summary>
    public static void BringToFront(IntPtr hwnd)
    {
        ShowWindow(hwnd, 9); // SW_RESTORE
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
        // Borrow the foreground thread's input state to lift the foreground lock.
        // (No synthetic key presses: those would flip the app into keyboard mode
        // and draw focus rectangles in the screenshots.)
        uint me = GetCurrentThreadId();
        uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        bool attached = fg != 0 && fg != me && AttachThreadInput(me, fg, true);
        SetForegroundWindow(hwnd);
        BringWindowToTop(hwnd);
        if (attached) AttachThreadInput(me, fg, false);
    }

    /// <summary>The visible window bounds (excludes the invisible resize borders).</summary>
    public static Rectangle FrameBounds(IntPtr hwnd)
    {
        RECT r;
        if (DwmGetWindowAttribute(hwnd, 9 /* DWMWA_EXTENDED_FRAME_BOUNDS */, out r, Marshal.SizeOf(typeof(RECT))) != 0)
        {
            GetWindowRect(hwnd, out r);
        }
        return Rectangle.FromLTRB(r.Left, r.Top, r.Right, r.Bottom);
    }

    public static Bitmap CaptureScreen(IntPtr hwnd)
    {
        Rectangle b = FrameBounds(hwnd);
        Bitmap bmp = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.CopyFromScreen(b.Left, b.Top, 0, 0, b.Size, CopyPixelOperation.SourceCopy);
        }
        return bmp;
    }

    public static Bitmap CapturePrintWindow(IntPtr hwnd)
    {
        RECT wr;
        GetWindowRect(hwnd, out wr);
        Rectangle frame = FrameBounds(hwnd);
        int w = wr.Right - wr.Left, h = wr.Bottom - wr.Top;
        using (Bitmap full = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (Graphics g = Graphics.FromImage(full))
            {
                IntPtr hdc = g.GetHdc();
                try { PrintWindow(hwnd, hdc, 2 /* PW_RENDERFULLCONTENT */); }
                finally { g.ReleaseHdc(hdc); }
            }
            Rectangle crop = new Rectangle(frame.Left - wr.Left, frame.Top - wr.Top, frame.Width, frame.Height);
            crop.Intersect(new Rectangle(0, 0, w, h));
            return full.Clone(crop, PixelFormat.Format32bppArgb);
        }
    }

    /// <summary>True when the bitmap is (almost) a single colour, i.e. the capture failed.</summary>
    public static bool LooksBlank(Bitmap bmp)
    {
        if (bmp.Width < 8 || bmp.Height < 8) return true;
        Color first = bmp.GetPixel(bmp.Width / 2, bmp.Height / 2);
        int different = 0;
        for (int y = 1; y < 8; y++)
        {
            for (int x = 1; x < 8; x++)
            {
                Color c = bmp.GetPixel(bmp.Width * x / 8, bmp.Height * y / 8);
                if (Math.Abs(c.R - first.R) + Math.Abs(c.G - first.G) + Math.Abs(c.B - first.B) > 24) different++;
            }
        }
        return different < 4;
    }

    /// <summary>Switches the primary display mode if it is smaller than requested. Returns a status string.</summary>
    public static string EnsureResolution(int width, int height)
    {
        DEVMODE dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        if (EnumDisplaySettings(null, -1 /* ENUM_CURRENT_SETTINGS */, ref dm) == 0) return "EnumDisplaySettings failed";
        if (dm.dmPelsWidth >= width && dm.dmPelsHeight >= height) return "display is " + dm.dmPelsWidth + "x" + dm.dmPelsHeight;
        dm.dmPelsWidth = width;
        dm.dmPelsHeight = height;
        dm.dmFields = 0x00080000 | 0x00100000; // DM_PELSWIDTH | DM_PELSHEIGHT
        int result = ChangeDisplaySettings(ref dm, 0);
        return "ChangeDisplaySettings(" + width + "x" + height + ") = " + result;
    }
}
'@

[void][NsCapture]::SetProcessDPIAware()

# The window must fit on screen for a faithful screen copy (hosted runners boot at 1024x768).
$sizeParts = $Size.ToLowerInvariant().Split('x')
$needW = [int]$sizeParts[0] + 64
$needH = [int]$sizeParts[1] + 96
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
if ($screen.Width -lt $needW -or $screen.Height -lt $needH) {
    Write-Host "Screen is $($screen.Width)x$($screen.Height); switching to 1920x1080"
    try {
        Set-DisplayResolution -Width 1920 -Height 1080 -Force -ErrorAction Stop
    }
    catch {
        Write-Host "Set-DisplayResolution unavailable ($($_.Exception.Message)); using ChangeDisplaySettings"
        Write-Host ([NsCapture]::EnsureResolution(1920, 1080))
    }
    Start-Sleep -Seconds 2
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
}
Write-Host "Screen: $($screen.Width)x$($screen.Height)"

# Keep the mouse pointer out of the shots (and away from hover states).
[void][NsCapture]::SetCursorPos(0, $screen.Height - 1)

$shots = @(
    @{ Name = 'store';           Args = @('--tab', 'store') },
    @{ Name = 'library';         Args = @('--tab', 'library') },
    @{ Name = 'community';       Args = @('--tab', 'community') },
    @{ Name = 'profile';         Args = @('--tab', 'profile') },
    @{ Name = 'game';            Args = @('--tab', 'library', '--game', '1145350') },
    @{ Name = 'gamepad';         Args = @('--tab', 'library', '--input', 'gamepad') },
    @{ Name = 'app';             Args = @('--tab', 'store', '--app', '3470960') },
    @{ Name = 'library-compact'; Args = @('--tab', 'library'); Size = '430x900' },
    @{ Name = 'store-compact';   Args = @('--tab', 'store'); Size = '430x900' }
)

$logFile = Join-Path $exe.DirectoryName 'nativesteam.log'
$captured = 0
$failed = @()

foreach ($shot in $shots) {
    if ($Only.Count -gt 0 -and -not ($Only -contains $shot.Name)) { continue }
    $shotSize = $Size
    if ($shot.ContainsKey('Size')) { $shotSize = $shot.Size }
    $arguments = @($shot.Args) + @('--size', $shotSize)
    $target = Join-Path $OutDir ($shot.Name + '.png')
    Write-Host ""
    Write-Host "=== $($shot.Name): NativeSteam.exe $($arguments -join ' ')"

    $proc = $null
    try {
        $proc = Start-Process -FilePath $exe.FullName -ArgumentList $arguments -WorkingDirectory $exe.DirectoryName -PassThru

        # Wait for the top-level window.
        $hwnd = [IntPtr]::Zero
        $deadline = (Get-Date).AddSeconds(45)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 250
            $proc.Refresh()
            if ($proc.HasExited) { throw "process exited early with code $($proc.ExitCode)" }
            if ($proc.MainWindowHandle -ne [IntPtr]::Zero -and [NsCapture]::IsWindowVisible($proc.MainWindowHandle)) {
                $hwnd = $proc.MainWindowHandle
                break
            }
        }
        if ($hwnd -eq [IntPtr]::Zero) { throw 'no main window within 45 s' }

        [NsCapture]::BringToFront($hwnd)
        # Let pages lay out and Steam CDN artwork stream in.
        Start-Sleep -Seconds $WaitSeconds
        [NsCapture]::BringToFront($hwnd)
        Start-Sleep -Milliseconds 700

        $bmp = [NsCapture]::CaptureScreen($hwnd)
        if ([NsCapture]::LooksBlank($bmp)) {
            Write-Host 'Screen copy looks blank; retrying with PrintWindow(PW_RENDERFULLCONTENT)'
            $bmp.Dispose()
            $bmp = [NsCapture]::CapturePrintWindow($hwnd)
        }
        $bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "Saved $target ($($bmp.Width)x$($bmp.Height))"
        $bmp.Dispose()
        $captured++
    }
    catch {
        Write-Warning "$($shot.Name) failed: $($_.Exception.Message)"
        $failed += $shot.Name
    }
    finally {
        if ($null -ne $proc -and -not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            $proc.WaitForExit(5000) | Out-Null
        }
        Start-Sleep -Milliseconds 800
    }
}

if (Test-Path $logFile) {
    Write-Host ""
    Write-Host "--- nativesteam.log (tail) ---"
    Get-Content $logFile -Tail 80 | ForEach-Object { Write-Host $_ }
}

Write-Host ""
Write-Host "Captured $captured screenshot(s) to $OutDir"
if ($failed.Count -gt 0) { Write-Warning ("Failed: " + ($failed -join ', ')) }
if ($captured -eq 0) { exit 1 }
exit 0
