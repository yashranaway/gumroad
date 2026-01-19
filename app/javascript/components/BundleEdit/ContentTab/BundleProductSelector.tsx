import * as React from "react";

import { CardProduct } from "$app/parsers/product";

import {
  CartItem,
  CartItemEnd,
  CartItemMain,
  CartItemMedia,
  CartItemTitle,
  CartItemFooter,
} from "$app/components/CartItemList";
import { Thumbnail } from "$app/components/Product/Thumbnail";

type BundleProduct = CardProduct & {
  is_quantity_enabled: boolean;
  quantity: number;
  variants: {
    selected_id: string;
    list: {
      id: string;
      name: string;
      description: string;
      price_difference: number;
    }[];
  } | null;
};

export const BundleProductSelector = ({
  bundleProduct,
  selected,
  onToggle,
}: {
  bundleProduct: BundleProduct;
  selected?: boolean;
  onToggle: () => void;
}) => (
  <CartItem>
    <CartItemMedia className="sm:w-24">
      <Thumbnail url={bundleProduct.thumbnail_url} nativeType={bundleProduct.native_type} className="size-full" />
    </CartItemMedia>
    <CartItemMain>
      <CartItemTitle>{bundleProduct.name}</CartItemTitle>
      {bundleProduct.variants ? (
        <CartItemFooter>
          {bundleProduct.variants.list.length} {bundleProduct.variants.list.length === 1 ? "version" : "versions"}{" "}
          available
        </CartItemFooter>
      ) : null}
    </CartItemMain>
    <CartItemEnd className="justify-center">
      <input type="checkbox" aria-label={bundleProduct.name} checked={!!selected} onChange={onToggle} />
    </CartItemEnd>
  </CartItem>
);
