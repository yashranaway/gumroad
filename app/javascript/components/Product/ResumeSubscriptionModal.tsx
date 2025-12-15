import * as React from "react";

import { Button, NavigationButton } from "$app/components/Button";
import { Modal } from "$app/components/Modal";

type Props = {
  open: boolean;
  onClose: () => void;
  onStartNewSubscription: () => void;
  manageUrl: string;
};

export const ResumeSubscriptionModal = ({ open, onClose, onStartNewSubscription, manageUrl }: Props) => (
  <Modal
    open={open}
    onClose={onClose}
    title="Resume your previous subscription?"
    className="!shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] !border-2 !border-black"
  >
    <div className="flex flex-col gap-6">
      <p className="text-lg">
        You've previously subscribed to this product. Would you like to <strong>pick up where you left off</strong>, or{" "}
        <strong>start fresh with a new subscription</strong>?
      </p>
      <div className="flex flex-col gap-3 sm:flex-row w-full">
        <Button className="flex-1 justify-center" onClick={onStartNewSubscription} color="black" outline>
          No, start a new subscription
        </Button>
        <NavigationButton className="flex-1 justify-center" color="primary" href={manageUrl}>
          Yes, resume subscription
        </NavigationButton>
      </div>
    </div>
  </Modal>
);
