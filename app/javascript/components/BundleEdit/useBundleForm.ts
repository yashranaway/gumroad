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

const getErrorMessage = (errors: Record<string, string | string[]>): string => {
  const message = errors.error_message ?? errors.base ?? Object.values(errors)[0];
  const errorString = Array.isArray(message) ? message[0] : message;
  return errorString ?? "An error occurred";
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

  const saveBundle = React.useCallback(
    () =>
      new Promise<void>((resolve, reject) => {
        router.patch(Routes.bundle_path(id), transformBundleForSubmission(bundle), {
          preserveScroll: true,
          onSuccess: () => resolve(),
          onError: (errors: Record<string, string | string[]>) => reject(new Error(getErrorMessage(errors))),
        });
      }),
    [id, bundle],
  );

  const save = React.useCallback(() => {
    setIsSaving(true);
    saveBundle()
      .then(() => showAlert("Changes saved!", "success"))
      .catch((e: unknown) => showAlert(e instanceof Error ? e.message : "An error occurred", "error"))
      .finally(() => setIsSaving(false));
  }, [saveBundle]);

  const publish = React.useCallback(async () => {
    setIsPublishing(true);
    try {
      await saveBundle();
      await setProductPublished(uniquePermalink, true);
      updateBundle({ is_published: true });
      showAlert("Published!", "success");
      router.visit(Routes.edit_share_bundle_path(id));
    } catch (e) {
      showAlert(e instanceof Error ? e.message : "Failed to publish", "error");
    }
    setIsPublishing(false);
  }, [saveBundle, id, uniquePermalink, updateBundle]);

  const unpublish = React.useCallback(async () => {
    setIsPublishing(true);
    try {
      await saveBundle();
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
  }, [saveBundle, id, uniquePermalink, updateBundle, currentTab]);

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
