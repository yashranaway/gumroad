import { router } from "@inertiajs/react";
import * as React from "react";

import { setProductPublished } from "$app/data/publish_product";

import { showAlert } from "$app/components/server-components/Alert";

import { Bundle, BundleFormMethods, transformBundleForSubmission } from "./state";

export type UseBundleFormOptions = {
  initialBundle: Bundle;
  id: string;
  uniquePermalink: string;
  currentTab: "product" | "content" | "share";
};

export const useBundleForm = ({ initialBundle, id, uniquePermalink, currentTab }: UseBundleFormOptions) => {
  const [bundle, setBundle] = React.useState<Bundle>(initialBundle);
  const [isSaving, setIsSaving] = React.useState(false);
  const [isPublishing, setIsPublishing] = React.useState(false);

  const updateBundle = React.useCallback((update: Partial<Bundle> | ((bundle: Bundle) => void)) => {
    setBundle((prevBundle) => {
      const updated = { ...prevBundle };
      if (typeof update === "function") update(updated);
      else Object.assign(updated, update);
      return updated;
    });
  }, []);

  const save = React.useCallback(() => {
    setIsSaving(true);
    router.patch(Routes.bundle_path(id), transformBundleForSubmission(bundle), {
      preserveScroll: true,
      onSuccess: () => {
        showAlert("Changes saved!", "success");
        setIsSaving(false);
      },
      onError: (errors: Record<string, string | string[]>) => {
        const message = errors.error_message ?? errors.base ?? Object.values(errors)[0];
        const errorMessage = Array.isArray(message) ? message[0] : message;
        if (errorMessage) showAlert(errorMessage, "error");
        setIsSaving(false);
      },
      onFinish: () => {
        setIsSaving(false);
      },
    });
  }, [id, bundle]);

  const publish = React.useCallback(async () => {
    setIsPublishing(true);
    try {
      // First save the bundle
      await new Promise<void>((resolve, reject) => {
        router.patch(Routes.bundle_path(id), transformBundleForSubmission(bundle), {
          preserveScroll: true,
          onSuccess: () => resolve(),
          onError: (errors: Record<string, string | string[]>) => {
            const message = errors.error_message ?? errors.base ?? Object.values(errors)[0];
            const errorMessage = Array.isArray(message) ? message[0] : message;
            reject(new Error(errorMessage ?? "Failed to save"));
          },
        });
      });

      // Then publish
      await setProductPublished(uniquePermalink, true);
      updateBundle({ is_published: true });
      showAlert("Published!", "success");
      router.visit(Routes.edit_share_bundle_path(id));
    } catch (e) {
      showAlert(e instanceof Error ? e.message : "Failed to publish", "error");
    }
    setIsPublishing(false);
  }, [id, bundle, uniquePermalink, updateBundle]);

  const unpublish = React.useCallback(async () => {
    setIsPublishing(true);
    try {
      // First save the bundle
      await new Promise<void>((resolve, reject) => {
        router.patch(Routes.bundle_path(id), transformBundleForSubmission(bundle), {
          preserveScroll: true,
          onSuccess: () => resolve(),
          onError: (errors: Record<string, string | string[]>) => {
            const message = errors.error_message ?? errors.base ?? Object.values(errors)[0];
            const errorMessage = Array.isArray(message) ? message[0] : message;
            reject(new Error(errorMessage ?? "Failed to save"));
          },
        });
      });

      // Then unpublish
      await setProductPublished(uniquePermalink, false);
      updateBundle({ is_published: false });
      showAlert("Unpublished!", "success");
      if (currentTab === "share") {
        router.visit(Routes.edit_content_bundle_path(id));
      }
    } catch (e) {
      showAlert(e instanceof Error ? e.message : "Failed to unpublish", "error");
    }
    setIsPublishing(false);
  }, [id, bundle, uniquePermalink, updateBundle, currentTab]);

  const formMethods: BundleFormMethods = React.useMemo(
    () => ({
      save,
      publish,
      unpublish,
      isSaving,
      isPublishing,
    }),
    [save, publish, unpublish, isSaving, isPublishing],
  );

  return {
    bundle,
    updateBundle,
    formMethods,
  };
};
