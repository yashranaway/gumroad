import { usePage } from "@inertiajs/react";
import * as React from "react";

import { Thumbnail } from "$app/data/thumbnails";
import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";
import { Taxonomy } from "$app/utils/discover";

import { ShareTab as ShareTabContent } from "$app/components/BundleEdit/ShareTab";
import { Bundle, BundleEditContext } from "$app/components/BundleEdit/state";
import { ProfileSection } from "$app/components/ProductEdit/state";

type Props = {
  bundle: Bundle;
  id: string;
  unique_permalink: string;
  currency_type: CurrencyCode;
  thumbnail: Thumbnail | null;
  sales_count_for_inventory: number;
  ratings: RatingsWithPercentages;
  taxonomies: Taxonomy[];
  profile_sections: ProfileSection[];
  is_bundle: boolean;
};

export default function ShareTab() {
  const {
    bundle: initialBundle,
    id,
    unique_permalink,
    currency_type,
    thumbnail,
    sales_count_for_inventory,
    ratings,
    taxonomies,
    profile_sections,
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

  const contextValue = React.useMemo(
    () => ({
      bundle,
      updateBundle,
      id,
      uniquePermalink: unique_permalink,
      currencyType: currency_type,
      thumbnail,
      salesCountForInventory: sales_count_for_inventory,
      ratings,
      taxonomies,
      profileSections: profile_sections,
      refundPolicies: [],
      productsCount: 0,
      hasOutdatedPurchases: false,
      seller_refund_policy_enabled: false,
      seller_refund_policy: { title: "", fine_print: "" },
    }),
    [
      bundle,
      updateBundle,
      id,
      unique_permalink,
      currency_type,
      thumbnail,
      sales_count_for_inventory,
      ratings,
      taxonomies,
      profile_sections,
    ],
  );

  return (
    <BundleEditContext.Provider value={contextValue}>
      <ShareTabContent />
    </BundleEditContext.Provider>
  );
}
