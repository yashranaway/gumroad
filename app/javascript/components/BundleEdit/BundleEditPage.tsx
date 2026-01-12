import { usePage } from "@inertiajs/react";
import * as React from "react";
import { cast } from "ts-safe-cast";

import { Bundle, BundleEditContext } from "$app/components/BundleEdit/state";
import { showAlert } from "$app/components/server-components/Alert";
import { useRunOnce } from "$app/components/useRunOnce";

type SharedProps = {
  bundle: Bundle;
  id: string;
  unique_permalink: string;
  is_bundle: boolean;
};

type BundleEditPageProps<T extends Record<string, unknown> = Record<string, never>> = SharedProps & T;

type BundleEditContextValue = React.ComponentProps<typeof BundleEditContext.Provider>["value"];

export function BundleEditPage<T extends Record<string, unknown> = Record<string, never>>({
  children,
  extractTabProps,
}: {
  children: React.ReactNode;
  extractTabProps?: (props: BundleEditPageProps<T>) => Partial<BundleEditContextValue>;
}) {
  const pageProps = cast<BundleEditPageProps<T>>(usePage().props);
  const { bundle: initialBundle, id, unique_permalink, is_bundle } = pageProps;

  const [bundle, setBundle] = React.useState(initialBundle);

  const updateBundle = React.useCallback((update: Partial<Bundle> | ((bundle: Bundle) => void)) => {
    setBundle((prevBundle) => {
      const updated = { ...prevBundle };
      if (typeof update === "function") update(updated);
      else Object.assign(updated, update);
      return updated;
    });
  }, []);

  useRunOnce(() => {
    if (!is_bundle)
      showAlert("Select products and save your changes to finish converting this product to a bundle.", "warning");
  });

  const contextValue: BundleEditContextValue = React.useMemo(() => {
    const baseValue = {
      bundle,
      updateBundle,
      id,
      uniquePermalink: unique_permalink,
    };
    const tabProps = extractTabProps?.(pageProps) || {};
    return { ...baseValue, ...tabProps };
  }, [bundle, updateBundle, id, unique_permalink, pageProps, extractTabProps]);

  return <BundleEditContext.Provider value={contextValue}>{children}</BundleEditContext.Provider>;
}
