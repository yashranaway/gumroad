import { cast } from "ts-safe-cast";

import { ResponseError, request } from "$app/utils/request";

export const updatePurchasesContent = async (id: string) => {
  const response = await request({
    method: "POST",
    accept: "json",
    url: Routes.update_purchases_content_bundle_content_path(id),
  });

  if (!response.ok)
    await response.json().then((json) => {
      throw new ResponseError(cast<{ error: string }>(json).error);
    });
};
