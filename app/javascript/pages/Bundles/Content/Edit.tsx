import * as React from "react";
import { cast } from "ts-safe-cast";

import { BundleEditPage } from "$app/components/BundleEdit/BundleEditPage";
import { ContentTab } from "$app/components/BundleEdit/ContentTab";

type ContentTabProps = {
  products_count: number;
  has_outdated_purchases: boolean;
};

export default function BundlesContentEdit() {
  return (
    <BundleEditPage<ContentTabProps>
      extractTabProps={(props) => {
        const { products_count, has_outdated_purchases } = cast<ContentTabProps>(props);
        return {
          productsCount: products_count,
          hasOutdatedPurchases: has_outdated_purchases,
        };
      }}
    >
      <ContentTab />
    </BundleEditPage>
  );
}
