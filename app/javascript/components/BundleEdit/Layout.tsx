import { Link, router } from "@inertiajs/react";
import * as React from "react";

import { setProductPublished } from "$app/data/publish_product";
import { asyncVoid } from "$app/utils/promise";
import { assertResponseError, request } from "$app/utils/request";

import { Bundle, useBundleEditContext } from "$app/components/BundleEdit/state";
import { Button } from "$app/components/Button";
import { CopyToClipboard } from "$app/components/CopyToClipboard";
import { useCurrentSeller } from "$app/components/CurrentSeller";
import { useDomains } from "$app/components/DomainSettings";
import { Icon } from "$app/components/Icons";
import { Preview } from "$app/components/Preview";
import { PreviewSidebar, WithPreviewSidebar } from "$app/components/PreviewSidebar";
import { showAlert } from "$app/components/server-components/Alert";
import { PageHeader } from "$app/components/ui/PageHeader";
import { Tabs, Tab } from "$app/components/ui/Tabs";
import { useIsAboveBreakpoint } from "$app/components/useIsAboveBreakpoint";
import { WithTooltip } from "$app/components/WithTooltip";

export const useProductUrl = (params = {}) => {
  const { bundle, uniquePermalink } = useBundleEditContext();
  const currentSeller = useCurrentSeller();
  const { appDomain } = useDomains();
  return Routes.short_link_url(bundle.custom_permalink ?? uniquePermalink, {
    host: currentSeller?.subdomain ?? appDomain,
    ...params,
  });
};

const useCurrentTab = () => {
  const [tab, setTab] = React.useState<"product" | "content" | "share">("product");

  React.useEffect(() => {
    const path = window.location.pathname;
    if (path.includes("/edit/share")) {
      setTab("share");
    } else if (path.includes("/edit/content")) {
      setTab("content");
    } else {
      setTab("product");
    }
  }, []);

  return tab;
};

const transformBundleForSubmission = (bundle: Bundle) => ({
  name: bundle.name,
  description: bundle.description,
  custom_permalink: bundle.custom_permalink,
  price_cents: bundle.price_cents,
  customizable_price: bundle.customizable_price,
  suggested_price_cents: bundle.suggested_price_cents,
  custom_button_text_option: bundle.custom_button_text_option,
  custom_summary: bundle.custom_summary,
  custom_attributes: bundle.custom_attributes,
  max_purchase_count: bundle.max_purchase_count,
  quantity_enabled: bundle.quantity_enabled,
  should_show_sales_count: bundle.should_show_sales_count,
  is_epublication: bundle.is_epublication,
  product_refund_policy_enabled: bundle.product_refund_policy_enabled,
  refund_policy: bundle.refund_policy,
  taxonomy_id: bundle.taxonomy_id,
  tags: bundle.tags,
  display_product_reviews: bundle.display_product_reviews,
  is_adult: bundle.is_adult,
  discover_fee_per_thousand: bundle.discover_fee_per_thousand,
  section_ids: bundle.section_ids,
  covers: bundle.covers.map(({ id }) => id),
  allow_installment_plan: bundle.allow_installment_plan,
  installment_plan: bundle.installment_plan,
  products: bundle.products.map((p, idx) => ({
    product_id: p.id,
    variant_id: p.variants?.selected_id,
    quantity: p.quantity,
    position: idx,
  })),
});

