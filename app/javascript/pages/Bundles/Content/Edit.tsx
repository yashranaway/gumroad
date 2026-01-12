import { Deferred, usePage } from "@inertiajs/react";
import * as React from "react";

import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";

import { ContentTab as ContentTabContent, ContentTabPreview } from "$app/components/BundleEdit/ContentTab";
import { Layout } from "$app/components/BundleEdit/Layout";
import { Bundle, BundleEditContext, BundleProduct } from "$app/components/BundleEdit/state";
import { useBundleForm } from "$app/components/BundleEdit/useBundleForm";
import { LoadingSpinner } from "$app/components/LoadingSpinner";
import { showAlert } from "$app/components/server-components/Alert";
import { useRunOnce } from "$app/components/useRunOnce";

const defaultRatings: RatingsWithPercentages = { average: 0, count: 0, percentages: [0, 0, 0, 0, 0] };

type Props = {
  tab: "product" | "content" | "share";
  bundle: Bundle;
  id: string;
  unique_permalink: string;
  currency_type: CurrencyCode;
  products_count: number;
  has_outdated_purchases: boolean;
  is_bundle: boolean;
  search_products?: BundleProduct[];
  search_has_more?: boolean;
  search_query: string;
  search_page: number;
};

export default function ContentEdit() {
  const {
    tab,
    bundle: initialBundle,
    id,
    unique_permalink,
    currency_type,
    products_count,
    has_outdated_purchases,
    is_bundle,
    search_products,
    search_has_more,
    search_query,
    search_page,
  } = usePage<Props>().props;

  const { bundle, updateBundle, form, isPublishing, handleSave, handlePublish, handleUnpublish } = useBundleForm({
    initialBundle,
    uniquePermalink: unique_permalink,
    savePath: Routes.bundle_content_path(id),
    publishRedirectPath: Routes.edit_bundle_share_path(id),
  });

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
      <Layout
        tab={tab}
        preview={<ContentTabPreview />}
        onSave={handleSave}
        onPublish={handlePublish}
        onUnpublish={handleUnpublish}
        isSaving={form.processing}
        isPublishing={isPublishing}
      >
        <Deferred
          data={["search_products", "search_has_more"]}
          fallback={
            <div className="flex justify-center p-8">
              <LoadingSpinner />
            </div>
          }
        >
          <ContentTabContent
            searchProducts={search_products ?? []}
            searchHasMore={search_has_more ?? true}
            searchQuery={search_query}
            searchPage={search_page}
          />
        </Deferred>
      </Layout>
    </BundleEditContext.Provider>
  );
}
