import { Link } from "@inertiajs/react";
import * as React from "react";

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

type LayoutProps = {
  children: React.ReactNode;
  preview: React.ReactNode;
  tab: "product" | "content" | "share";
  isLoading?: boolean;
  onSave: () => void;
  onPublish: () => void;
  onUnpublish: () => void;
  isSaving: boolean;
  isPublishing: boolean;
};

export const Layout = ({
  children,
  preview,
  tab,
  isLoading = false,
  onSave,
  onPublish,
  onUnpublish,
  isSaving,
  isPublishing,
}: LayoutProps) => {
  const { bundle, id } = useBundleEditContext();

  const url = useProductUrl();

  const isDesktop = useIsAboveBreakpoint("lg");

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
      <Button color="primary" disabled={isBusy} onClick={onSave}>
        {isSaving ? "Saving changes..." : "Save changes"}
      </Button>
    </WithTooltip>
  );

  const handleTabClick = (e: React.MouseEvent, callback?: () => void) => {
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

  const handlePreviewClick = () => {
    onSave();
    window.open(url);
  };

  return (
    <>
      <PageHeader
        className="sticky-top"
        title={bundle.name || "Untitled"}
        actions={
          bundle.is_published ? (
            <>
              <Button disabled={isBusy} onClick={onUnpublish}>
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
            <Button color="primary" disabled={isBusy} onClick={onSave}>
              {isSaving ? "Saving changes..." : "Save and continue"}
            </Button>
          ) : (
            <>
              {saveButton}
              <WithTooltip tip={saveButtonTooltip}>
                <Button color="accent" disabled={isBusy} onClick={onPublish}>
                  {isPublishing ? "Publishing..." : "Publish and continue"}
                </Button>
              </WithTooltip>
            </>
          )
        }
      >
        <Tabs style={{ gridColumn: 1 }}>
          <Tab asChild isSelected={tab === "product"}>
            <Link href={Routes.edit_bundle_product_path(id)} onClick={handleTabClick}>
              Product
            </Link>
          </Tab>
          <Tab asChild isSelected={tab === "content"}>
            <Link href={Routes.edit_bundle_content_path(id)} onClick={handleTabClick}>
              Content
            </Link>
          </Tab>
          <Tab asChild isSelected={tab === "share"}>
            <Link
              href={Routes.edit_bundle_share_path(id)}
              onClick={(evt: React.MouseEvent) => {
                handleTabClick(evt, () => {
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
          <PreviewSidebar previewLink={(props) => <Button {...props} onClick={handlePreviewClick} disabled={isBusy} />}>
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
