import * as React from "react";

import { CommunityView } from "$app/components/Communities/CommunityView";

function CommunitiesIndex() {
  return <CommunityView />;
}

CommunitiesIndex.loggedInUserLayout = true;

export default CommunitiesIndex;
