import { router, usePage } from "@inertiajs/react";
import * as React from "react";
import { cast } from "ts-safe-cast";

import { BundleContentUpdatedStatus } from "$app/components/BundleEdit/ContentTab/BundleContentUpdatedStatus";
import { BundleProductItem } from "$app/components/BundleEdit/ContentTab/BundleProductItem";
import { BundleProductSelector } from "$app/components/BundleEdit/ContentTab/BundleProductSelector";
import { Layout } from "$app/components/BundleEdit/Layout";
import { BundleProduct, useBundleEditContext } from "$app/components/BundleEdit/state";
import { useBundleFormSubmission } from "$app/components/BundleEdit/useBundleFormSubmission";
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

type PageProps = {
  search_products?: BundleProduct[];
  search_has_more?: boolean;
  search_page?: number;
};

export const ContentTab = () => {
  const {
    bundle,
    updateBundle,
    id,
    productsCount,
    hasOutdatedPurchases,
    searchProducts: initialSearchProducts,
    searchHasMore: initialSearchHasMore,
  } = useBundleEditContext();
  const pageProps = cast<PageProps>(usePage().props);

  const results = pageProps.search_products || initialSearchProducts || [];
  const hasMoreResults = pageProps.search_has_more ?? initialSearchHasMore ?? false;
  const currentPage = pageProps.search_page ?? 1;
  const [isLoading, setIsLoading] = React.useState(false);
  const [query, setQuery] = React.useState("");

  const lastProcessedResultsRef = React.useRef<string>("");
  React.useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get("all") === "true" && results.length > 0) {
      const resultsKey = results
        .map((p) => p.id)
        .sort()
        .join(",");
      if (lastProcessedResultsRef.current !== resultsKey) {
        lastProcessedResultsRef.current = resultsKey;
        const currentProductIds = new Set(bundle.products.map((p) => p.id));
        const newProductIds = new Set(results.map((p) => p.id));
        const areEqual =
          currentProductIds.size === newProductIds.size && [...currentProductIds].every((id) => newProductIds.has(id));
        if (!areEqual) {
          updateBundle({ products: results });
        }
      }
    } else if (urlParams.get("all") !== "true") {
      lastProcessedResultsRef.current = "";
    }
  }, [results, updateBundle, bundle.products]);

  const searchProducts = React.useCallback(
    (options: {
      query?: string;
      page?: number;
      all?: boolean;
      only?: string[];
      reset?: string[];
      preserveUrl?: boolean;
    }) => {
      const data: { query?: string; page?: number; all?: boolean } = {};
      if (options.query !== undefined) {
        if (options.query) {
          data.query = options.query;
        }
      }
      if (options.page !== undefined) {
        data.page = options.page;
      }
      if (options.all !== undefined) {
        data.all = options.all;
      }

      router.reload({
        data,
        only: options.only ?? ["search_products", "search_has_more"],
        ...(options.reset && { reset: options.reset }),
        ...(options.preserveUrl && { preserveUrl: options.preserveUrl }),
        onStart: () => setIsLoading(true),
        onFinish: () => setIsLoading(false),
      });
    },
    [],
  );

  const debouncedSearch = useDebouncedCallback((searchQuery: string) => {
    searchProducts({
      query: searchQuery,
      reset: ["search_products"],
    });
  }, 300);

  useOnChange(() => debouncedSearch(query), [query]);

  const loadMore = () => {
    if (!hasMoreResults || isLoading) return;
    searchProducts({
      query,
      page: currentPage + 1,
      only: ["search_products", "search_has_more", "search_page"],
      preserveUrl: true,
    });
  };

  const loadAll = () => {
    searchProducts({
      query,
      all: true,
      reset: ["search_products"],
    });
  };

  const formRef = React.useRef<HTMLFormElement>(null);
    useOnScrollToBottom(
      formRef,
      () => {
        if (!isLoading) loadMore();
      },
      30,
    );

  const [isSelecting, setIsSelecting] = React.useState(bundle.products.length > 0);

  const transformContentData = React.useCallback(
    () => ({
      products: bundle.products.map((bundleProduct, idx) => ({
        product_id: bundleProduct.id,
        variant_id: bundleProduct.variants?.selected_id,
        quantity: bundleProduct.quantity,
        position: idx,
      })),
    }),
    [bundle.products],
  );

  const { submit: submitForm, isProcessing } = useBundleFormSubmission({
    url: Routes.edit_content_bundle_path(id),
    transform: transformContentData,
  });

  return (
    <Layout
      preview={
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
      }
      onSave={submitForm}
      isProcessing={isProcessing}
    >
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
                    onChange={(evt) => {
                      if (evt.target.checked) {
                        loadAll();
                      } else {
                        updateBundle({ products: [] });
                      }
                    }}
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
              <div
                className="grid gap-4 rounded-sm border border-border bg-background p-4"
                aria-label="Product selector"
              >
                <div className="input">
                  <Icon name="solid-search" />
                  <input
                    type="text"
                    value={query}
                    onChange={(evt) => setQuery(evt.target.value)}
                    placeholder="Search products"
                  />
                </div>
                {isLoading && results.length === 0 ? (
                  <div style={{ justifySelf: "center" }}>
                    <LoadingSpinner />
                  </div>
                ) : results.length > 0 ? (
                  <CartItemList>
                    {results.map((bundleProduct) => {
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
    </Layout>
  );
};
