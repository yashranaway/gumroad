import { usePage } from "@inertiajs/react";
import * as React from "react";

import { OtherRefundPolicy } from "$app/data/products/other_refund_policies";
import { Thumbnail } from "$app/data/thumbnails";
import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";
import { Taxonomy } from "$app/utils/discover";

import { ProductTab as ProductTabContent } from "$app/components/BundleEdit/ProductTab";
import { Bundle, BundleEditContext } from "$app/components/BundleEdit/state";
import { RefundPolicy } from "$app/components/ProductEdit/RefundPolicy";
import { showAlert } from "$app/components/server-components/Alert";
import { useRunOnce } from "$app/components/useRunOnce";

const defaultRatings: RatingsWithPercentages = { average: 0, count: 0, percentages: [0, 0, 0, 0, 0] };

type Props = {
  bundle: Bundle;
  id: string;
  unique_permalink: string;
  currency_type: CurrencyCode;
  thumbnail: Thumbnail | null;
  taxonomies: Taxonomy[];
  refund_policies: OtherRefundPolicy[];
  is_bundle: boolean;
  seller_refund_policy_enabled: boolean;
  seller_refund_policy: Pick<RefundPolicy, "title" | "fine_print">;
};

export default function ProductTab() {
  const {
    bundle: initialBundle,
    id,
    unique_permalink,
    currency_type,
    thumbnail,
    taxonomies,
    refund_policies,
    is_bundle,
    seller_refund_policy_enabled,
    seller_refund_policy,
  } = usePage<Props>().props;

  const [bundle, setBundle] = React.useState(initialBundle);
  const updateBundle = React.useCallback(
    (update: Partial<Bundle> | ((bundle: Bundle) => void)) =>
      setBundle((prevBundle) => {
        const updated = { ...prevBundle };
        if (typeof update === "function") update(updated);
        else Object.assign(updated, update);
        return updated;
      }),
    [],
  );

  useRunOnce(() => {
    if (!is_bundle)
      showAlert("Select products and save your changes to finish converting this product to a bundle.", "warning");
  });

  const contextValue = React.useMemo(
    () => ({
      bundle,
      updateBundle,
      id,
      uniquePermalink: unique_permalink,
      currencyType: currency_type,
      thumbnail,
      salesCountForInventory: 0,
      ratings: defaultRatings,
      taxonomies,
      profileSections: [],
      refundPolicies: refund_policies,
      productsCount: 0,
      hasOutdatedPurchases: false,
      seller_refund_policy_enabled,
      seller_refund_policy,
    }),
    [
      bundle,
      updateBundle,
      id,
      unique_permalink,
      currency_type,
      thumbnail,
      taxonomies,
      refund_policies,
      seller_refund_policy_enabled,
      seller_refund_policy,
    ],
  );

  return (
    <BundleEditContext.Provider value={contextValue}>
      <ProductTabContent />
    </BundleEditContext.Provider>
  );
}
