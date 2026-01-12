import { usePage } from "@inertiajs/react";
import * as React from "react";

import { Thumbnail } from "$app/data/thumbnails";
import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";
import { Taxonomy } from "$app/utils/discover";

import { Layout } from "$app/components/BundleEdit/Layout";
import { ProductPreview } from "$app/components/BundleEdit/ProductPreview";
import { ShareTab as ShareTabContent } from "$app/components/BundleEdit/ShareTab";
import { Bundle, BundleEditContext } from "$app/components/BundleEdit/state";
import { useBundleForm } from "$app/components/BundleEdit/useBundleForm";
import { ProfileSection } from "$app/components/ProductEdit/state";

type Props = {
  tab: "product" | "content" | "share";
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

export default function ShareEdit() {
  const {
    tab,
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

  const { bundle, updateBundle, form, isPublishing, handleSave, handlePublish, handleUnpublish } = useBundleForm({
    initialBundle,
    uniquePermalink: unique_permalink,
    savePath: Routes.bundle_share_path(id),
    unpublishRedirectPath: Routes.edit_bundle_content_path(id),
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
      <Layout
        tab={tab}
        preview={<ProductPreview />}
        onSave={handleSave}
        onPublish={handlePublish}
        onUnpublish={handleUnpublish}
        isSaving={form.processing}
        isPublishing={isPublishing}
      >
        <ShareTabContent />
      </Layout>
    </BundleEditContext.Provider>
  );
}
