import { usePage } from "@inertiajs/react";
import * as React from "react";

import { OtherRefundPolicy } from "$app/data/products/other_refund_policies";
import { Thumbnail } from "$app/data/thumbnails";
import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";
import { Taxonomy } from "$app/utils/discover";

import { Layout } from "$app/components/BundleEdit/Layout";
import { ProductPreview } from "$app/components/BundleEdit/ProductPreview";
import { ProductTab as ProductTabContent } from "$app/components/BundleEdit/ProductTab";
import { Bundle, BundleEditContext } from "$app/components/BundleEdit/state";
import { useBundleForm } from "$app/components/BundleEdit/useBundleForm";
import { RefundPolicy } from "$app/components/ProductEdit/RefundPolicy";
import { showAlert } from "$app/components/server-components/Alert";
import { useRunOnce } from "$app/components/useRunOnce";

const defaultRatings: RatingsWithPercentages = { average: 0, count: 0, percentages: [0, 0, 0, 0, 0] };

type Props = {
  tab: "product" | "content" | "share";
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

export default function ProductEdit() {
  const {
    tab,
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

  const { bundle, updateBundle, form, isPublishing, handleSave, handlePublish, handleUnpublish } = useBundleForm({
    initialBundle,
    uniquePermalink: unique_permalink,
    savePath: Routes.bundle_product_path(id),
    publishRedirectPath: Routes.edit_bundle_share_path(id),
  });

  const [showRefundPolicyPreview, setShowRefundPolicyPreview] = React.useState(false);
  const [isUploading, setIsUploading] = React.useState(false);

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
      <Layout
        tab={tab}
        preview={<ProductPreview showRefundPolicyModal={showRefundPolicyPreview} />}
        onSave={handleSave}
        onPublish={handlePublish}
        onUnpublish={handleUnpublish}
        isSaving={form.processing}
        isPublishing={isPublishing}
        isLoading={isUploading}
      >
        <ProductTabContent setShowRefundPolicyPreview={setShowRefundPolicyPreview} setIsUploading={setIsUploading} />
      </Layout>
    </BundleEditContext.Provider>
  );
}
