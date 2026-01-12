import { router } from "@inertiajs/react";
import * as React from "react";

import { useBundleEditContext } from "$app/components/BundleEdit/state";
import { Button } from "$app/components/Button";
import { Alert } from "$app/components/ui/Alert";

export const BundleContentUpdatedStatus = () => {
  const { id } = useBundleEditContext();
  const [isLoading, setIsLoading] = React.useState(false);

  const updatePurchases = () => {
    setIsLoading(true);
    router.post(
      Routes.update_purchases_content_bundle_path(id),
      {},
      {
        preserveScroll: true,
        onFinish: () => setIsLoading(false),
      },
    );
  };

  return (
    <Alert role="status" variant="info">
      <div className="flex flex-col gap-4">
        <strong>Some of your customers don't have access to the latest content in your bundle.</strong>
        Would you like to give them access and send them an email notification?
        <Button color="primary" onClick={updatePurchases} disabled={isLoading}>
          {isLoading ? "Updating..." : "Yes, update"}
        </Button>
      </div>
    </Alert>
  );
};
