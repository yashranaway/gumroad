import * as React from "react";

import { OtherRefundPolicy } from "$app/data/products/other_refund_policies";
import { Thumbnail } from "$app/data/thumbnails";
import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";
import { Taxonomy } from "$app/utils/discover";

import { ContentTab } from "$app/components/BundleEdit/ContentTab";
import { ProductTab } from "$app/components/BundleEdit/ProductTab";
import { ShareTab } from "$app/components/BundleEdit/ShareTab";
import { Bundle, BundleEditContext, BundleProduct } from "$app/components/BundleEdit/state";
import { RefundPolicy } from "$app/components/ProductEdit/RefundPolicy";
import { ProfileSection } from "$app/components/ProductEdit/state";
import { showAlert } from "$app/components/server-components/Alert";
import { useRunOnce } from "$app/components/useRunOnce";

type Tab = "product" | "content" | "share";

export type BundleEditPageProps = {
  bundle: Bundle;
  id: string;
  unique_permalink: string;
  currency_type: CurrencyCode;
  thumbnail: Thumbnail | null;
  sales_count_for_inventory: number;
  ratings: RatingsWithPercentages;
  taxonomies: Taxonomy[];
  profile_sections: ProfileSection[];
  refund_policies: OtherRefundPolicy[];
  products_count: number;
  is_bundle: boolean;
  has_outdated_purchases: boolean;
  seller_refund_policy_enabled: boolean;
  seller_refund_policy: Pick<RefundPolicy, "title" | "fine_print">;
  search_products?: BundleProduct[];
  search_has_more?: boolean;
};

export const BundleEditPage = ({
  bundle: initialBundle,
  id,
  unique_permalink,
  currency_type,
  thumbnail,
  sales_count_for_inventory,
  ratings,
  taxonomies,
  profile_sections,
  refund_policies,
  products_count,
  is_bundle,
  has_outdated_purchases,
  seller_refund_policy_enabled,
  seller_refund_policy,
  search_products: initialSearchProducts,
  search_has_more: initialSearchHasMore,
}: BundleEditPageProps) => {
  const [bundle, setBundle] = React.useState(initialBundle);
  const [activeTab, setActiveTab] = React.useState<Tab>("product");

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
      refundPolicies: refund_policies,
      productsCount: products_count,
      hasOutdatedPurchases: has_outdated_purchases,
      seller_refund_policy_enabled,
      seller_refund_policy,
      activeTab,
      setActiveTab,
      ...(initialSearchProducts !== undefined ? { searchProducts: initialSearchProducts } : {}),
      ...(initialSearchHasMore !== undefined ? { searchHasMore: initialSearchHasMore } : {}),
    }),
    [bundle, initialSearchProducts, initialSearchHasMore, activeTab],
  );

  const renderTab = () => {
    switch (activeTab) {
      case "product":
        return <ProductTab />;
      case "content":
        return <ContentTab />;
      case "share":
        return <ShareTab />;
      default:
        return <ProductTab />;
    }
  };

  return (
    <BundleEditContext.Provider value={contextValue}>
      {renderTab()}
    </BundleEditContext.Provider>
  );
};
