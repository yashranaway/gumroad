import * as React from "react";
import { is } from "ts-safe-cast";

import Mobile from "$app/utils/mobile";

import { useRefToLatest } from "./useRefToLatest";

export const useReactNativeMessage = <T extends Record<string, unknown>>(handler: (data: T) => void) => {
  const handlerRef = useRefToLatest(handler);

  React.useEffect(() => {
    if (!window.ReactNativeWebView) return;
    const target = Mobile.isOnAndroidDevice() ? document : window;
    const listener = (event: MessageEvent) => {
      if (typeof event.data !== "string" || !event.data.startsWith("{")) return;
      let data: unknown;
      try {
        data = JSON.parse(event.data);
      } catch {
        return;
      }
      if (is<T>(data)) {
        handlerRef.current(data);
      }
    };
    // @ts-expect-error - React Native sends message events to Android webviews via the document object, not window
    target.addEventListener("message", listener);
    // @ts-expect-error - React Native sends message events to Android webviews via the document object, not window
    return () => target.removeEventListener("message", listener);
  }, []);
};
