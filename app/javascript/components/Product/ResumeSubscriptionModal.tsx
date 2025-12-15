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
  <Modal open={open} onClose={onClose} title="Resume your previous subscription?">
    <div className="paragraphs">
      <p>
        You've previously subscribed to this product. Would you like to <strong>pick up where you left off</strong>, or{" "}
        <strong>start fresh with a new subscription</strong>?
      </p>
      <div className="button-row">
        <Button onClick={onStartNewSubscription}>No, start a new subscription</Button>
        <NavigationButton color="primary" href={manageUrl}>
          Yes, resume subscription
        </NavigationButton>
      </div>
    </div>
  </Modal>
);
