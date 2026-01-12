import { router } from "@inertiajs/react";
import * as React from "react";

import { BundleContentUpdatedStatus } from "$app/components/BundleEdit/ContentTab/BundleContentUpdatedStatus";
import { BundleProductItem } from "$app/components/BundleEdit/ContentTab/BundleProductItem";
import { BundleProductSelector } from "$app/components/BundleEdit/ContentTab/BundleProductSelector";
import { BundleProduct, useBundleEditContext } from "$app/components/BundleEdit/state";
import { Button } from "$app/components/Button";
import { CartItemList } from "$app/components/CartItemList";
import { Icon } from "$app/components/Icons";
import { LoadingSpinner } from "$app/components/LoadingSpinner";
import { Card } from "$app/components/Product/Card";
import { Placeholder } from "$app/components/ui/Placeholder";
import { ProductCardGrid } from "$app/components/ui/ProductCardGrid";
import { useDebouncedCallback } from "$app/components/useDebouncedCallback";
import { useOnChange } from "$app/components/useOnChange";
import { useOnScrollToBottom } from "$app/components/useOnScrollToBottom";

export const ContentTabPreview = () => {
  const { bundle } = useBundleEditContext();

  return (
    <div>
      <header>
        <h1>Library</h1>
      </header>
      <section>
        <ProductCardGrid>
          {bundle.products.map((bundleProduct) => (
            <Card key={bundleProduct.id} product={bundleProduct} />
          ))}
        </ProductCardGrid>
      </section>
    </div>
  );
};

export type SearchData = {
  products: BundleProduct[];
  has_more: boolean;
  query: string;
  page: number;
};

type ContentTabProps = {
  searchData: SearchData;
};

export const ContentTab = ({ searchData }: ContentTabProps) => {
  const { products: searchProducts, has_more: searchHasMore, query: searchQuery, page: searchPage } = searchData;
  const { bundle, updateBundle, productsCount, hasOutdatedPurchases } = useBundleEditContext();
  const [query, setQuery] = React.useState(searchQuery);
  const [isLoadingMore, setIsLoadingMore] = React.useState(false);
  const [isSearching, setIsSearching] = React.useState(false);
  const [selectAllPending, setSelectAllPending] = React.useState(false);

  const updateSearch = useDebouncedCallback((newQuery: string) => {
    setIsSearching(true);
    router.reload({
      data: { query: newQuery || undefined, page: 1 },
      only: ["search_data"],
      preserveUrl: true,
      onFinish: () => setIsSearching(false),
    });
  }, 300);

  useOnChange(() => {
    if (query !== searchQuery) {
      updateSearch(query);
    }
  }, [query, searchQuery, updateSearch]);

  React.useEffect(() => {
    if (selectAllPending && !searchHasMore && searchProducts.length > 0) {
      updateBundle({ products: searchProducts });
      setSelectAllPending(false);
      setIsSearching(false);
    }
  }, [selectAllPending, searchHasMore, searchProducts, updateBundle]);

  const formRef = React.useRef<HTMLFormElement>(null);
  useOnScrollToBottom(
    formRef,
    () => {
      if (!isLoadingMore && searchHasMore) {
        setIsLoadingMore(true);
        router.reload({
          data: { query: query || undefined, page: searchPage + 1 },
          only: ["search_data"],
          preserveUrl: true,
          onFinish: () => setIsLoadingMore(false),
        });
      }
    },
    30,
  );

  const loadAllProducts = () => {
    setSelectAllPending(true);
    setIsSearching(true);
    router.reload({
      data: { query: query || undefined, all: "true" },
      only: ["search_data"],
      preserveUrl: true,
    });
  };

  const [isSelecting, setIsSelecting] = React.useState(bundle.products.length > 0);
  const isLoading = isSearching || isLoadingMore;

  return (
    <form onSubmit={(evt) => evt.preventDefault()} ref={formRef}>
      <section className="p-4! md:p-8!">
        {hasOutdatedPurchases ? <BundleContentUpdatedStatus /> : null}
        {isSelecting ? (
          <>
            <header
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              <h2>Products</h2>
              <label>
                <input
                  type="checkbox"
                  checked={bundle.products.length === productsCount}
                  disabled={isLoading}
                  onChange={(evt) => (evt.target.checked ? loadAllProducts() : updateBundle({ products: [] }))}
                />
                All products
              </label>
            </header>
            {bundle.products.length > 0 ? (
              <CartItemList aria-label="Bundle products">
                {bundle.products.map((bundleProduct, idx) => (
                  <BundleProductItem
                    key={bundleProduct.id}
                    bundleProduct={bundleProduct}
                    updateBundleProduct={(update) =>
                      updateBundle({
                        products: [
                          ...bundle.products.slice(0, idx),
                          { ...bundleProduct, ...update },
                          ...bundle.products.slice(idx + 1),
                        ],
                      })
                    }
                    removeBundleProduct={() =>
                      updateBundle({ products: bundle.products.filter(({ id }) => id !== bundleProduct.id) })
                    }
                  />
                ))}
              </CartItemList>
            ) : null}
            <div className="grid gap-4 rounded-sm border border-border bg-background p-4" aria-label="Product selector">
              <div className="input">
                <Icon name="solid-search" />
                <input
                  type="text"
                  value={query}
                  onChange={(evt) => setQuery(evt.target.value)}
                  placeholder="Search products"
                />
              </div>
              {isSearching && searchProducts.length === 0 ? (
                <div style={{ justifySelf: "center" }}>
                  <LoadingSpinner />
                </div>
              ) : searchProducts.length > 0 ? (
                <CartItemList>
                  {searchProducts.map((bundleProduct) => {
                    const selected = bundle.products.some(({ id }) => id === bundleProduct.id);
                    return (
                      <BundleProductSelector
                        key={bundleProduct.id}
                        bundleProduct={bundleProduct}
                        selected={selected}
                        onToggle={() =>
                          updateBundle({
                            products: selected
                              ? bundle.products.filter(({ id }) => id !== bundleProduct.id)
                              : [...bundle.products, bundleProduct],
                          })
                        }
                      />
                    );
                  })}
                </CartItemList>
              ) : (
                <div style={{ justifySelf: "center" }}>No products found</div>
              )}
              {isLoadingMore ? (
                <div style={{ justifySelf: "center" }}>
                  <LoadingSpinner />
                </div>
              ) : null}
            </div>
          </>
        ) : (
          <Placeholder>
            <h2>Select products</h2>
            <p>Choose the products you want to include in your bundle</p>
            <Button color="primary" onClick={() => setIsSelecting(true)}>
              <Icon name="plus" />
              Add products
            </Button>
          </Placeholder>
        )}
      </section>
    </form>
  );
};
