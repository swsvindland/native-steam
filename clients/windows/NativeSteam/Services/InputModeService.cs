using System;

namespace NativeSteam.Services;

public enum InputMode
{
    Mouse,
    Touch,
    Keyboard,
    Gamepad,
}

/// <summary>
/// Tracks the last-used input device (DESIGN.md §3). The shell shows the
/// Big-Picture-style hints bar and LB/RB glyphs while this is <see cref="InputMode.Gamepad"/>.
/// </summary>
public static class InputModeService
{
    public static InputMode Current { get; private set; } = InputMode.Mouse;

    /// <summary>True once any gamepad has been seen (or <c>--input gamepad</c> was passed).</summary>
    public static bool GamepadPresent { get; private set; }

    public static event EventHandler<InputMode>? Changed;

    public static bool IsFocusDriven => Current is InputMode.Keyboard or InputMode.Gamepad;

    public static void Set(InputMode mode)
    {
        if (mode == InputMode.Gamepad) GamepadPresent = true;
        if (Current == mode) return;
        Current = mode;
        Changed?.Invoke(null, mode);
    }

    public static void SetGamepadPresent(bool present)
    {
        if (GamepadPresent == present) return;
        GamepadPresent = present;
        Changed?.Invoke(null, Current);
    }
}
