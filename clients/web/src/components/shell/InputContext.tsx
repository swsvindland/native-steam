"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

export type InputMode = "mouse" | "touch" | "keyboard" | "gamepad";
const MODES: InputMode[] = ["mouse", "touch", "keyboard", "gamepad"];

interface InputState {
  mode: InputMode;
  /** True once the Gamepad API has reported a controller. */
  gamepadConnected: boolean;
  setMode: (mode: InputMode, opts?: { force?: boolean }) => void;
  setGamepadConnected: (v: boolean) => void;
  /** Set by `?input=…`: pointer *movement* no longer changes the mode (a real click/tap still does). */
  forced: React.RefObject<boolean>;
}

const Ctx = createContext<InputState | null>(null);

function readInitialMode(): InputMode {
  if (typeof document === "undefined") return "mouse";
  const m = document.documentElement.dataset.input as InputMode | undefined;
  return m && MODES.includes(m) ? m : "mouse";
}

/**
 * Tracks the last-used input and mirrors it to `<html data-input="…">` so CSS
 * can decide when to show focus rings, hover lifts, touch targets and the
 * gamepad hints bar. Pointer movement / taps / keys update it here; the
 * keyboard + gamepad controller updates it via `setMode`.
 */
export function InputProvider({ children }: { children: React.ReactNode }) {
  const [mode, setModeState] = useState<InputMode>("mouse");
  const [gamepadConnected, setGamepadConnected] = useState(false);
  const modeRef = useRef<InputMode>("mouse");
  const forced = useRef(false);

  const setMode = useCallback((next: InputMode, opts?: { force?: boolean }) => {
    if (forced.current && !opts?.force) return;
    if (modeRef.current === next) return;
    modeRef.current = next;
    document.documentElement.dataset.input = next;
    setModeState(next);
  }, []);

  useEffect(() => {
    // The inline script in <head> already set data-input before first paint.
    const initial = readInitialMode();
    modeRef.current = initial;
    forced.current = document.documentElement.dataset.inputForced === "1";
    setModeState(initial);

    let moved = 0;
    let lastX = -1;
    let lastY = -1;
    const onPointerDown = (e: PointerEvent) => {
      forced.current = false; // a real click/tap always wins
      setMode(e.pointerType === "mouse" ? "mouse" : "touch");
    };
    const onPointerMove = (e: PointerEvent) => {
      if (e.pointerType !== "mouse" || modeRef.current === "mouse") return;
      if (lastX >= 0) moved += Math.abs(e.clientX - lastX) + Math.abs(e.clientY - lastY);
      lastX = e.clientX;
      lastY = e.clientY;
      if (moved > 12) {
        moved = 0;
        setMode("mouse");
      }
    };
    const onWheel = () => {
      if (modeRef.current === "keyboard") setMode("mouse");
    };
    const resetMove = () => {
      moved = 0;
      lastX = -1;
    };
    window.addEventListener("pointerdown", onPointerDown, { capture: true, passive: true });
    window.addEventListener("pointermove", onPointerMove, { passive: true });
    window.addEventListener("wheel", onWheel, { passive: true });
    window.addEventListener("keydown", resetMove, true);
    return () => {
      window.removeEventListener("pointerdown", onPointerDown, { capture: true });
      window.removeEventListener("pointermove", onPointerMove);
      window.removeEventListener("wheel", onWheel);
      window.removeEventListener("keydown", resetMove, true);
    };
  }, [setMode]);

  const value = useMemo(
    () => ({ mode, gamepadConnected, setMode, setGamepadConnected, forced }),
    [mode, gamepadConnected, setMode],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useInput(): InputState {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useInput outside InputProvider");
  return ctx;
}

/** Runs before hydration (inlined in <head>) so the first paint already has the right mode. */
export const INPUT_BOOT_SCRIPT = `(function(){try{var d=document.documentElement;var q=new URLSearchParams(location.search).get('input');var ok=['mouse','touch','keyboard','gamepad'];var m=ok.indexOf(q)>=0?q:(matchMedia('(pointer: coarse)').matches?'touch':'mouse');d.dataset.input=m;if(ok.indexOf(q)>=0)d.dataset.inputForced='1';}catch(e){}})();`;
