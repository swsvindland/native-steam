"use client";

import { useEffect, useRef } from "react";
import { type Direction, findNext, focusElement, initialFocusTarget } from "@/lib/spatial";
import { useInput } from "./InputContext";
import { useNav } from "./NavContext";
import { useUserState } from "./UserState";

// Standard Gamepad mapping (Xbox names).
const BTN = { A: 0, B: 1, X: 2, Y: 3, LB: 4, RB: 5, LT: 6, RT: 7, VIEW: 8, MENU: 9, UP: 12, DOWN: 13, LEFT: 14, RIGHT: 15 };
const STICK_DEADZONE = 0.5;
const REPEAT_DELAY = 380;
const REPEAT_RATE = 110;

function isTyping(el: Element | null): el is HTMLInputElement | HTMLTextAreaElement {
  if (!el) return false;
  if (el instanceof HTMLTextAreaElement) return true;
  if (el instanceof HTMLInputElement) return !["button", "checkbox", "radio", "range", "submit"].includes(el.type);
  return (el as HTMLElement).isContentEditable;
}

function active(): HTMLElement | null {
  const el = document.activeElement as HTMLElement | null;
  return el && el !== document.body && el !== document.documentElement ? el : null;
}

/**
 * Keyboard + gamepad controller. Arrow keys / D-pad / left stick drive
 * spatial navigation; A / Enter activates; B / Esc goes back; LB / RB and
 * ⌘/Ctrl+1…4 switch tabs; Y / ⌘/Ctrl+F focus search; X is the focused item's
 * secondary action (favorite / wishlist / like); LT / RT page sections.
 */
