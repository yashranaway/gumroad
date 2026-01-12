import * as React from "react";
import { cast } from "ts-safe-cast";

import { OtherRefundPolicy } from "$app/data/products/other_refund_policies";
import { Thumbnail } from "$app/data/thumbnails";
import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";

import { BundleEditPage } from "$app/components/BundleEdit/BundleEditPage";
import { ProductTab } from "$app/components/BundleEdit/ProductTab";
import { RefundPolicy } from "$app/components/ProductEdit/RefundPolicy";

type ProductTabProps = {
  currency_type: CurrencyCode;
  thumbnail: Thumbnail | null;
  sales_count_for_inventory: number;
  ratings: RatingsWithPercentages;
  refund_policies: OtherRefundPolicy[];
  seller_refund_policy_enabled: boolean;
  seller_refund_policy: Pick<RefundPolicy, "title" | "fine_print">;
};

export default function BundlesProductEdit() {
  return (
    <BundleEditPage<ProductTabProps>
      extractTabProps={(props) => {
        const {
          currency_type,
          thumbnail,
          sales_count_for_inventory,
          ratings,
          refund_policies,
          seller_refund_policy_enabled,
          seller_refund_policy,
        } = cast<ProductTabProps>(props);
        return {
          currencyType: currency_type,
          thumbnail,
          salesCountForInventory: sales_count_for_inventory,
          ratings,
          refundPolicies: refund_policies,
          seller_refund_policy_enabled,
          seller_refund_policy,
        };
      }}
    >
      <ProductTab />
    </BundleEditPage>
  );
}