export const Layout = ({
  children,
  preview,
  isLoading = false,
}: {
  children: React.ReactNode;
  preview: React.ReactNode;
  isLoading?: boolean;
}) => {
  const { bundle, updateBundle, id, uniquePermalink } = useBundleEditContext();

  const url = useProductUrl();
  const tab = useCurrentTab();

  const isDesktop = useIsAboveBreakpoint("lg");

  const [isSaving, setIsSaving] = React.useState(false);
  const handleSave = async () => {
    try {
      setIsSaving(true);
      await request({
        method: "PATCH",
        url: Routes.bundle_path(id),
        data: transformBundleForSubmission(bundle),
        accept: "json",
      });
      showAlert("Changes saved!", "success");
    } catch (e) {
      assertResponseError(e);
      showAlert(e.message, "error");
    }
    setIsSaving(false);
  };

  const [isPublishing, setIsPublishing] = React.useState(false);
  const setPublished = async (published: boolean) => {
    try {
      setIsPublishing(true);
      await request({
        method: "PATCH",
        url: Routes.bundle_path(id),
        data: transformBundleForSubmission(bundle),
        accept: "json",
      });
      await setProductPublished(uniquePermalink, published);
      updateBundle({ is_published: published });
      showAlert(published ? "Published!" : "Unpublished!", "success");
      if (tab === "share") router.visit(Routes.edit_content_bundle_path(id));
      else if (published) router.visit(Routes.edit_share_bundle_path(id));
    } catch (e) {
      assertResponseError(e);
      showAlert(e.message, "error");
    }
    setIsPublishing(false);
  };

  const isUploadingFiles = bundle.public_files.some(
    (f) => f.status?.type === "unsaved" && f.status.uploadStatus.type === "uploading",
  );
  const isUploadingFilesOrImages = isLoading || isUploadingFiles;
  const isBusy = isUploadingFilesOrImages || isSaving || isPublishing;
  const saveButtonTooltip = isUploadingFiles
    ? "Files are still uploading..."
    : isUploadingFilesOrImages
      ? "Images are still uploading..."
      : isBusy
        ? "Please wait..."
        : undefined;

  const saveButton = (
    <WithTooltip tip={saveButtonTooltip}>
      <Button color="primary" disabled={isBusy} onClick={asyncVoid(handleSave)}>
        {isSaving ? "Saving changes..." : "Save changes"}
      </Button>
    </WithTooltip>
  );

  const onTabClick = (e: React.MouseEvent, callback?: () => void) => {
    const message = isUploadingFiles
      ? "Some files are still uploading, please wait..."
      : isUploadingFilesOrImages
        ? "Some images are still uploading, please wait..."
        : undefined;

    if (message) {
      e.preventDefault();
      showAlert(message, "warning");
      return;
    }

    callback?.();
  };

  return (
    <>
      <PageHeader
        className="sticky-top"
        title={bundle.name || "Untitled"}
        actions={
          bundle.is_published ? (
            <>
              <Button disabled={isBusy} onClick={() => void setPublished(false)}>
                {isPublishing ? "Unpublishing..." : "Unpublish"}
              </Button>
              {saveButton}
              <CopyToClipboard
                text={url}
                copyTooltip="Copy product URL"
                tooltipPosition={isDesktop ? "left" : "bottom"}
              >
                <Button>
                  <Icon name="link" />
                </Button>
              </CopyToClipboard>
            </>
          ) : tab === "product" ? (
            <Button
              color="primary"
              disabled={isBusy}
              onClick={() => void handleSave().then(() => router.visit(Routes.edit_content_bundle_path(id)))}
            >
              {isSaving ? "Saving changes..." : "Save and continue"}
            </Button>
          ) : (
            <>
              {saveButton}
              <WithTooltip tip={saveButtonTooltip}>
                <Button color="accent" disabled={isBusy} onClick={() => void setPublished(true)}>
                  {isPublishing ? "Publishing..." : "Publish and continue"}
                </Button>
              </WithTooltip>
            </>
          )
        }
      >
        <Tabs style={{ gridColumn: 1 }}>
          <Tab asChild isSelected={tab === "product"}>
            <Link href={Routes.edit_bundle_path(id)} onClick={onTabClick}>
              Product
            </Link>
          </Tab>
          <Tab asChild isSelected={tab === "content"}>
            <Link href={Routes.edit_content_bundle_path(id)} onClick={onTabClick}>
              Content
            </Link>
          </Tab>
          <Tab asChild isSelected={tab === "share"}>
            <Link
              href={Routes.edit_share_bundle_path(id)}
              onClick={(evt: React.MouseEvent) => {
                onTabClick(evt, () => {
                  if (!bundle.is_published) {
                    evt.preventDefault();
                    showAlert(
                      "Not yet! You've got to publish your awesome product before you can share it with your audience and the world.",
                      "warning",
                    );
                  }
                });
              }}
            >
              Share
            </Link>
          </Tab>
        </Tabs>
      </PageHeader>
      {preview ? (
        <WithPreviewSidebar className="flex-1">
          {children}
          <PreviewSidebar
            previewLink={(props) => (
              <Button {...props} onClick={() => void handleSave().then(() => window.open(url))} disabled={isBusy} />
            )}
          >
            <Preview
              scaleFactor={0.4}
              style={{
                border: "var(--border)",
                backgroundColor: "rgb(var(--filled))",
              }}
            >
              {preview}
            </Preview>
          </PreviewSidebar>
        </WithPreviewSidebar>
      ) : (
        <div className="flex-1">{children}</div>
      )}
    </>
  );
};
