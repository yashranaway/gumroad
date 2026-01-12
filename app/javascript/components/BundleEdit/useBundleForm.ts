import { router, useForm } from "@inertiajs/react";
import * as React from "react";

import { setProductPublished } from "$app/data/publish_product";

import { Bundle, transformBundleForSubmission } from "$app/components/BundleEdit/state";
import { showAlert } from "$app/components/server-components/Alert";

type UseBundleFormOptions = {
  initialBundle: Bundle;
  uniquePermalink: string;
  savePath: string;
  publishRedirectPath?: string;
  unpublishRedirectPath?: string;
};

export const useBundleForm = ({
  initialBundle,
  uniquePermalink,
  savePath,
  publishRedirectPath,
  unpublishRedirectPath,
}: UseBundleFormOptions) => {
  const [bundle, setBundle] = React.useState<Bundle>(initialBundle);
  const form = useForm(transformBundleForSubmission(bundle));
  const [isPublishing, setIsPublishing] = React.useState(false);

  const updateBundle = React.useCallback((update: Partial<Bundle> | ((bundle: Bundle) => void)) => {
    setBundle((prevBundle) => {
      const updated = { ...prevBundle };
      if (typeof update === "function") update(updated);
      else Object.assign(updated, update);
      return updated;
    });
  }, []);

  React.useEffect(() => {
    form.setData(transformBundleForSubmission(bundle));
  }, [bundle]);

  const handleError = (errors: Record<string, string | string[]>) => {
    const message = errors.error_message ?? errors.base ?? Object.values(errors)[0];
    const errorString = Array.isArray(message) ? message[0] : message;
    showAlert(errorString ?? "An error occurred", "error");
  };

  const handleSave = () => {
    form.patch(savePath, {
      preserveScroll: true,
      onSuccess: () => showAlert("Changes saved!", "success"),
      onError: handleError,
    });
  };

  const handlePublish = () => {
    setIsPublishing(true);
    form.patch(savePath, {
      preserveScroll: true,
      onSuccess: () => {
        void (async () => {
          try {
            await setProductPublished(uniquePermalink, true);
            updateBundle({ is_published: true });
            showAlert("Published!", "success");
            if (publishRedirectPath) {
              router.visit(publishRedirectPath);
            }
          } catch (e) {
            showAlert(e instanceof Error ? e.message : "Failed to publish", "error");
          }
          setIsPublishing(false);
        })();
      },
      onError: (errors: Record<string, string | string[]>) => {
        handleError(errors);
        setIsPublishing(false);
      },
    });
  };

  const handleUnpublish = () => {
    setIsPublishing(true);
    void (async () => {
      try {
        await setProductPublished(uniquePermalink, false);
        updateBundle({ is_published: false });
        showAlert("Unpublished!", "success");
        if (unpublishRedirectPath) {
          router.visit(unpublishRedirectPath);
        }
      } catch (e) {
        showAlert(e instanceof Error ? e.message : "Failed to unpublish", "error");
      }
      setIsPublishing(false);
    })();
  };

  return {
    bundle,
    updateBundle,
    form,
    isPublishing,
    handleSave,
    handlePublish,
    handleUnpublish,
  };
};