export function Controller() {
  const nav = useNav();
  const input = useInput();
  const user = useUserState();
  const navRef = useRef(nav);
  navRef.current = nav;
  const userRef = useRef(user);
  userRef.current = user;
  const { setMode, setGamepadConnected } = input;

  // Spatial move shared by keyboard and gamepad.
  const move = (dir: Direction) => {
    // An open overlay (lightbox) captures navigation.
    const overlay = document.querySelector<HTMLElement>("[data-overlay]");
    if (overlay) {
      const stepper = overlay.querySelector<HTMLElement>(`[data-dir="${dir}"]`);
      if (stepper) return stepper.click();
      const cur = active();
      const next = cur && overlay.contains(cur) ? findNext(cur, dir, overlay) : overlay.querySelector<HTMLElement>("button");
      if (next) focusElement(next);
      return;
    }
    const cur = active();
    if (!cur) {
      const first = initialFocusTarget();
      if (first) focusElement(first);
      return;
    }
    const next = findNext(cur, dir);
    if (next) focusElement(next);
  };
  const moveRef = useRef(move);
  moveRef.current = move;

  const activate = () => {
    const el = active();
    if (!el) return moveRef.current("down");
    if (isTyping(el)) {
      // Submitting a search field: hop to the first result if there is one.
      const first = document.querySelector<HTMLElement>("[data-search-result]");
      if (first) focusElement(first);
      return;
    }
    el.click();
  };

  // ---- Keyboard -----------------------------------------------------------
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Shift" && e.key !== "Control" && e.key !== "Meta" && e.key !== "Alt") setMode("keyboard");
      if (e.defaultPrevented) return;
      const n = navRef.current;
      const mod = e.metaKey || e.ctrlKey;
      const target = e.target as Element | null;
      const typing = isTyping(target);

      if (mod && !e.altKey && !e.shiftKey) {
        if (e.key >= "1" && e.key <= "4") {
          e.preventDefault();
          n.switchTab(["store", "library", "community", "profile"][Number(e.key) - 1] as never);
          return;
        }
        if (e.key.toLowerCase() === "f") {
          e.preventDefault();
          n.focusSearch();
          return;
        }
        if (e.key === "[") {
          e.preventDefault();
          n.back();
          return;
        }
        return;
      }
      if (e.altKey || mod) return;

      const dirs: Record<string, Direction> = { ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right" };
      const dir = dirs[e.key];
      if (dir) {
        if (typing && (dir === "left" || dir === "right")) return; // caret movement
        e.preventDefault();
        moveRef.current(dir);
        return;
      }
      if (e.key === "Escape") {
        if (typing && (target as HTMLInputElement).value) return; // let the field clear itself
        e.preventDefault();
        if (typing) (target as HTMLElement).blur();
        n.back();
        return;
      }
      if (e.key === "Backspace" && !typing) {
        e.preventDefault();
        n.back();
        return;
      }
      if ((e.key === "Enter" || e.key === " ") && !typing && target instanceof HTMLElement) {
        // Native buttons handle both; links handle Enter. Fill in the gaps for
        // links + Space and for focusable cards (tabindex) that aren't buttons.
        const tag = target.tagName;
        const native = tag === "BUTTON" || (tag === "A" && e.key === "Enter") || tag === "SELECT";
        if (!native && target !== document.body) {
          e.preventDefault();
          target.click();
        }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [setMode]);

  // ---- Gamepad (polled in rAF) -------------------------------------------
  useEffect(() => {
    if (typeof navigator === "undefined" || !("getGamepads" in navigator)) return;
    let raf = 0;
    let running = false;
    const prev: boolean[] = [];
    let held: Direction | null = null;
    let nextRepeat = 0;

    const press = (i: number) => {
      const n = navRef.current;
      switch (i) {
        case BTN.A:
          return activate();
        case BTN.B: {
          const dismiss = document.querySelector<HTMLElement>("[data-overlay] [data-dismiss]");
          if (dismiss) return dismiss.click();
          const el = active();
          if (isTyping(el) && el.value) {
            el.value = "";
            el.dispatchEvent(new Event("input", { bubbles: true }));
            return;
          }
          if (isTyping(el)) el.blur();
          return n.back();
        }
        case BTN.X: {
          const el = active();
          if (el) userRef.current.secondary(el);
          return;
        }
        case BTN.Y:
          return n.focusSearch();
        case BTN.LB:
          return n.switchTab(-1);
        case BTN.RB:
          return n.switchTab(1);
        case BTN.LT:
          return n.page(-1);
        case BTN.RT:
          return n.page(1);
      }
    };

    const poll = (t: number) => {
      raf = requestAnimationFrame(poll);
      const pads = navigator.getGamepads();
      let pad: Gamepad | null = null;
      for (const p of pads) if (p && p.connected) pad = pad ?? p;
      if (!pad) return;

      let anyInput = false;
      const pressed = pad.buttons.map((b) => b.pressed || b.value > 0.5);
      pressed.forEach((down, i) => {
        if (down) anyInput = true;
        if (down && !prev[i] && i !== BTN.UP && i !== BTN.DOWN && i !== BTN.LEFT && i !== BTN.RIGHT) {
          setMode("gamepad", { force: true });
          press(i);
        }
        prev[i] = down;
      });

      const [ax = 0, ay = 0] = pad.axes;
      let dir: Direction | null = null;
      if (pressed[BTN.UP]) dir = "up";
      else if (pressed[BTN.DOWN]) dir = "down";
      else if (pressed[BTN.LEFT]) dir = "left";
      else if (pressed[BTN.RIGHT]) dir = "right";
      else if (Math.max(Math.abs(ax), Math.abs(ay)) > STICK_DEADZONE) {
        dir = Math.abs(ax) > Math.abs(ay) ? (ax > 0 ? "right" : "left") : ay > 0 ? "down" : "up";
      }
      if (dir) anyInput = true;
      // Right stick scrolls the page freely (Big Picture style).
      const ry = pad.axes[3] ?? 0;
      if (Math.abs(ry) > 0.25) {
        anyInput = true;
        window.scrollBy({ top: ry * 22 });
      }
      if (anyInput) setMode("gamepad", { force: true });

      if (dir && dir !== held) {
        held = dir;
        nextRepeat = t + REPEAT_DELAY;
        moveRef.current(dir);
      } else if (dir && t >= nextRepeat) {
        nextRepeat = t + REPEAT_RATE;
        moveRef.current(dir);
      } else if (!dir) held = null;
    };

    const start = () => {
      setGamepadConnected(true);
      if (!running) {
        running = true;
        raf = requestAnimationFrame(poll);
      }
    };
    const stop = () => {
      if ([...navigator.getGamepads()].some((p) => p && p.connected)) return;
      setGamepadConnected(false);
      running = false;
      cancelAnimationFrame(raf);
    };
    window.addEventListener("gamepadconnected", start);
    window.addEventListener("gamepaddisconnected", stop);
    if ([...navigator.getGamepads()].some((p) => p && p.connected)) start();
    return () => {
      window.removeEventListener("gamepadconnected", start);
      window.removeEventListener("gamepaddisconnected", stop);
      cancelAnimationFrame(raf);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [setMode, setGamepadConnected]);

  // ---- `?input=gamepad|keyboard`: focus the first item in content --------
  useEffect(() => {
    const mode = document.documentElement.dataset.input;
    if (document.documentElement.dataset.inputForced !== "1") return;
    if (mode !== "gamepad" && mode !== "keyboard") return;
    const id = window.setTimeout(() => {
      if (active()) return;
      const el = initialFocusTarget();
      if (el) focusElement(el, false);
    }, 60);
    return () => window.clearTimeout(id);
  }, []);

  return null;
}
