import { usePage } from "@inertiajs/react";
import React from "react";
import { cast } from "ts-safe-cast";

import { BundleEditPage, type BundleEditPageProps } from "$app/components/BundleEditPage";

export default function BundlesEdit() {
  const props = cast<BundleEditPageProps>(usePage().props);

  return <BundleEditPage {...props} />;
}
