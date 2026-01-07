import { useForm } from "@inertiajs/react";
import * as React from "react";

import { setProductPublished } from "$app/data/publish_product";

import { useBundleEditContext } from "$app/components/BundleEdit/state";
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

export const Layout = ({
  children,
  preview,
  isLoading = false,
}: {
  children: React.ReactNode;
  preview: React.ReactNode;
  isLoading?: boolean;
}) => {
  const { bundle, updateBundle, id, uniquePermalink, activeTab, setActiveTab } = useBundleEditContext();

  const url = useProductUrl();

  const isDesktop = useIsAboveBreakpoint("lg");

  const form = useForm({});

  // Helper to transform bundle data for form submission
  const transformBundleData = () => {
    form.transform(() => ({
      ...bundle,
      covers: bundle.covers.map(({ id }) => id),
      products: bundle.products.map((bundleProduct, idx) => ({
        product_id: bundleProduct.id,
        variant_id: bundleProduct.variants?.selected_id,
        quantity: bundleProduct.quantity,
        position: idx,
      })),
      installment_plan: bundle.allow_installment_plan ? bundle.installment_plan : undefined,
    }));
  };

  // Helper to save bundle with custom success callback
  const saveBundle = (onSuccess?: () => void | Promise<void>) => {
    transformBundleData();
    form.put(Routes.bundle_path(id), {
      preserveScroll: true,
      onSuccess: () => {
        showAlert("Changes saved!", "success");
        void onSuccess?.();
      },
      onError: (errors) => {
        const errorMessage = Object.values(errors)[0] || "An error occurred";
        showAlert(errorMessage, "error");
      },
    });
  };

  const handleSave = () => {
    saveBundle();
  };

  const setPublished = (published: boolean) => {
    saveBundle(async () => {
      await setProductPublished(uniquePermalink, published);
      updateBundle({ is_published: published });
      showAlert(published ? "Published!" : "Unpublished!", "success");
      if (activeTab === "share") setActiveTab("content");
      else if (published) setActiveTab("share");
    });
  };

  const isUploadingFiles = bundle.public_files.some(
    (f) => f.status?.type === "unsaved" && f.status.uploadStatus.type === "uploading",
  );
  const isUploadingFilesOrImages = isLoading || isUploadingFiles;
  const isBusy = isUploadingFilesOrImages || form.processing;
  const saveButtonTooltip = isUploadingFiles
    ? "Files are still uploading..."
    : isUploadingFilesOrImages
      ? "Images are still uploading..."
      : isBusy
      ? "Please wait..."
      : undefined;

  const saveButton = (
    <WithTooltip tip={saveButtonTooltip}>
      <Button color="primary" disabled={isBusy} onClick={handleSave}>
        {form.processing ? "Saving changes..." : "Save changes"}
      </Button>
    </WithTooltip>
  );

  const onTabClick = (tab: "product" | "content" | "share", callback?: () => void) => {
    const message = isUploadingFiles
      ? "Some files are still uploading, please wait..."
      : isUploadingFilesOrImages
        ? "Some images are still uploading, please wait..."
        : undefined;

    if (message) {
      showAlert(message, "warning");
      return;
    }

    setActiveTab(tab);
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
              <Button disabled={isBusy} onClick={() => setPublished(false)}>
                {form.processing ? "Unpublishing..." : "Unpublish"}
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
          ) : activeTab === "product" ? (
            <Button
              color="primary"
              disabled={isBusy}
              onClick={() => saveBundle(() => setActiveTab("content"))}
            >
              {form.processing ? "Saving changes..." : "Save and continue"}
            </Button>
          ) : (
            <>
              {saveButton}
              <WithTooltip tip={saveButtonTooltip}>
                <Button color="accent" disabled={isBusy} onClick={() => setPublished(true)}>
                  {form.processing ? "Publishing..." : "Publish and continue"}
                </Button>
              </WithTooltip>
            </>
          )
        }
      >
        <Tabs style={{ gridColumn: 1 }}>
          <Tab
            isSelected={activeTab === "product"}
            onClick={(e) => {
              e.preventDefault();
              onTabClick("product");
            }}
            href="#"
          >
            Product
          </Tab>
          <Tab
            isSelected={activeTab === "content"}
            onClick={(e) => {
              e.preventDefault();
              onTabClick("content");
            }}
            href="#"
          >
            Content
          </Tab>
          <Tab
            isSelected={activeTab === "share"}
            onClick={(e) => {
              e.preventDefault();
              onTabClick("share", () => {
                if (!bundle.is_published) {
                  showAlert(
                    "Not yet! You've got to publish your awesome product before you can share it with your audience and the world.",
                    "warning",
                  );
                }
              });
            }}
            href="#"
          >
            Share
          </Tab>
        </Tabs>
      </PageHeader>
      {preview ? (
        <WithPreviewSidebar className="flex-1">
          {children}
          <PreviewSidebar
            previewLink={(props) => (
              <Button
                {...props}
                onClick={() =>
                  saveBundle(() => {
                    window.open(url);
                  })
                }
                disabled={isBusy}
              />
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
