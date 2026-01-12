import * as React from "react";
import { cast } from "ts-safe-cast";

import { RatingsWithPercentages } from "$app/parsers/product";
import { CurrencyCode } from "$app/utils/currency";
import { Taxonomy } from "$app/utils/discover";

import { BundleEditPage } from "$app/components/BundleEdit/BundleEditPage";
import { ShareTab } from "$app/components/BundleEdit/ShareTab";
import { RefundPolicy } from "$app/components/ProductEdit/RefundPolicy";
import { ProfileSection } from "$app/components/ProductEdit/state";

type ShareTabProps = {
  taxonomies: Taxonomy[];
  profile_sections: ProfileSection[];
  currency_type: CurrencyCode;
  sales_count_for_inventory: number;
  ratings: RatingsWithPercentages;
  seller_refund_policy_enabled: boolean;
  seller_refund_policy: Pick<RefundPolicy, "title" | "fine_print">;
};

export default function BundlesShareEdit() {
  return (
    <BundleEditPage<ShareTabProps>
      extractTabProps={(props) => {
        const {
          taxonomies,
          profile_sections,
          currency_type,
          sales_count_for_inventory,
          ratings,
          seller_refund_policy_enabled,
          seller_refund_policy,
        } = cast<ShareTabProps>(props);
        return {
          taxonomies,
          profileSections: profile_sections,
          currencyType: currency_type,
          salesCountForInventory: sales_count_for_inventory,
          ratings,
          seller_refund_policy_enabled,
          seller_refund_policy,
        };
      }}
    >
      <ShareTab />
    </BundleEditPage>
  );
}
