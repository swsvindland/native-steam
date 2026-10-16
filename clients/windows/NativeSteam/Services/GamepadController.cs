using System;
using System.Collections.Generic;
using Microsoft.UI.Dispatching;
using Windows.Gaming.Input;

namespace NativeSteam.Services;

/// <summary>One-shot delayed work on the UI thread.</summary>
public static class DispatcherQueueTimerHelper
{
    // Keep running one-shot timers reachable until they fire.
    private static readonly HashSet<DispatcherQueueTimer> Active = new();

    public static void Run(DispatcherQueue queue, TimeSpan delay, Action action)
    {
        DispatcherQueueTimer timer = queue.CreateTimer();
        timer.Interval = delay;
        timer.IsRepeating = false;
        Active.Add(timer);
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            Active.Remove(timer);
            try
            {
                action();
            }
            catch (Exception ex)
            {
                App.Log("Deferred action failed: " + ex);
            }
        };
        timer.Start();
    }
}

/// <summary>
/// Polls <see cref="Gamepad"/> every ~16 ms on the UI thread (WinUI 3 desktop apps don't get
/// gamepad navigation for free), edge-detects buttons, maps the left stick onto the D-pad with
/// key-repeat, and forwards logical <see cref="PadAction"/>s to the shell.
/// </summary>
public sealed class GamepadController : IDisposable
{
    private const double StickThreshold = 0.55;
    private const double TriggerThreshold = 0.5;
    private static readonly TimeSpan RepeatDelay = TimeSpan.FromMilliseconds(380);
    private static readonly TimeSpan RepeatInterval = TimeSpan.FromMilliseconds(110);

    private const GamepadButtons Directions =
        GamepadButtons.DPadUp | GamepadButtons.DPadDown | GamepadButtons.DPadLeft | GamepadButtons.DPadRight;

    private readonly DispatcherQueueTimer _timer;
    private readonly ShellPage _shell;
    private GamepadButtons _previous = GamepadButtons.None;
    private GamepadButtons _heldDirection = GamepadButtons.None;
    private DateTime _nextRepeat = DateTime.MaxValue;
    private bool _leftTriggerDown;
    private bool _rightTriggerDown;
    private bool _disposed;
    private int _failures;

    public GamepadController(DispatcherQueue queue, ShellPage shell)
    {
        _shell = shell;
        _timer = queue.CreateTimer();
        _timer.Interval = TimeSpan.FromMilliseconds(16);
        _timer.IsRepeating = true;
        _timer.Tick += OnTick;

        try
        {
            Gamepad.GamepadAdded += OnGamepadAdded;
            Gamepad.GamepadRemoved += OnGamepadRemoved;
            if (Gamepad.Gamepads.Count > 0) InputModeService.SetGamepadPresent(true);
        }
        catch (Exception ex)
        {
            // No gaming input stack (e.g. some server SKUs): keyboard / mouse / touch still work.
            App.Log("Windows.Gaming.Input unavailable: " + ex.Message);
            return;
        }

        _timer.Start();
    }

    /// <summary>Shown in the hints bar.</summary>
    public string ControllerName { get; private set; } = "Controller";

    private void OnGamepadAdded(object? sender, Gamepad e)
    {
        string name = "Controller";
        try
        {
            RawGameController? raw = RawGameController.FromGameController(e);
            if (raw is not null && !string.IsNullOrWhiteSpace(raw.DisplayName)) name = raw.DisplayName;
        }
        catch
        {
            // DisplayName is best-effort only.
        }
        ControllerName = name;
        InputModeService.SetGamepadPresent(true);
    }

    private void OnGamepadRemoved(object? sender, Gamepad e)
    {
        try
        {
            if (Gamepad.Gamepads.Count == 0) InputModeService.SetGamepadPresent(false);
        }
        catch
        {
            // ignore
        }
    }

