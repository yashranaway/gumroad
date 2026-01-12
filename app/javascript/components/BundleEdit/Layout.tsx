import { Link, usePage } from "@inertiajs/react";
import * as React from "react";
import { cast } from "ts-safe-cast";

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
  isProcessing = false,
  onSave,
  onUnpublish,
  onSaveAndContinue,
  onPublishAndContinue,
  onPreview,
}: {
  children: React.ReactNode;
  preview: React.ReactNode;
  isLoading?: boolean;
  isProcessing?: boolean;
  onSave?: () => void;
  onPublish?: () => void;
  onUnpublish?: () => void;
  onSaveAndContinue?: () => void;
  onPublishAndContinue?: () => void;
  onPreview?: () => void;
}) => {
  const { bundle, id } = useBundleEditContext();
  const { tab } = cast<{ tab: "product" | "content" | "share" }>(usePage().props);

  const url = useProductUrl();
  const rootPath = Routes.edit_bundle_product_path(id);

  const isDesktop = useIsAboveBreakpoint("lg");

  const isUploadingFiles = bundle.public_files.some(
    (f) => f.status?.type === "unsaved" && f.status.uploadStatus.type === "uploading",
  );
  const isUploadingFilesOrImages = isLoading || isUploadingFiles;
  const isBusy = isUploadingFilesOrImages || isProcessing;
  const saveButtonTooltip = isUploadingFiles
    ? "Files are still uploading..."
    : isUploadingFilesOrImages
      ? "Images are still uploading..."
      : isBusy
        ? "Please wait..."
        : undefined;

  const saveButton = onSave ? (
    <WithTooltip tip={saveButtonTooltip}>
      <Button color="primary" disabled={isBusy} onClick={onSave}>
        {isProcessing ? "Saving changes..." : "Save changes"}
      </Button>
    </WithTooltip>
  ) : null;

  const handleTabClick = (e: React.MouseEvent, targetTab: "product" | "content" | "share") => {
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

    if (targetTab === "share" && !bundle.is_published) {
      e.preventDefault();
      showAlert(
        "Not yet! You've got to publish your awesome product before you can share it with your audience and the world.",
        "warning",
      );
    }
  };

  return (
    <>
      <PageHeader
        className="sticky-top"
        title={bundle.name || "Untitled"}
        actions={
          bundle.is_published ? (
            <>
              {onUnpublish ? (
                <Button disabled={isBusy} onClick={onUnpublish}>
                  {isProcessing ? "Unpublishing..." : "Unpublish"}
                </Button>
              ) : null}
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
            onSaveAndContinue ? (
              <Button color="primary" disabled={isBusy} onClick={onSaveAndContinue}>
                {isProcessing ? "Saving changes..." : "Save and continue"}
              </Button>
            ) : null
          ) : (
            <>
              {saveButton}
              {onPublishAndContinue ? (
                <WithTooltip tip={saveButtonTooltip}>
                  <Button color="accent" disabled={isBusy} onClick={onPublishAndContinue}>
                    {isProcessing ? "Publishing..." : "Publish and continue"}
                  </Button>
                </WithTooltip>
              ) : null}
            </>
          )
        }
      >
        <Tabs style={{ gridColumn: 1 }}>
          <Tab asChild isSelected={tab === "product"}>
            <Link href={rootPath} onClick={(e) => handleTabClick(e, "product")}>
              Product
            </Link>
          </Tab>
          <Tab asChild isSelected={tab === "content"}>
            <Link href={Routes.edit_bundle_content_path(id)} onClick={(e) => handleTabClick(e, "content")}>
              Content
            </Link>
          </Tab>
          <Tab asChild isSelected={tab === "share"}>
            <Link href={Routes.edit_bundle_share_path(id)} onClick={(e) => handleTabClick(e, "share")}>
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
              <Button {...props} onClick={onPreview} disabled={isBusy} />
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
