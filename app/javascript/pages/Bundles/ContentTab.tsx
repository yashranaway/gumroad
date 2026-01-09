import { usePage } from "@inertiajs/react";
import * as React from "react";

import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";

import { ContentTab as ContentTabContent } from "$app/components/BundleEdit/ContentTab";
import { Bundle, BundleEditContext, BundleProduct } from "$app/components/BundleEdit/state";
import { showAlert } from "$app/components/server-components/Alert";
import { useRunOnce } from "$app/components/useRunOnce";

const defaultRatings: RatingsWithPercentages = { average: 0, count: 0, percentages: [0, 0, 0, 0, 0] };

type Props = {
  bundle: Bundle;
  id: string;
  unique_permalink: string;
  currency_type: CurrencyCode;
  products_count: number;
  has_outdated_purchases: boolean;
  is_bundle: boolean;
  search_products?: BundleProduct[];
  search_has_more?: boolean;
};

export default function ContentTab() {
  const {
    bundle: initialBundle,
    id,
    unique_permalink,
    currency_type,
    products_count,
    has_outdated_purchases,
    is_bundle,
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
      thumbnail: null,
      salesCountForInventory: 0,
      ratings: defaultRatings,
      taxonomies: [],
      profileSections: [],
      refundPolicies: [],
      productsCount: products_count,
      hasOutdatedPurchases: has_outdated_purchases,
      seller_refund_policy_enabled: false,
      seller_refund_policy: { title: "", fine_print: "" },
    }),
    [bundle, updateBundle, id, unique_permalink, currency_type, products_count, has_outdated_purchases],
  );

  return (
    <BundleEditContext.Provider value={contextValue}>
      <ContentTabContent />
    </BundleEditContext.Provider>
  );
}