    private void OnTick(DispatcherQueueTimer sender, object args)
    {
        Gamepad? pad = null;
        GamepadReading reading;
        try
        {
            var pads = Gamepad.Gamepads;
            if (pads.Count > 0)
            {
                pad = pads[0];
                reading = pad.GetCurrentReading();
            }
            else
            {
                reading = default;
            }
        }
        catch (Exception ex)
        {
            if (++_failures == 30)
            {
                App.Log("Gamepad polling disabled: " + ex.Message);
                _timer.Stop();
            }
            return;
        }

        if (pad is null)
        {
            _previous = GamepadButtons.None;
            _heldDirection = GamepadButtons.None;
            return;
        }

        GamepadButtons buttons = reading.Buttons;

        // Left stick acts as a D-pad.
        if (reading.LeftThumbstickY > StickThreshold) buttons |= GamepadButtons.DPadUp;
        if (reading.LeftThumbstickY < -StickThreshold) buttons |= GamepadButtons.DPadDown;
        if (reading.LeftThumbstickX < -StickThreshold) buttons |= GamepadButtons.DPadLeft;
        if (reading.LeftThumbstickX > StickThreshold) buttons |= GamepadButtons.DPadRight;

        bool lt = reading.LeftTrigger > TriggerThreshold;
        bool rt = reading.RightTrigger > TriggerThreshold;

        GamepadButtons pressed = buttons & ~_previous;
        _previous = buttons;
        bool ltPressed = lt && !_leftTriggerDown;
        bool rtPressed = rt && !_rightTriggerDown;
        _leftTriggerDown = lt;
        _rightTriggerDown = rt;

        if (pressed != GamepadButtons.None || ltPressed || rtPressed)
        {
            InputModeService.Set(InputMode.Gamepad);
        }

        // Directions with key-repeat while held.
        GamepadButtons direction = buttons & Directions;
        DateTime now = DateTime.UtcNow;
        if (direction != _heldDirection)
        {
            _heldDirection = direction;
            _nextRepeat = now + RepeatDelay;
            Dispatch(pressed & Directions);
        }
        else if (direction != GamepadButtons.None && now >= _nextRepeat)
        {
            _nextRepeat = now + RepeatInterval;
            Dispatch(direction);
        }

        if (Has(pressed, GamepadButtons.A)) _shell.HandlePad(PadAction.Accept);
        if (Has(pressed, GamepadButtons.B)) _shell.HandlePad(PadAction.Back);
        if (Has(pressed, GamepadButtons.X)) _shell.HandlePad(PadAction.Secondary);
        if (Has(pressed, GamepadButtons.Y)) _shell.HandlePad(PadAction.Search);
        if (Has(pressed, GamepadButtons.Menu)) _shell.HandlePad(PadAction.Menu);
        if (Has(pressed, GamepadButtons.LeftShoulder)) _shell.HandlePad(PadAction.PreviousTab);
        if (Has(pressed, GamepadButtons.RightShoulder)) _shell.HandlePad(PadAction.NextTab);
        if (ltPressed) _shell.HandlePad(PadAction.PreviousSection);
        if (rtPressed) _shell.HandlePad(PadAction.NextSection);
    }

    private void Dispatch(GamepadButtons directions)
    {
        // One step per tick; vertical wins over horizontal on diagonals.
        if (Has(directions, GamepadButtons.DPadUp)) _shell.HandlePad(PadAction.Up);
        else if (Has(directions, GamepadButtons.DPadDown)) _shell.HandlePad(PadAction.Down);
        else if (Has(directions, GamepadButtons.DPadLeft)) _shell.HandlePad(PadAction.Left);
        else if (Has(directions, GamepadButtons.DPadRight)) _shell.HandlePad(PadAction.Right);
    }

    private static bool Has(GamepadButtons value, GamepadButtons flag) => (value & flag) == flag;

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _timer.Stop();
        try
        {
            Gamepad.GamepadAdded -= OnGamepadAdded;
            Gamepad.GamepadRemoved -= OnGamepadRemoved;
        }
        catch
        {
            // ignore
        }
    }
}
