import { useForm } from "@inertiajs/react";
import * as React from "react";

import { showAlert } from "$app/components/server-components/Alert";

type UseBundleFormSubmissionOptions<T> = {
  url: string;
  transform: () => T;
};

export const useBundleFormSubmission = <T extends Record<string, unknown>>({
  url,
  transform,
}: UseBundleFormSubmissionOptions<T>) => {
  const form = useForm({});
  const onSuccessRef = React.useRef<(() => void | Promise<void>) | undefined>(undefined);

  const submit = React.useCallback(
    (onSuccess?: () => void | Promise<void>) => {
      if (form.processing) return;
      onSuccessRef.current = onSuccess;
      form.transform(() => transform());
      form.put(url, {
        preserveScroll: true,
        onSuccess: () => {
          showAlert("Changes saved!", "success");
          const callback = onSuccessRef.current;
          if (callback) {
            void callback();
          }
        },
        onError: (errors) => {
          const errorMessage = Object.values(errors)[0] || "An error occurred";
          showAlert(errorMessage, "error");
        },
      });
    },
    [form, transform, url],
  );

  return { submit, isProcessing: form.processing };
};
