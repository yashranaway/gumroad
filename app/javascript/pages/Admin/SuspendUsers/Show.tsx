import { useForm, usePage } from "@inertiajs/react";
import React from "react";

type PageProps = {
  authenticity_token: string;
  suspend_reasons: string[];
};

const SuspendUsers = () => {
  const { authenticity_token: authenticityToken, suspend_reasons: suspendReasons } = usePage<PageProps>().props;

  const form = useForm({
    authenticity_token: authenticityToken,
    suspend_users: {
      identifiers: "",
      reason: "",
      additional_notes: "",
    },
  });

  const setIdentifiers = (event: React.ChangeEvent<HTMLTextAreaElement>) => {
    form.setData("suspend_users.identifiers", event.target.value);
  };

  const setReason = (event: React.ChangeEvent<HTMLSelectElement>) => {
    form.setData("suspend_users.reason", event.target.value);
  };

  const setAdditionalNotes = (event: React.ChangeEvent<HTMLTextAreaElement>) => {
    form.setData("suspend_users.additional_notes", event.target.value);
  };

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    form.put(Routes.admin_suspend_users_path(), {
      onSuccess: () => form.reset(),
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <section>
        <input type="hidden" name="authenticity_token" value={form.data.authenticity_token} />
        <header>
          To suspend users for terms of service violations, please enter IDs of those users separated by comma or
          newline.
        </header>

        <figure className="code">
          <figcaption>Example with comma-separated items</figcaption>
          <pre>3322133, 3738461, 4724778</pre>
        </figure>

        <figure className="code">
          <figcaption>Example with items separated by newline</figcaption>
          <pre>
            3322133
            <br />
            3738461
            <br />
            4724778
          </pre>
        </figure>

        <textarea
          id="identifiers"
          name="suspend_users[identifiers]"
          placeholder="Enter user IDs here"
          rows={10}
          value={form.data.suspend_users.identifiers}
          onChange={setIdentifiers}
        />

        <label htmlFor="reason">Reason</label>
        <select
          id="reason"
          name="suspend_users[reason]"
          required
          value={form.data.suspend_users.reason}
          onChange={setReason}
        >
          <option value="">Select a reason</option>
          {suspendReasons.map((reason: string) => (
            <option key={reason} value={reason}>
              {reason}
            </option>
          ))}
        </select>

        <label htmlFor="additionalNotes">Notes</label>
        <textarea
          id="additionalNotes"
          name="suspend_users[additional_notes]"
          placeholder="Additional info for support team"
          rows={3}
          value={form.data.suspend_users.additional_notes}
          onChange={setAdditionalNotes}
        />

        <button type="submit" className="button primary">
          Suspend users
        </button>
      </section>
    </form>
  );
};

export default SuspendUsers;
